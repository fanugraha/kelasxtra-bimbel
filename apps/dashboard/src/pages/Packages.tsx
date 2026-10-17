import { useEffect, useMemo, useState } from 'react'
import { supabase } from '../lib/supabase'

interface PackageRow {
  id: string
  jenjang: string
  duration_minutes: number
  mode: string
  total_sesi: number
  sesi_terpakai: number
  price_total: number
  discount_percent: number
  status: string
  expires_at: string | null
  students: { full_name: string } | null
  tutors: { full_name: string } | null
  subjects: { name: string } | null
}

const STATUS_META: Record<string, { label: string; tone: string }> = {
  active: { label: 'Aktif', tone: 'success' },
  pending_payment: { label: 'Menunggu bayar', tone: 'warning' },
  expired: { label: 'Kedaluwarsa', tone: 'neutral' },
  refunded: { label: 'Direfund', tone: 'neutral' },
  cancelled: { label: 'Dibatalkan', tone: 'danger' },
}

const rupiah = (n: number) => 'Rp' + n.toLocaleString('id-ID')
const tanggal = (value: string | null) =>
  value
    ? new Intl.DateTimeFormat('id-ID', {
        day: '2-digit',
        month: 'short',
        year: 'numeric',
        timeZone: 'Asia/Jakarta',
      }).format(new Date(value))
    : '—'

function initials(name: string) {
  return name
    .split(/\s+/)
    .slice(0, 2)
    .map((part) => part[0] ?? '')
    .join('')
    .toUpperCase()
}

