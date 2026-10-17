import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'

interface Metrics {
  revenue: {
    gross: number
    gateway_fee: number
    refunds: number
    platform_share: number
    tutor_earnings: number
    tutor_unpaid: number
    tutor_paid: number
  }
}

interface PaymentRow {
  id: string
  order_id: string
  type: string
  amount: number
  gateway_fee: number
  status: string
  paid_at: string | null
  created_at: string
}

interface EarningRow {
  id: string
  amount_tutor: number
  amount_platform: number
  status: string
  source: string
  session_at: string
  tutors: { full_name: string } | null
}

const rupiah = (n: number) => 'Rp' + n.toLocaleString('id-ID')
const iso = (d: Date) =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(
    d.getDate(),
  ).padStart(2, '0')}`

export function Finance() {
  const now = new Date()
  const [from, setFrom] = useState(iso(new Date(now.getFullYear(), now.getMonth(), 1)))
  const [to, setTo] = useState(iso(now))
  const [metrics, setMetrics] = useState<Metrics | null>(null)
  const [payments, setPayments] = useState<PaymentRow[]>([])
  const [earnings, setEarnings] = useState<EarningRow[]>([])
  const [loading, setLoading] = useState(true)
  const [notice, setNotice] = useState<string | null>(null)

  async function load() {
    setLoading(true)
    setNotice(null)
    const { data, error } = await supabase.rpc('admin_metrics', { p_from: from, p_to: to })
    if (error) setNotice(`Gagal metrik: ${error.message}`)
    else setMetrics(data as Metrics)

    const { data: pay } = await supabase
      .from('payments')
      .select('id, order_id, type, amount, gateway_fee, status, paid_at, created_at')
      .order('created_at', { ascending: false })
      .limit(30)
    setPayments((pay as PaymentRow[]) ?? [])

    const { data: earn } = await supabase
      .from('tutor_earnings')
      .select('id, amount_tutor, amount_platform, status, source, session_at, tutors(full_name)')
      .order('session_at', { ascending: false })
      .limit(30)
    setEarnings((earn as unknown as EarningRow[]) ?? [])
    setLoading(false)
  }

  useEffect(() => {
    queueMicrotask(load)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  const r = metrics?.revenue

  return (
    <section>
      <h1>Keuangan</h1>
      <p className="muted">
        Gross gateway, estimasi biaya gateway (dari webhook), potongan platform 25%,
        refund tercatat, dan posisi honor tutor. Payroll ada di modul Payroll.
      </p>

      <div className="tutor-form">
        <label>
          Dari
          <input type="date" value={from} onChange={(e) => setFrom(e.target.value)} />
        </label>
        <label>
          Sampai
          <input type="date" value={to} onChange={(e) => setTo(e.target.value)} />
        </label>
        <button onClick={load} disabled={loading}>
          {loading ? 'Memuat…' : 'Terapkan'}
        </button>
      </div>

      {notice && <pre className="notice-line">{notice}</pre>}

      {r && (
        <div className="cards">
          <div className="card">
            <h3>Gross (settlement)</h3>
            <p className="muted">{rupiah(r.gross)}</p>
          </div>
          <div className="card">
            <h3>Biaya gateway</h3>
            <p className="muted">{rupiah(r.gateway_fee)}</p>
          </div>
          <div className="card">
            <h3>Potongan platform</h3>
            <p className="muted">{rupiah(r.platform_share)}</p>
          </div>
          <div className="card">
            <h3>Honor tutor</h3>
            <p className="muted">
              {rupiah(r.tutor_earnings)} · belum bayar {rupiah(r.tutor_unpaid)}
            </p>
          </div>
          <div className="card">
            <h3>Refund tercatat</h3>
            <p className="muted">{rupiah(r.refunds)}</p>
          </div>
        </div>
      )}

      <h2>Transaksi terbaru</h2>
      <table className="table">
        <thead>
          <tr>
            <th>Order</th>
            <th>Tipe</th>
            <th>Nominal</th>
            <th>Gateway</th>
            <th>Status</th>
            <th>Dibayar</th>
          </tr>
        </thead>
        <tbody>
          {payments.length === 0 ? (
            <tr>
              <td colSpan={6} className="muted">
                Belum ada transaksi.
              </td>
            </tr>
          ) : (
            payments.map((p) => (
              <tr key={p.id}>
                <td className="muted">{p.order_id}</td>
                <td>{p.type}</td>
                <td>{rupiah(p.amount)}</td>
                <td className="muted">{rupiah(p.gateway_fee)}</td>
                <td>{p.status}</td>
                <td className="muted">
                  {p.paid_at ? new Date(p.paid_at).toLocaleDateString('id-ID') : '—'}
                </td>
              </tr>
            ))
          )}
        </tbody>
      </table>

      <h2>Ledger honor tutor</h2>
      <table className="table">
        <thead>
          <tr>
            <th>Tanggal sesi</th>
            <th>Tutor</th>
            <th>Sumber</th>
            <th>Honor tutor</th>
            <th>Platform</th>
            <th>Status</th>
          </tr>
        </thead>
        <tbody>
          {earnings.length === 0 ? (
            <tr>
              <td colSpan={6} className="muted">
                Belum ada earning.
              </td>
            </tr>
          ) : (
            earnings.map((e) => (
              <tr key={e.id}>
                <td className="muted">
                  {new Date(e.session_at).toLocaleDateString('id-ID')}
                </td>
                <td>{e.tutors?.full_name ?? '—'}</td>
                <td>{e.source === 'group' ? 'Kelas grup' : 'Privat'}</td>
                <td>{rupiah(e.amount_tutor)}</td>
                <td className="muted">{rupiah(e.amount_platform)}</td>
                <td>{e.status}</td>
              </tr>
            ))
          )}
        </tbody>
      </table>
    </section>
  )
}
