import { useEffect, useState } from 'react'
import { formatDateTime, rupiah } from '../lib/format'
import { invokeFn } from '../lib/functions'
import { supabase } from '../lib/supabase'

interface ReviewRow {
  id: string
  order_id: string
  type: string
  status: string
  amount: number
  paid_at: string | null
  created_at: string
  review_note: string | null
  booking_id: string | null
  package_purchase_id: string | null
  group_seat_id: string | null
  subscription_id: string | null
}

interface Context {
  who: string
  what: string
}

const TYPE_LABEL: Record<string, string> = {
  package: 'Paket sesi',
  booking: 'Sesi satuan',
  group_seat: 'Kursi kelas grup',
  subscription: 'Langganan bank soal',
}

const STATUS_TONE: Record<string, string> = {
  settlement: 'success',
  refund: 'info',
  partial_refund: 'info',
  pending: 'warning',
  expire: 'neutral',
  deny: 'danger',
  cancel: 'danger',
}

function nameMap<T extends { id: string }>(
  rows: T[] | null,
  pick: (row: T) => string | null | undefined,
) {
  const map: Record<string, string> = {}
  for (const row of rows ?? []) {
    const value = pick(row)
    if (value) map[row.id] = value
  }
  return map
}

export function PaymentReviews() {
  const [rows, setRows] = useState<ReviewRow[]>([])
  const [context, setContext] = useState<Record<string, Context>>({})
  const [loading, setLoading] = useState(true)
  const [notice, setNotice] = useState<string | null>(null)
  const [busy, setBusy] = useState<string | null>(null)

  async function load() {
    setLoading(true)
    setNotice(null)

    const { data, error } = await supabase
      .from('payments')
      .select(
        'id, order_id, type, status, amount, paid_at, created_at, review_note, ' +
          'booking_id, package_purchase_id, group_seat_id, subscription_id',
      )
      .eq('review_required', true)
      .order('created_at', { ascending: false })
      .limit(200)
    if (error) {
      setNotice(`Gagal memuat: ${error.message}`)
      setLoading(false)
      return
    }

    const list = (data ?? []) as unknown as ReviewRow[]
    const ids = (pick: (row: ReviewRow) => string | null) =>
      [...new Set(list.map(pick).filter((v): v is string => !!v))]

    const bookingIds = ids((r) => r.booking_id)
    const packageIds = ids((r) => r.package_purchase_id)
    const seatIds = ids((r) => r.group_seat_id)
    const subscriptionIds = ids((r) => r.subscription_id)

    const [bookings, packages, seats, subscriptions] = await Promise.all(
      [
        bookingIds.length
          ? supabase
              .from('bookings_visible')
              .select('id, student_id, subject_id, scheduled_at')
              .in('id', bookingIds)
          : null,
        packageIds.length
          ? supabase
              .from('package_purchases')
              .select('id, student_id, tutor_id, subject_id, jenjang, mode, total_sesi')
              .in('id', packageIds)
          : null,
        seatIds.length
          ? supabase
              .from('group_seats')
              .select('id, student_id, group_class_id')
              .in('id', seatIds)
          : null,
        subscriptionIds.length
          ? supabase
              .from('subscriptions')
              .select('id, student_id, plan_code')
              .in('id', subscriptionIds)
          : null,
      ].map((q) => (q ? q : Promise.resolve({ data: [] }))),
    )

    const bookingRows = (bookings.data ?? []) as {
      id: string
      student_id: string
      subject_id: string | null
      scheduled_at: string
    }[]
    const packageRows = (packages.data ?? []) as {
      id: string
      student_id: string
      tutor_id: string | null
      subject_id: string | null
      jenjang: string | null
      mode: string | null
      total_sesi: number
    }[]
    const seatRows = (seats.data ?? []) as {
      id: string
      student_id: string
      group_class_id: string
    }[]
    const subscriptionRows = (subscriptions.data ?? []) as {
      id: string
      student_id: string
      plan_code: string
    }[]

    const studentIds = [
      ...new Set([
        ...bookingRows.map((b) => b.student_id),
        ...packageRows.map((p) => p.student_id),
        ...seatRows.map((s) => s.student_id),
        ...subscriptionRows.map((s) => s.student_id),
      ]),
    ]
    const subjectIds = [
      ...new Set([
        ...bookingRows.map((b) => b.subject_id),
        ...packageRows.map((p) => p.subject_id),
      ].filter((v): v is string => !!v)),
    ]
    const classIds = [...new Set(seatRows.map((s) => s.group_class_id))]
    const planCodes = [...new Set(subscriptionRows.map((s) => s.plan_code))]

    const [students, subjects, classes, plans] = await Promise.all(
      [
        studentIds.length
          ? supabase.from('students').select('id, full_name').in('id', studentIds)
          : null,
        subjectIds.length
          ? supabase.from('subjects').select('id, name').in('id', subjectIds)
          : null,
        classIds.length
          ? supabase.from('group_classes').select('id, subject_id').in('id', classIds)
          : null,
        planCodes.length
          ? supabase.from('subscription_plans').select('code, name').in('code', planCodes)
          : null,
      ].map((q) => (q ? q : Promise.resolve({ data: [] }))),
    )

    const studentNames = nameMap(
      students.data as { id: string; full_name: string }[] | null,
      (s) => s.full_name,
    )
    const subjectNames = nameMap(
      subjects.data as { id: string; name: string }[] | null,
      (s) => s.name,
    )
    const classRows = (classes.data ?? []) as { id: string; subject_id: string | null }[]
    const planNames = Object.fromEntries(
      ((plans.data ?? []) as { code: string; name: string }[]).map((p) => [p.code, p.name]),
    )
    const bookingById = Object.fromEntries(bookingRows.map((b) => [b.id, b]))
    const packageById = Object.fromEntries(packageRows.map((p) => [p.id, p]))
    const seatById = Object.fromEntries(seatRows.map((s) => [s.id, s]))
    const subscriptionById = Object.fromEntries(subscriptionRows.map((s) => [s.id, s]))
    const classById = Object.fromEntries(classRows.map((c) => [c.id, c]))

    const next: Record<string, Context> = {}
    for (const row of list) {
      if (row.booking_id) {
        const b = bookingById[row.booking_id]
        if (b) {
          next[row.id] = {
            who: studentNames[b.student_id] ?? 'Siswa',
            what: `${b.subject_id ? subjectNames[b.subject_id] ?? 'Sesi' : 'Sesi'} · ${formatDateTime(b.scheduled_at)}`,
          }
        }
      } else if (row.package_purchase_id) {
        const p = packageById[row.package_purchase_id]
        if (p) {
          next[row.id] = {
            who: studentNames[p.student_id] ?? 'Siswa',
            what:
              `Paket ${p.total_sesi} sesi · ${p.jenjang ?? '—'} · ${p.mode ?? '—'}` +
              (p.subject_id ? ` · ${subjectNames[p.subject_id] ?? ''}` : ''),
          }
        }
      } else if (row.group_seat_id) {
        const s = seatById[row.group_seat_id]
        if (s) {
          const cls = classById[s.group_class_id]
          next[row.id] = {
            who: studentNames[s.student_id] ?? 'Siswa',
            what: `Kursi kelas grup · ${cls?.subject_id ? subjectNames[cls.subject_id] ?? '—' : '—'}`,
          }
        }
      } else if (row.subscription_id) {
        const s = subscriptionById[row.subscription_id]
        if (s) {
          next[row.id] = {
            who: studentNames[s.student_id] ?? 'Siswa',
            what: `Langganan ${planNames[s.plan_code] ?? s.plan_code}`,
          }
        }
      }
    }

    setRows(list)
    setContext(next)
    setLoading(false)
  }

  useEffect(() => {
    queueMicrotask(load)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  async function onRetry(row: ReviewRow) {
    if (
      !confirm(
        `Jalankan ulang pemrosesan ${row.order_id}?\n\n` +
          'Sistem akan mengecek Midtrans (bila perlu) lalu mengaktifkan kembali ' +
          'paket/kursi/langganan yang tertahan.',
      )
    )
      return

    setBusy(row.id)
    setNotice(null)
    const { data, error } = await invokeFn<{ ok: boolean; message?: string; review_note?: string }>(
      'resolve-payment-review',
      { payment_id: row.id, action: 'retry' },
    )
    setBusy(null)
    if (error) {
      setNotice(`Gagal: ${error}`)
      return
    }
    setNotice(
      data?.ok
        ? `Selesai: ${data.message ?? 'pembayaran diproses ulang.'}`
        : `Masih perlu ditinjau — ${data?.review_note ?? data?.message ?? 'periksa manual.'}`,
    )
    load()
  }

  async function onDismiss(row: ReviewRow) {
    const note = prompt(
      `Catatan penanganan untuk ${row.order_id} (mis. "sudah direfund manual via Midtrans"):`,
    )
    if (!note) return

    setBusy(row.id)
    setNotice(null)
    const { error } = await invokeFn('resolve-payment-review', {
      payment_id: row.id,
      action: 'dismiss',
      note,
    })
    setBusy(null)
    if (error) {
      setNotice(`Gagal: ${error}`)
      return
    }
    setNotice(`${row.order_id} ditandai sudah ditangani.`)
    load()
  }

  return (
    <section>
      <div className="page-head">
        <div>
          <p className="eyebrow">Keuangan · Pembayaran</p>
          <h1 className="page-title">Pembayaran perlu ditinjau</h1>
          <p className="page-sub">
            Pembayaran yang uangnya sudah masuk tetapi aktivasi otomatisnya gagal. Uang tidak
            pernah hilang: slot tetap ditahan sampai masalah ini dibereskan.
          </p>
        </div>
      </div>

      {notice && (
        <div className="note" style={{ marginBottom: 14 }}>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
            <circle cx="12" cy="12" r="9" />
            <path d="M12 11v5M12 8h.01" />
          </svg>
          <span>{notice}</span>
        </div>
      )}

      <div className="card">
        <div className="toolbar">
          <div className="spacer" />
          <button className="btn btn-secondary btn-sm" onClick={() => load()} disabled={loading}>
            {loading ? 'Memuat…' : 'Muat ulang'}
          </button>
          <span className="badge neutral">{rows.length} pembayaran</span>
        </div>

        <div className="table-wrap">
          <table className="data-table" style={{ minWidth: 1040 }}>
            <thead>
              <tr>
                <th>Dibuat</th>
                <th>Pesanan</th>
                <th>Pembeli & pembelian</th>
                <th className="num">Nominal</th>
                <th>Status bayar</th>
                <th>Kendala</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan={7}>
                    <div className="empty-state">
                      <strong>Memuat…</strong>
                    </div>
                  </td>
                </tr>
              ) : rows.length === 0 ? (
                <tr>
                  <td colSpan={7}>
                    <div className="empty-state">
                      <strong>Tidak ada yang perlu ditinjau</strong>
                      <span>Semua pembayaran terakhir selesai otomatis.</span>
                    </div>
                  </td>
                </tr>
              ) : (
                rows.map((row) => {
                  const ctx = context[row.id]
                  return (
                    <tr key={row.id}>
                      <td className="num">{formatDateTime(row.created_at)}</td>
                      <td className="num" style={{ maxWidth: 180, wordBreak: 'break-all' }}>
                        {row.order_id}
                        <span className="sub">{TYPE_LABEL[row.type] ?? row.type}</span>
                      </td>
                      <td>
                        {ctx ? (
                          <>
                            <span className="strong">{ctx.who}</span>
                            <span className="sub">{ctx.what}</span>
                          </>
                        ) : (
                          <span className="sub">Data terkait tidak ditemukan</span>
                        )}
                      </td>
                      <td className="num">{rupiah(row.amount)}</td>
                      <td>
                        <span className={`badge ${STATUS_TONE[row.status] ?? 'neutral'}`}>
                          {row.status}
                        </span>
                        {row.paid_at && <span className="sub">Lunas {formatDateTime(row.paid_at)}</span>}
                      </td>
                      <td style={{ maxWidth: 300, wordBreak: 'break-word' }}>
                        {row.review_note ?? '—'}
                      </td>
                      <td>
                        <div className="row-actions">
                          <button
                            className="btn btn-secondary btn-sm"
                            disabled={busy === row.id}
                            onClick={() => onRetry(row)}
                          >
                            Proses ulang
                          </button>
                          <button
                            className="btn btn-ghost btn-sm"
                            disabled={busy === row.id}
                            onClick={() => onDismiss(row)}
                          >
                            Sudah ditangani
                          </button>
                        </div>
                      </td>
                    </tr>
                  )
                })
              )}
            </tbody>
          </table>
        </div>

        <div className="card-foot">
          <div className="note">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
              <circle cx="12" cy="12" r="9" />
              <path d="M12 11v5M12 8h.01" />
            </svg>
            <span>
              "Proses ulang" mengaktifkan kembali paket/kursi/langganan yang tertahan dan aman
              diulang. "Sudah ditangani" dipakai bila masalahnya dibereskan di luar sistem
              (mis. refund manual lewat dashboard Midtrans) dan wajib disertai catatan.
            </span>
          </div>
        </div>
      </div>
    </section>
  )
}
