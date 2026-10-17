import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { supabase } from '../lib/supabase'

interface Period {
  id: string
  period_start: string
  period_end: string
  status: string
  created_at: string
  approved_at: string | null
  paid_at: string | null
}

interface Payout {
  id: string
  period_id: string
  amount: number
  status: string
  bank_name: string | null
  bank_account_number: string | null
  bank_account_holder: string | null
  transfer_ref: string | null
  tutors: { full_name: string } | null
  payroll_periods: { period_start: string; period_end: string; status: string } | null
}

interface PeriodStat {
  count: number
  total: number
}

const STATUS_META: Record<string, { label: string; tone: string }> = {
  draft: { label: 'Menunggu persetujuan', tone: 'warning' },
  approved: { label: 'Menunggu transfer', tone: 'info' },
  paid: { label: 'Selesai', tone: 'success' },
}

const rupiah = (n: number) => 'Rp' + n.toLocaleString('id-ID')
const iso = (d: Date) =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(
    d.getDate(),
  ).padStart(2, '0')}`

const tanggal = (value: string) =>
  new Intl.DateTimeFormat('id-ID', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    timeZone: 'Asia/Jakarta',
  }).format(new Date(`${value}T00:00:00+07:00`))

function defaultPeriod() {
  const now = new Date()
  const start = new Date(now.getFullYear(), now.getMonth() - 1, 26)
  const end = new Date(now.getFullYear(), now.getMonth(), 25)
  return { start: iso(start), end: iso(end) }
}

export function Payroll() {
  const [periods, setPeriods] = useState<Period[]>([])
  const [payouts, setPayouts] = useState<Payout[]>([])
  const [stats, setStats] = useState<Record<string, PeriodStat>>({})
  const [selected, setSelected] = useState<Period | null>(null)
  const [range, setRange] = useState(defaultPeriod)
  const [loading, setLoading] = useState(true)
  const [notice, setNotice] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)

  async function loadPeriods(keep?: string) {
    const { data } = await supabase
      .from('payroll_periods')
      .select('id, period_start, period_end, status, created_at, approved_at, paid_at')
      .order('period_start', { ascending: false })
    const rows = (data as Period[]) ?? []
    setPeriods(rows)
    const target = keep ? rows.find((r) => r.id === keep) : selected
    if (target) {
      setSelected(rows.find((r) => r.id === target.id) ?? null)
    } else if (rows.length > 0) {
      setSelected(rows[0])
    }

    const { data: allPayouts } = await supabase.from('payouts').select('period_id, amount')
    const map: Record<string, PeriodStat> = {}
    for (const p of (allPayouts ?? []) as { period_id: string; amount: number }[]) {
      const entry = (map[p.period_id] ??= { count: 0, total: 0 })
      entry.count += 1
      entry.total += Number(p.amount)
    }
    setStats(map)
    setLoading(false)
  }

  async function loadPayouts(periodId: string) {
    const { data } = await supabase
      .from('payouts')
      .select(
        'id, period_id, amount, status, bank_name, bank_account_number, ' +
          'bank_account_holder, transfer_ref, tutors(full_name), ' +
          'payroll_periods(period_start, period_end, status)',
      )
      .eq('period_id', periodId)
      .order('amount', { ascending: false })
    setPayouts((data as unknown as Payout[]) ?? [])
  }

  useEffect(() => {
    queueMicrotask(() => loadPeriods())
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  useEffect(() => {
    if (selected) queueMicrotask(() => loadPayouts(selected.id))
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selected?.id])

  async function onGenerate() {
    if (!confirm(`Buat rekap payroll ${range.start} s/d ${range.end}?`)) return
    setBusy(true)
    setNotice(null)
    const { data, error } = await supabase.rpc('admin_generate_payroll', {
      p_start: range.start,
      p_end: range.end,
    })
    setBusy(false)
    if (error) {
      setNotice(`Gagal: ${error.message}`)
      return
    }
    const res = data as { period_id: string; payouts: number; earnings: number; total: number }
    setNotice(
      `Periode dibuat: ${res.payouts} tutor, ${res.earnings} sesi, total ${rupiah(res.total)}.`,
    )
    loadPeriods(res.period_id)
  }

  async function onApprove(p: Period) {
    if (
      !confirm(
        `Setujui payroll ${p.period_start} s/d ${p.period_end}?\n` +
          'Four-eyes: kamu tidak boleh menyetujui periode yang kamu buat sendiri.',
      )
    )
      return
    setBusy(true)
    setNotice(null)
    const { error } = await supabase.rpc('admin_approve_payroll', { p_period: p.id })
    setBusy(false)
    if (error) {
      setNotice(`Gagal: ${error.message}`)
      return
    }
    setNotice('Periode disetujui. Silakan transfer manual lalu tandai.')
    loadPeriods(p.id)
  }

  async function onMarkPaid(p: Period) {
    const ref = prompt('Referensi transfer bank (contoh: BCA-20261028-001):')
    if (!ref) return
    if (
      !confirm(
        `Tandai periode ${p.period_start} s/d ${p.period_end} SUDAH ditransfer?\n` +
          'Status earning tutor akan menjadi sudah_dibayar.',
      )
    )
      return
    setBusy(true)
    setNotice(null)
    const { error } = await supabase.rpc('admin_mark_payroll_paid', {
      p_period: p.id,
      p_transfer_ref: ref,
    })
    setBusy(false)
    if (error) {
      setNotice(`Gagal: ${error.message}`)
      return
    }
    setNotice('Periode ditandai sudah ditransfer.')
    loadPeriods(p.id)
  }

  async function onCancel(p: Period) {
    if (!confirm('Batalkan periode draft ini? Earning akan dilepas ke periode berikutnya.')) return
    setBusy(true)
    setNotice(null)
    const { error } = await supabase.rpc('admin_cancel_payroll', { p_period: p.id })
    setBusy(false)
    if (error) {
      setNotice(`Gagal: ${error.message}`)
      return
    }
    setNotice('Periode draft dibatalkan.')
    setSelected(null)
    setPayouts([])
    loadPeriods()
  }

  function exportCsv() {
    if (!selected) return
    const header = [
      'tutor',
      'bank',
      'nomor_rekening',
      'pemilik_rekening',
      'nominal',
      'status',
      'referensi_transfer',
    ]
    const lines = payouts.map((p) =>
      [
        p.tutors?.full_name ?? '',
        p.bank_name ?? '',
        p.bank_account_number ?? '',
        p.bank_account_holder ?? '',
        String(p.amount),
        p.status,
        p.transfer_ref ?? '',
      ]
        .map((v) => `"${v.replaceAll('"', '""')}"`)
        .join(','),
    )
    const blob = new Blob([[header.join(','), ...lines].join('\n')], {
      type: 'text/csv;charset=utf-8',
    })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `payroll-${selected.period_start}-${selected.period_end}.csv`
    a.click()
    URL.revokeObjectURL(url)
  }

  const total = payouts.reduce((sum, p) => sum + p.amount, 0)
  const pending = periods.filter((p) => p.status !== 'paid')
  const draftCount = periods.filter((p) => p.status === 'draft').length
  const approved = periods.filter((p) => p.status === 'approved')
  const approvedTotal = approved.reduce((sum, p) => sum + (stats[p.id]?.total ?? 0), 0)
  const selectedStat = selected ? stats[selected.id] : undefined

  function steps(status: string) {
    return {
      created: 'is-done',
      approved: status === 'draft' ? 'is-current' : 'is-done',
      transfer: status === 'paid' ? 'is-done' : status === 'approved' ? 'is-current' : '',
    }
  }

  return (
    <section>
      <div className="page-head">
        <div>
          <p className="eyebrow">Bisnis · Gaji tutor</p>
          <h1 className="page-title">Gaji tutor</h1>
          <p className="page-sub">
            Setujui rekap, lalu catat transfer manual. Cut-off tanggal 25 WIB · four-eyes: approver harus admin lain.
          </p>
        </div>
        <div className="head-actions">
          <Link className="btn btn-secondary" to="/audit-log">
            Riwayat aktivitas
          </Link>
        </div>
      </div>

      <div className="pay-summary">
        <article className="pay-summary-card">
          <p className="ov-label">
            <span className="pay-summary-dot" aria-hidden="true" />
            Perlu tindakan
          </p>
          <p className="ov-value">
            <span>{pending.length}</span>
            <span className="pay-unit">rekap</span>
          </p>
          <p className="ov-note">{draftCount} persetujuan · {approved.length} transfer</p>
        </article>
        <article className="pay-summary-card">
          <p className="ov-label">Periode terpilih</p>
          <p className="ov-value">{selectedStat ? rupiah(selectedStat.total) : '—'}</p>
          <p className="ov-note">
            {selected ? `${tanggal(selected.period_start)} – ${tanggal(selected.period_end)}` : 'Belum ada periode'}
            {selectedStat ? ` · ${selectedStat.count} tutor` : ''}
          </p>
        </article>
        <article className="pay-summary-card">
          <p className="ov-label">Menunggu transfer</p>
          <p className="ov-value">{rupiah(approvedTotal)}</p>
          <p className="ov-note">{approved.length} rekap disetujui</p>
        </article>
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
        <div className="card-head">
          <div>
            <h2 className="card-title">Rekap per periode</h2>
            <p className="card-sub">Buat periode baru sesuai rentang cut-off</p>
          </div>
          <div className="head-actions">
            <label className="field">
              <span className="hint">Mulai</span>
              <input className="input" type="date" value={range.start} onChange={(e) => setRange({ ...range, start: e.target.value })} />
            </label>
            <label className="field">
              <span className="hint">Selesai</span>
              <input className="input" type="date" value={range.end} onChange={(e) => setRange({ ...range, end: e.target.value })} />
            </label>
            <button className="btn btn-primary" disabled={busy} onClick={onGenerate}>
              {busy ? 'Memproses…' : 'Buat rekap'}
            </button>
          </div>
        </div>

        <div className="pay-list">
          {loading ? (
            <div className="empty-state">
              <strong>Memuat periode…</strong>
            </div>
          ) : periods.length === 0 ? (
            <div className="empty-state">
              <strong>Belum ada periode payroll</strong>
              <span>Buat rekap pertama lewat tombol Buat rekap.</span>
            </div>
          ) : (
            periods.map((p) => {
              const meta = STATUS_META[p.status] ?? { label: p.status, tone: 'neutral' }
              const stat = stats[p.id]
              const track = steps(p.status)
              return (
                <article
                  className="pay-row"
                  key={p.id}
                  style={{ cursor: 'pointer' }}
                  onClick={() => setSelected(p)}
                >
                  <div className="pay-row-main">
                    <div className="pay-row-title">
                      <h3>{tanggal(p.period_start)} – {tanggal(p.period_end)}</h3>
                      <span className={`badge ${meta.tone}`}>{meta.label}</span>
                    </div>
                    <p className="pay-row-meta">{stat?.count ?? 0} tutor</p>
                  </div>
                  <div className="pay-track" aria-label="Progres rekap">
                    <span className={`pay-track-step ${track.created}`}>Dibuat</span>
                    <span className={`pay-track-line ${p.status !== 'draft' ? 'is-done' : ''}`} />
                    <span className={`pay-track-step ${track.approved}`}>Persetujuan</span>
                    <span className={`pay-track-line ${p.status === 'paid' ? 'is-done' : ''}`} />
                    <span className={`pay-track-step ${track.transfer}`}>Transfer</span>
                  </div>
                  <div className="pay-row-amount">
                    <strong className="pay-amount">{rupiah(stat?.total ?? 0)}</strong>
                    <span className="pay-amount-sub">
                      {p.status === 'paid' ? 'Sudah ditransfer' : p.status === 'approved' ? 'Siap ditransfer' : 'Menunggu persetujuan'}
                    </span>
                  </div>
                  <div className="pay-row-actions">
                    <button className="btn btn-ghost btn-sm" onClick={(e) => { e.stopPropagation(); setSelected(p) }}>
                      Rincian
                    </button>
                    {p.status === 'draft' && (
                      <>
                        <button className="btn btn-primary btn-sm" disabled={busy} onClick={(e) => { e.stopPropagation(); onApprove(p) }}>
                          Setujui
                        </button>
                        <button className="btn btn-ghost btn-sm" disabled={busy} onClick={(e) => { e.stopPropagation(); onCancel(p) }}>
                          Batalkan
                        </button>
                      </>
                    )}
                    {p.status === 'approved' && (
                      <button className="btn btn-secondary btn-sm" disabled={busy} onClick={(e) => { e.stopPropagation(); onMarkPaid(p) }}>
                        Tandai ditransfer
                      </button>
                    )}
                  </div>
                </article>
              )
            })
          )}
        </div>
      </div>

      {selected && (
        <div className="card" style={{ marginTop: 14 }}>
          <div className="card-head">
            <div>
              <h2 className="card-title">Rincian {tanggal(selected.period_start)} – {tanggal(selected.period_end)}</h2>
              <p className="card-sub">{payouts.length} tutor · total {rupiah(total)}</p>
            </div>
            <div className="head-actions">
              <button className="btn btn-secondary btn-sm" onClick={exportCsv} disabled={payouts.length === 0}>
                Ekspor CSV
              </button>
            </div>
          </div>
          <div className="table-wrap">
            <table className="data-table" style={{ minWidth: 820 }}>
              <thead>
                <tr>
                  <th>Tutor</th>
                  <th>Bank</th>
                  <th>Nomor</th>
                  <th>Pemilik</th>
                  <th className="num">Nominal</th>
                  <th>Status</th>
                  <th>Referensi</th>
                </tr>
              </thead>
              <tbody>
                {payouts.length === 0 ? (
                  <tr>
                    <td colSpan={7}>
                      <div className="empty-state">
                        <strong>Tidak ada earning</strong>
                        <span>Periode ini belum punya honor tutor.</span>
                      </div>
                    </td>
                  </tr>
                ) : (
                  payouts.map((p) => (
                    <tr key={p.id}>
                      <td className="strong">{p.tutors?.full_name ?? '—'}</td>
                      <td>{p.bank_name ?? 'Belum diisi'}</td>
                      <td className="num">{p.bank_account_number ?? '—'}</td>
                      <td>{p.bank_account_holder ?? '—'}</td>
                      <td className="num">{rupiah(p.amount)}</td>
                      <td>
                        <span className={`badge ${p.status === 'sudah_dibayar' ? 'success' : p.status === 'ditahan' ? 'danger' : 'warning'}`}>
                          {p.status === 'sudah_dibayar' ? 'Dibayar' : p.status === 'ditahan' ? 'Tertahan' : 'Belum dibayar'}
                        </span>
                      </td>
                      <td className="num">{p.transfer_ref ?? '—'}</td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </section>
  )
}
