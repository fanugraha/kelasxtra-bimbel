import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'

interface ComplaintRow {
  id: string
  category: string
  body: string
  status: string
  decision: string | null
  refund_nominal: number
  created_at: string
  bookings: {
    id: string
    scheduled_at: string
    price: number
    students: { full_name: string } | null
    tutors: { full_name: string } | null
  } | null
}

const CATEGORY_LABEL: Record<string, string> = {
  tutor_absent: 'Tutor tidak hadir',
  student_absent: 'Siswa tidak hadir',
  quality: 'Kualitas sesi',
  schedule: 'Jadwal',
  payment: 'Pembayaran',
  other: 'Lainnya',
}

const STATUS_META: Record<string, { label: string; tone: string }> = {
  open: { label: 'Baru', tone: 'danger' },
  in_review: { label: 'Ditinjau', tone: 'info' },
  resolved: { label: 'Selesai', tone: 'success' },
  rejected: { label: 'Ditolak', tone: 'neutral' },
}

const FILTERS: { value: string; label: string }[] = [
  { value: 'all', label: 'Semua' },
  { value: 'open', label: 'Baru' },
  { value: 'in_review', label: 'Ditinjau' },
  { value: 'resolved', label: 'Selesai' },
  { value: 'rejected', label: 'Ditolak' },
]

const rupiah = (n: number) => 'Rp' + n.toLocaleString('id-ID')