export function Packages() {
  const [rows, setRows] = useState<PackageRow[]>([])
  const [tutors, setTutors] = useState<{ id: string; full_name: string }[]>([])
  const [loading, setLoading] = useState(true)
  const [notice, setNotice] = useState<string | null>(null)
  const [busy, setBusy] = useState<string | null>(null)
  const [search, setSearch] = useState('')

  async function load() {
    const { data } = await supabase
      .from('package_purchases')
      .select(
        'id, jenjang, duration_minutes, mode, total_sesi, sesi_terpakai, ' +
          'price_total, discount_percent, status, expires_at, ' +
          'students(full_name), tutors(full_name), subjects(name)',
      )
      .order('created_at', { ascending: false })
    setRows((data as unknown as PackageRow[]) ?? [])
    const { data: tutorRows } = await supabase
      .from('tutors')
      .select('id, full_name')
      .eq('status', 'aktif')
      .order('full_name')
    setTutors((tutorRows as { id: string; full_name: string }[]) ?? [])
    setLoading(false)
  }

  useEffect(() => {
    queueMicrotask(load)
  }, [])

  const sisa = (p: PackageRow) => p.total_sesi - p.sesi_terpakai
  const refundPreview = (p: PackageRow) =>
    Math.floor((p.price_total * sisa(p)) / p.total_sesi)

  async function onRefund(p: PackageRow) {
    const amount = refundPreview(p)
    const ok = confirm(
      `Refund paket ${p.tutors?.full_name ?? '-'} (${p.students?.full_name ?? '-'})?\n` +
        `Sisa ${sisa(p)}/${p.total_sesi} sesi → ${rupiah(amount)}.\n\n` +
        'Ini hanya MENGHITUNG & MENCATAT. Pengembalian uang dilakukan manual di dashboard Midtrans.',
    )
    if (!ok) return
    setBusy(p.id)
    setNotice(null)
    const { data, error } = await supabase.rpc('refund_package', { p_package_id: p.id })
    setBusy(null)
    if (error) {
      setNotice(`Gagal: ${error.message}`)
      return
    }
    setNotice(
      `Refund tercatat: ${rupiah(Number(data))}. Kembalikan dana secara manual via Midtrans.`,
    )
    load()
  }

  async function onTransfer(p: PackageRow) {
    const list = tutors.map((t, i) => `${i + 1}. ${t.full_name}`).join('\n')
    const pick = prompt(
      `Pindahkan paket ${p.students?.full_name ?? '-'} ke tutor mana?\n\n${list}\n\nKetik nomor:`,
    )
    if (!pick) return
    const target = tutors[Number(pick) - 1]
    if (!target) {
      setNotice('Nomor tutor tidak valid.')
      return
    }
    if (!confirm('Pastikan siswa sudah menyetujui pemindahan paket ini.')) return
    const reason = prompt('Alasan pemindahan (masuk audit log):')
    if (!reason) return
    setBusy(p.id)
    setNotice(null)
    const { error } = await supabase.rpc('admin_transfer_package', {
      p_package: p.id,
      p_new_tutor: target.id,
      p_consent: true,
      p_reason: reason,
    })
    setBusy(null)
    if (error) {
      setNotice(`Gagal: ${error.message}`)
      return
    }
    setNotice(`Paket dipindah ke ${target.full_name}. Booking lama tetap memakai tutor sebelumnya.`)
    load()
  }

  const filtered = useMemo(() => {
    const term = search.trim().toLowerCase()
    if (!term) return rows
    return rows.filter((p) =>
      [p.students?.full_name, p.tutors?.full_name, p.subjects?.name]
        .filter(Boolean)
        .some((value) => value!.toLowerCase().includes(term)),
    )
  }, [rows, search])

  return (
    <section>
      <div className="page-head">
        <div>
          <p className="eyebrow">Bisnis · Paket sesi</p>
          <h1 className="page-title">Paket sesi</h1>
          <p className="page-sub">
            Paket 4/8/12 sesi (diskon 0/5/10%), berlaku 90 hari, kuota hangus bila lewat. Refund hanya dihitung &amp; dicatat — dana dikembalikan manual via Midtrans.
          </p>
        </div>
        <div className="head-actions">
          <div className="search">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" aria-hidden="true">
              <circle cx="11" cy="11" r="7" />
              <path d="m20 20-3.5-3.5" />
            </svg>
            <input
              className="input"
              type="search"
              placeholder="Cari siswa atau tutor"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              aria-label="Cari paket"
            />
          </div>
          <button className="btn btn-ghost btn-sm" onClick={() => setSearch('')}>
            Reset filter
          </button>
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
        <div className="table-wrap">
          <table className="data-table" style={{ minWidth: 880 }}>
            <thead>
              <tr>
                <th>Siswa</th>
                <th>Tutor</th>
                <th>Mapel · jenjang</th>
                <th>Sisa sesi</th>
                <th className="num">Total bayar</th>
                <th>Berlaku sampai</th>
                <th>Status</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan={8}>
                    <div className="empty-state">
                      <strong>Memuat paket…</strong>
                    </div>
                  </td>
                </tr>
              ) : filtered.length === 0 ? (
                <tr>
                  <td colSpan={8}>
                    <div className="empty-state">
                      <strong>Belum ada pembelian paket</strong>
                      <span>Pembelian dari siswa akan tampil di sini.</span>
                    </div>
                  </td>
                </tr>
              ) : (
                filtered.map((p) => {
                  const remaining = sisa(p)
                  const rate = p.total_sesi ? Math.round((remaining / p.total_sesi) * 100) : 0
                  const meta = STATUS_META[p.status] ?? { label: p.status, tone: 'neutral' }
                  return (
                    <tr key={p.id}>
                      <td>
                        <div className="cell-person">
                          <span className="avatar">{initials(p.students?.full_name ?? 'Siswa')}</span>
                          <span className="strong">{p.students?.full_name ?? '—'}</span>
                        </div>
                      </td>
                      <td>{p.tutors?.full_name ?? '—'}</td>
                      <td>
                        {p.subjects?.name ?? '—'} · {p.jenjang}
                        <span className="sub">
                          {p.duration_minutes} menit · {p.mode === 'online' ? 'Online' : 'Offline'}
                          {p.discount_percent > 0 ? ` · diskon ${p.discount_percent}%` : ''}
                        </span>
                      </td>
                      <td>
                        <div className="progress-row">
                          <span className={`progress${rate === 0 ? ' warn' : rate >= 80 ? ' done' : ''}`}>
                            <span style={{ width: `${rate}%` }} />
                          </span>
                          <span className="num">
                            {remaining}/{p.total_sesi}
                          </span>
                        </div>
                      </td>
                      <td className="num">{rupiah(p.price_total)}</td>
                      <td className="num">{tanggal(p.expires_at)}</td>
                      <td>
                        <span className={`badge ${meta.tone}`}>{meta.label}</span>
                      </td>
                      <td>
                        <div className="row-actions">
                          {(p.status === 'active' || p.status === 'expired') && (
                            <>
                              <button
                                className="btn btn-secondary btn-sm"
                                disabled={busy === p.id}
                                onClick={() => onRefund(p)}
                              >
                                Refund {rupiah(refundPreview(p))}
                              </button>
                              <button
                                className="btn btn-ghost btn-sm"
                                disabled={busy === p.id}
                                onClick={() => onTransfer(p)}
                              >
                                Pindah tutor
                              </button>
                            </>
                          )}
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
          <div className="note warn">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
              <path d="M12 3 2.5 20h19L12 3Z" />
              <path d="M12 9v4.5M12 17h.01" />
            </svg>
            <span>Pengembalian dana hanya dicatat di sistem. Dana tetap dikirim manual lewat Midtrans oleh tim keuangan.</span>
          </div>
        </div>
      </div>
    </section>
  )
}
