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

const STATUS_LABEL: Record<string, string> = {
  open: 'Baru',
  in_review: 'Ditinjau',
  resolved: 'Selesai',
  rejected: 'Ditolak',
}

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
      .select(
        'id, category, body, status, decision, refund_nominal, created_at, ' +
          'bookings(id, scheduled_at, price, students(full_name), tutors(full_name))',
      )
      .order('created_at', { ascending: false })
    if (filter !== 'all') q = q.eq('status', filter)
    const { data, error } = await q
    if (error) setNotice(`Gagal memuat: ${error.message}`)
    setRows((data as unknown as ComplaintRow[]) ?? [])
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
      <h1>Komplain</h1>
      <p className="muted">
        Tiket dari siswa/tutor maksimal H+3 setelah sesi. Selama komplain terbuka,
        penghasilan tutor ditahan. Refund di sini hanya dicatat — dana dikembalikan
        manual via Midtrans.
      </p>

      <div className="actions" style={{ marginBottom: 12 }}>
        <select value={filter} onChange={(e) => setFilter(e.target.value)}>
          <option value="open">Baru</option>
          <option value="in_review">Ditinjau</option>
          <option value="resolved">Selesai</option>
          <option value="rejected">Ditolak</option>
          <option value="all">Semua</option>
        </select>
      </div>

      {notice && <pre className="notice-line">{notice}</pre>}

      {loading ? (
        <p className="muted">Memuat…</p>
      ) : rows.length === 0 ? (
        <p className="muted">Tidak ada komplain.</p>
      ) : (
        <table className="table">
          <thead>
            <tr>
              <th>Tanggal</th>
              <th>Siswa</th>
              <th>Tutor</th>
              <th>Kategori</th>
              <th>Isi</th>
              <th>Status</th>
              <th>Refund</th>
              <th>Aksi</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((c) => (
              <tr key={c.id}>
                <td className="muted">
                  {new Date(c.created_at).toLocaleString('id-ID')}
                </td>
                <td>{c.bookings?.students?.full_name ?? '—'}</td>
                <td>{c.bookings?.tutors?.full_name ?? '—'}</td>
                <td>{CATEGORY_LABEL[c.category] ?? c.category}</td>
                <td>{c.body}</td>
                <td>
                  <span className="status status-diundang">
                    {STATUS_LABEL[c.status] ?? c.status}
                  </span>
                  {c.decision && <div className="muted">{c.decision}</div>}
                </td>
                <td>{c.refund_nominal > 0 ? rupiah(c.refund_nominal) : '—'}</td>
                <td className="actions">
                  {c.status === 'open' || c.status === 'in_review' ? (
                    <>
                      <button disabled={busy === c.id} onClick={() => onResolve(c)}>
                        {busy === c.id ? '…' : 'Selesaikan'}
                      </button>
                      <button disabled={busy === c.id} onClick={() => onReject(c)}>
                        Tolak
                      </button>
                    </>
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
