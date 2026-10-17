import { useEffect, useState } from 'react'
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

const STATUS_LABEL: Record<string, string> = {
  draft: 'Draft',
  approved: 'Disetujui',
  paid: 'Sudah ditransfer',
}

const rupiah = (n: number) => 'Rp' + n.toLocaleString('id-ID')
const iso = (d: Date) =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(
    d.getDate(),
  ).padStart(2, '0')}`

function defaultPeriod() {
  const now = new Date()
  const start = new Date(now.getFullYear(), now.getMonth() - 1, 26)
  const end = new Date(now.getFullYear(), now.getMonth(), 25)
  return { start: iso(start), end: iso(end) }
}

export function Payroll() {
  const [periods, setPeriods] = useState<Period[]>([])
  const [payouts, setPayouts] = useState<Payout[]>([])
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

  const total = payouts.reduce((s, p) => s + p.amount, 0)

  return (
    <section>
      <h1>Payroll</h1>
      <p className="muted">
        Rekap honor tutor dari ledger. Cut-off tgl 25 (WIB). Transfer dilakukan manual
        lewat bank; di sini hanya approval, ekspor, dan penandaan bukti transfer.
        Four-eyes: approver harus admin lain.
      </p>

      <div className="tutor-form">
        <label>
          Mulai
          <input
            type="date"
            value={range.start}
            onChange={(e) => setRange({ ...range, start: e.target.value })}
          />
        </label>
        <label>
          Selesai
          <input
            type="date"
            value={range.end}
            onChange={(e) => setRange({ ...range, end: e.target.value })}
          />
        </label>
        <button disabled={busy} onClick={onGenerate}>
          {busy ? 'Memproses…' : 'Buat rekap'}
        </button>
      </div>

      {notice && <pre className="notice-line">{notice}</pre>}

      {loading ? (
        <p className="muted">Memuat…</p>
      ) : periods.length === 0 ? (
        <p className="muted">Belum ada periode payroll.</p>
      ) : (
        <table className="table">
          <thead>
            <tr>
              <th>Periode</th>
              <th>Status</th>
              <th>Disetujui</th>
              <th>Dibayar</th>
              <th>Aksi</th>
            </tr>
          </thead>
          <tbody>
            {periods.map((p) => (
              <tr
                key={p.id}
                style={{ cursor: 'pointer', fontWeight: selected?.id === p.id ? 700 : 400 }}
                onClick={() => setSelected(p)}
              >
                <td>
                  {p.period_start} s/d {p.period_end}
                </td>
                <td>
                  <span className="status status-diundang">
                    {STATUS_LABEL[p.status] ?? p.status}
                  </span>
                </td>
                <td className="muted">{p.approved_at ? 'Ya' : '—'}</td>
                <td className="muted">{p.paid_at ? 'Ya' : '—'}</td>
                <td className="actions">
                  {p.status === 'draft' && (
                    <>
                      <button disabled={busy} onClick={() => onApprove(p)}>
                        Setujui
                      </button>
                      <button disabled={busy} onClick={() => onCancel(p)}>
                        Batalkan
                      </button>
                    </>
                  )}
                  {p.status === 'approved' && (
                    <button disabled={busy} onClick={() => onMarkPaid(p)}>
                      Tandai ditransfer
                    </button>
                  )}
                  {p.status === 'paid' && <span className="muted">Selesai</span>}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}

      {selected && (
        <>
          <div className="actions" style={{ margin: '16px 0' }}>
            <strong>
              {payouts.length} tutor · total {rupiah(total)}
            </strong>
            <button onClick={exportCsv}>Ekspor CSV</button>
          </div>
          <table className="table">
            <thead>
              <tr>
                <th>Tutor</th>
                <th>Bank</th>
                <th>Nomor</th>
                <th>Pemilik</th>
                <th>Nominal</th>
                <th>Status</th>
                <th>Referensi</th>
              </tr>
            </thead>
            <tbody>
              {payouts.length === 0 ? (
                <tr>
                  <td colSpan={7} className="muted">
                    Tidak ada earning pada periode ini.
                  </td>
                </tr>
              ) : (
                payouts.map((p) => (
                  <tr key={p.id}>
                    <td>{p.tutors?.full_name ?? '—'}</td>
                    <td className="muted">{p.bank_name ?? 'Belum diisi'}</td>
                    <td className="muted">{p.bank_account_number ?? '—'}</td>
                    <td className="muted">{p.bank_account_holder ?? '—'}</td>
                    <td>{rupiah(p.amount)}</td>
                    <td>{STATUS_LABEL[p.status] ?? p.status}</td>
                    <td className="muted">{p.transfer_ref ?? '—'}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </>
      )}
    </section>
  )
}
