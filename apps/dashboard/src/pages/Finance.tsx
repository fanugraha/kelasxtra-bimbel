import { useEffect, useState } from 'react'
import { formatDateTime, isoDate, rupiah } from '../lib/format'
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

const PAYMENT_META: Record<string, { label: string; tone: string }> = {
  settlement: { label: 'Berhasil', tone: 'success' },
  capture: { label: 'Berhasil', tone: 'success' },
  pending: { label: 'Menunggu', tone: 'warning' },
  deny: { label: 'Ditolak', tone: 'danger' },
  cancel: { label: 'Batal', tone: 'danger' },
  expire: { label: 'Kedaluwarsa', tone: 'neutral' },
  refund: { label: 'Dikembalikan', tone: 'neutral' },
}

const EARNING_META: Record<string, { label: string; tone: string }> = {
  belum_dibayar: { label: 'Belum dibayar', tone: 'warning' },
  ditahan: { label: 'Tertahan', tone: 'danger' },
  sudah_dibayar: { label: 'Dibayar', tone: 'success' },
}

const TYPE_LABEL: Record<string, string> = {
  booking: 'Sesi privat',
  package: 'Paket sesi',
  group_seat: 'Kelas grup',
  subscription: 'Langganan bank soal',
}

export function Finance() {
  const now = new Date()
  const [from, setFrom] = useState(isoDate(new Date(now.getFullYear(), now.getMonth(), 1)))
  const [to, setTo] = useState(isoDate(now))
  const [metrics, setMetrics] = useState<Metrics | null>(null)
  const [payments, setPayments] = useState<PaymentRow[]>([])
  const [earnings, setEarnings] = useState<EarningRow[]>([])
  const [loading, setLoading] = useState(true)
  const [notice, setNotice] = useState<string | null>(null)
  const [tab, setTab] = useState<'trx' | 'ledger'>('trx')

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
      <div className="page-head">
        <div>
          <p className="eyebrow">Bisnis · Keuangan</p>
          <h1 className="page-title">Keuangan</h1>
          <p className="page-sub">
            Cocokkan pembayaran masuk, potongan aplikasi 25%, gaji tutor, dan pengembalian dana.
          </p>
        </div>
        <div className="head-actions">
          <label className="field">
            <span className="hint">Dari</span>
            <input className="input" type="date" value={from} onChange={(e) => setFrom(e.target.value)} />
          </label>
          <label className="field">
            <span className="hint">Sampai</span>
            <input className="input" type="date" value={to} onChange={(e) => setTo(e.target.value)} />
          </label>
          <button className="btn btn-secondary" onClick={load} disabled={loading}>
            {loading ? 'Memuat…' : 'Terapkan'}
          </button>
        </div>
      </div>

      {notice && (
        <div className="note warn" style={{ marginBottom: 14 }}>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
            <path d="M12 3 2.5 20h19L12 3Z" />
            <path d="M12 9v4.5M12 17h.01" />
          </svg>
          <span>{notice}</span>
        </div>
      )}

      <div className="stat-strip">
        <div className="mini-stat">
          <p className="mini-label">Pembayaran masuk</p>
          <div className="mini-value">{r ? rupiah(r.gross) : '—'}</div>
          <p className="mini-sub">{from} – {to}</p>
        </div>
        <div className="mini-stat">
          <p className="mini-label">Biaya pembayaran</p>
          <div className="mini-value">{r ? rupiah(r.gateway_fee) : '—'}</div>
          <p className="mini-sub">dari webhook</p>
        </div>
        <div className="mini-stat">
          <p className="mini-label">Potongan aplikasi</p>
          <div className="mini-value">{r ? rupiah(r.platform_share) : '—'}</div>
          <p className="mini-sub">25% dari pembayaran masuk</p>
        </div>
        <div className="mini-stat">
          <p className="mini-label">Pengembalian dana</p>
          <div className="mini-value" style={{ color: 'var(--danger)' }}>
            {r ? rupiah(r.refunds) : '—'}
          </div>
          <p className="mini-sub">tercatat di sistem</p>
        </div>
      </div>

      <div className="card">
        <div className="toolbar">
          <div className="segmented" role="group" aria-label="Jenis data">
            <button aria-pressed={tab === 'trx'} onClick={() => setTab('trx')}>
              Transaksi
            </button>
            <button aria-pressed={tab === 'ledger'} onClick={() => setTab('ledger')}>
              Gaji tutor
            </button>
          </div>
          <div className="spacer" />
          <span className="sub" style={{ fontSize: 11, color: 'var(--muted)' }}>
            Zona waktu WIB
          </span>
        </div>

        {tab === 'trx' ? (
          <div className="table-wrap">
            <table className="data-table" style={{ minWidth: 820 }}>
              <thead>
                <tr>
                  <th>Pesanan</th>
                  <th>Jenis</th>
                  <th className="num">Jumlah</th>
                  <th className="num">Biaya bayar</th>
                  <th>Status</th>
                  <th>Tanggal bayar</th>
                </tr>
              </thead>
              <tbody>
                {payments.length === 0 ? (
                  <tr>
                    <td colSpan={6}>
                      <div className="empty-state">
                        <strong>Belum ada transaksi</strong>
                        <span>Pembayaran masuk akan tampil di sini.</span>
                      </div>
                    </td>
                  </tr>
                ) : (
                  payments.map((p) => {
                    const meta = PAYMENT_META[p.status] ?? { label: p.status, tone: 'neutral' }
                    return (
                      <tr key={p.id}>
                        <td className="num">{p.order_id}</td>
                        <td>{TYPE_LABEL[p.type] ?? p.type}</td>
                        <td className="num">{rupiah(p.amount)}</td>
                        <td className="num">{rupiah(p.gateway_fee ?? 0)}</td>
                        <td><span className={`badge ${meta.tone}`}>{meta.label}</span></td>
                        <td className="num">
                          {p.paid_at ? formatDateTime(p.paid_at) : '—'}
                        </td>
                      </tr>
                    )
                  })
                )}
              </tbody>
            </table>
          </div>
        ) : (
          <div className="table-wrap">
            <table className="data-table" style={{ minWidth: 820 }}>
              <thead>
                <tr>
                  <th>Tanggal sesi</th>
                  <th>Tutor</th>
                  <th>Sumber</th>
                  <th className="num">Gaji tutor</th>
                  <th className="num">Aplikasi</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                {earnings.length === 0 ? (
                  <tr>
                    <td colSpan={6}>
                      <div className="empty-state">
                        <strong>Belum ada earning</strong>
                        <span>Honor tutor muncul setelah sesi selesai.</span>
                      </div>
                    </td>
                  </tr>
                ) : (
                  earnings.map((e) => {
                    const meta = EARNING_META[e.status] ?? { label: e.status, tone: 'neutral' }
                    return (
                      <tr key={e.id}>
                        <td className="num">
                          {formatDateTime(e.session_at)}
                        </td>
                        <td>{e.tutors?.full_name ?? '—'}</td>
                        <td>{e.source === 'group' ? 'Kelas grup' : e.source === 'package' ? 'Paket' : 'Privat'}</td>
                        <td className="num">{rupiah(e.amount_tutor)}</td>
                        <td className="num">{rupiah(e.amount_platform)}</td>
                        <td><span className={`badge ${meta.tone}`}>{meta.label}</span></td>
                      </tr>
                    )
                  })
                )}
              </tbody>
            </table>
          </div>
        )}

        <div className="card-foot">
          <div className="note">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
              <circle cx="12" cy="12" r="9" />
              <path d="M12 11v5M12 8h.01" />
            </svg>
            <span>Honor tutor belum dibayar: {r ? rupiah(r.tutor_unpaid) : '—'} · sudah dibayar: {r ? rupiah(r.tutor_paid) : '—'}.</span>
          </div>
        </div>
      </div>
    </section>
  )
}
