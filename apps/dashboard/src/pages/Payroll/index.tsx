import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { rupiah } from '../../lib/format'
import { supabase } from '../../lib/supabase'
import { PayrollSummary } from './PayrollSummary'
import { PayoutTable } from './PayoutTable'
import { PeriodRow } from './PeriodRow'
import { defaultPeriod } from './types'
import type { Period, PeriodStat, Payout } from './types'

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

      <PayrollSummary
        pendingCount={pending.length}
        draftCount={draftCount}
        approvedCount={approved.length}
        selected={selected}
        selectedStat={selectedStat}
        approvedTotal={approvedTotal}
      />

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
            periods.map((p) => (
              <PeriodRow
                key={p.id}
                p={p}
                stat={stats[p.id]}
                busy={busy}
                onSelect={setSelected}
                onApprove={onApprove}
                onCancel={onCancel}
                onMarkPaid={onMarkPaid}
              />
            ))
          )}
        </div>
      </div>

      {selected && (
        <PayoutTable
          selected={selected}
          payouts={payouts}
          total={total}
          onExport={exportCsv}
        />
      )}
    </section>
  )
}