export function Disputes() {
  const [rows, setRows] = useState<ComplaintRow[]>([])
  const [filter, setFilter] = useState('open')
  const [loading, setLoading] = useState(true)
  const [notice, setNotice] = useState<string | null>(null)
  const [busy, setBusy] = useState<string | null>(null)

  async function load() {
    setLoading(true)
    let q = supabase
      .from('complaints')
      .select('id, booking_id, category, body, status, decision, refund_nominal, created_at')
      .order('created_at', { ascending: false })
    if (filter !== 'all') q = q.eq('status', filter)
    const { data, error } = await q
    if (error) {
      setNotice(`Gagal memuat: ${error.message}`)
      setLoading(false)
      return
    }
    const complaints = (data ?? []) as {
      id: string
      booking_id: string
      category: string
      body: string
      status: string
      decision: string | null
      refund_nominal: number
      created_at: string
    }[]
    const bookingIds = [...new Set(complaints.map((c) => c.booking_id))]
    const { data: bookings } = await supabase
      .from('bookings_visible')
      .select('id, scheduled_at, price, student_id, tutor_id')
      .in('id', bookingIds)
    const list = (bookings ?? []) as {
      id: string
      scheduled_at: string
      price: number
      student_id: string
      tutor_id: string
    }[]
    const studentIds = [...new Set(list.map((b) => b.student_id))]
    const tutorIds = [...new Set(list.map((b) => b.tutor_id))]
    const [{ data: students }, { data: tutors }] = await Promise.all([
      supabase.from('students').select('id, full_name').in('id', studentIds),
      supabase.from('tutors').select('id, full_name').in('id', tutorIds),
    ])
    const byId = new Map(list.map((b) => [b.id, b]))
    const studentNames = Object.fromEntries((students ?? []).map((s) => [s.id, s.full_name]))
    const tutorNames = Object.fromEntries((tutors ?? []).map((t) => [t.id, t.full_name]))

    setRows(
      complaints.map((c) => {
        const b = byId.get(c.booking_id)
        return {
          ...c,
          bookings: b
            ? {
                id: b.id,
                scheduled_at: b.scheduled_at,
                price: b.price,
                students: studentNames[b.student_id] ? { full_name: studentNames[b.student_id] } : null,
                tutors: tutorNames[b.tutor_id] ? { full_name: tutorNames[b.tutor_id] } : null,
              }
            : null,
        }
      }),
    )
    setLoading(false)
  }

  useEffect(() => {
    queueMicrotask(load)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [filter])

  async function onResolve(row: ComplaintRow) {
    const decision = prompt('Keputusan admin (terlihat oleh pelapor):')
    if (!decision) return
    const raw = prompt(
      `Nominal refund untuk siswa (0 = tanpa refund, maks ${rupiah(row.bookings?.price ?? 0)}):`,
      '0',
    )
    if (raw === null) return
    const refund = Number(raw)
    if (!Number.isFinite(refund) || refund < 0) {
      setNotice('Nominal refund tidak valid.')
      return
    }
    if (
      !confirm(
        `Tandai komplain selesai dengan refund ${rupiah(refund)}?\n\n` +
          'Dana tetap dikembalikan manual lewat dashboard Midtrans.',
      )
    )
      return

    setBusy(row.id)
    setNotice(null)
    const { error } = await supabase.rpc('resolve_complaint', {
      p_complaint: row.id,
      p_status: 'resolved',
      p_decision: decision,
      p_refund: refund,
    })
    setBusy(null)
    if (error) {
      setNotice(`Gagal: ${error.message}`)
      return
    }
    setNotice(`Komplain ditutup. Refund tercatat: ${rupiah(refund)}.`)
    load()
  }

  async function onReject(row: ComplaintRow) {
    const decision = prompt('Alasan penolakan (terlihat oleh pelapor):')
    if (!decision) return
    setBusy(row.id)
    setNotice(null)
    const { error } = await supabase.rpc('resolve_complaint', {
      p_complaint: row.id,
      p_status: 'rejected',
      p_decision: decision,
      p_refund: 0,
    })
    setBusy(null)
    if (error) {
      setNotice(`Gagal: ${error.message}`)
      return
    }
    setNotice('Komplain ditolak; penghasilan tutor dilepas kembali.')
    load()
  }

  return (
    <section>
      <div className="page-head">
        <div>
          <p className="eyebrow">Layanan · Komplain</p>
          <h1 className="page-title">Komplain</h1>
          <p className="page-sub">
            Selama komplain terbuka, gaji tutor ditahan. Keputusan pengembalian dana dicatat; dana dikirim manual via Midtrans.
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
          <div className="segmented" role="group" aria-label="Filter status komplain">
            {FILTERS.map((item) => (
              <button
                key={item.value}
                aria-pressed={filter === item.value}
                onClick={() => setFilter(item.value)}
              >
                {item.label}
              </button>
            ))}
          </div>
          <div className="spacer" />
          <span className="badge neutral">{rows.length} tiket</span>
        </div>

        <div className="table-wrap">
          <table className="data-table" style={{ minWidth: 940 }}>
            <thead>
              <tr>
                <th>Tanggal</th>
                <th>Siswa</th>
                <th>Tutor</th>
                <th>Kategori</th>
                <th>Ringkasan</th>
                <th>Status</th>
                <th className="num">Dana kembali</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan={8}>
                    <div className="empty-state">
                      <strong>Memuat komplain…</strong>
                    </div>
                  </td>
                </tr>
              ) : rows.length === 0 ? (
                <tr>
                  <td colSpan={8}>
                    <div className="empty-state">
                      <strong>Tidak ada komplain</strong>
                      <span>Tiket baru akan tampil di sini.</span>
                    </div>
                  </td>
                </tr>
              ) : (
                rows.map((c) => {
                  const meta = STATUS_META[c.status] ?? { label: c.status, tone: 'neutral' }
                  return (
                    <tr key={c.id}>
                      <td className="num">
                        {new Intl.DateTimeFormat('id-ID', {
                          day: '2-digit',
                          month: 'short',
                          timeZone: 'Asia/Jakarta',
                        }).format(new Date(c.created_at))}
                      </td>
                      <td>{c.bookings?.students?.full_name ?? '—'}</td>
                      <td>{c.bookings?.tutors?.full_name ?? '—'}</td>
                      <td>{CATEGORY_LABEL[c.category] ?? c.category}</td>
                      <td>
                        {c.body}
                        {c.decision && <span className="sub">Keputusan: {c.decision}</span>}
                      </td>
                      <td>
                        <span className={`badge ${meta.tone}`}>{meta.label}</span>
                      </td>
                      <td className="num">{c.refund_nominal > 0 ? rupiah(c.refund_nominal) : '—'}</td>
                      <td>
                        <div className="row-actions">
                          {c.status === 'open' || c.status === 'in_review' ? (
                            <>
                              <button className="btn btn-secondary btn-sm" disabled={busy === c.id} onClick={() => onResolve(c)}>
                                Selesaikan
                              </button>
                              <button className="btn btn-ghost btn-sm" disabled={busy === c.id} onClick={() => onReject(c)}>
                                Tolak
                              </button>
                            </>
                          ) : null}
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
            <span>Komplain bisa diajukan maksimal 3 hari setelah sesi. Auto-complete H+1 bila tidak ada komplain.</span>
          </div>
        </div>
      </div>
    </section>
  )
}
