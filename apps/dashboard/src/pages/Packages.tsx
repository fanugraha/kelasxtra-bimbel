import { useEffect, useState } from 'react'
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

const STATUS_CLASS: Record<string, string> = {
  active: 'status-aktif',
  pending_payment: 'status-diundang',
  expired: 'status-suspend',
  refunded: 'status-suspend',
  cancelled: 'status-suspend',
}

const STATUS_LABEL: Record<string, string> = {
  active: 'Aktif',
  pending_payment: 'Menunggu bayar',
  expired: 'Kedaluwarsa',
  refunded: 'Direfund',
  cancelled: 'Dibatalkan',
}

const rupiah = (n: number) => 'Rp' + n.toLocaleString('id-ID')

export function Packages() {
  const [rows, setRows] = useState<PackageRow[]>([])
  const [loading, setLoading] = useState(true)
  const [notice, setNotice] = useState<string | null>(null)
  const [busy, setBusy] = useState<string | null>(null)

  async function load() {
    setLoading(true)
    const { data } = await supabase
      .from('package_purchases')
      .select(
        'id, jenjang, duration_minutes, mode, total_sesi, sesi_terpakai, '+ 
          'price_total, discount_percent, status, expires_at, '+ 
          'students(full_name), tutors(full_name), subjects(name)',
      )
      .order('created_at', { ascending: false })
    setRows((data as unknown as PackageRow[]) ?? [])
    setLoading(false)
  }

  useEffect(() => {
    load()
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

  return (
    <section>
      <h1>Paket Sesi</h1>
      <p className="muted">
        Paket 4/8/12 sesi (diskon 0/5/10%), berlaku 90 hari, kuota hangus bila lewat.
        Refund di sini hanya menghitung &amp; mencatat — dana dikembalikan manual via Midtrans.
      </p>

      {notice && <pre className="notice-line">{notice}</pre>}

      {loading ? (
        <p className="muted">Memuat…</p>
      ) : rows.length === 0 ? (
        <p className="muted">Belum ada pembelian paket.</p>
      ) : (
        <table className="table">
          <thead>
            <tr>
              <th>Siswa</th>
              <th>Tutor</th>
              <th>Mapel · Jenjang</th>
              <th>Sesi</th>
              <th>Total bayar</th>
              <th>Berlaku s/d</th>
              <th>Status</th>
              <th>Aksi</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((p) => (
              <tr key={p.id}>
                <td>{p.students?.full_name ?? '—'}</td>
                <td>{p.tutors?.full_name ?? '—'}</td>
                <td>
                  {p.subjects?.name ?? '—'} · {p.jenjang} · {p.duration_minutes} menit ·{' '}
                  {p.mode === 'online' ? 'Online' : 'Offline'}
                </td>
                <td>
                  {p.sesi_terpakai}/{p.total_sesi}
                  {p.discount_percent > 0 && (
                    <span className="muted"> (−{p.discount_percent}%)</span>
                  )}
                </td>
                <td>{rupiah(p.price_total)}</td>
                <td className="muted">
                  {p.expires_at ? new Date(p.expires_at).toLocaleDateString('id-ID') : '—'}
                </td>
                <td>
                  <span className={`status ${STATUS_CLASS[p.status] ?? 'status-diundang'}`}>
                    {STATUS_LABEL[p.status] ?? p.status}
                  </span>
                </td>
                <td className="actions">
                  {p.status === 'active' || p.status === 'expired' ? (
                    <button disabled={busy === p.id} onClick={() => onRefund(p)}>
                      {busy === p.id ? '…' : `Refund ${rupiah(refundPreview(p))}`}
                    </button>
                  ) : (
                    <span className="muted">—</span>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </section>
  )
}
