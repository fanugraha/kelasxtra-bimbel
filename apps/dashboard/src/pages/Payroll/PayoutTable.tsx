import { formatDateOnly, rupiah } from '../../lib/format'
import type { Period, Payout } from './types'

export function PayoutTable({
  selected,
  payouts,
  total,
  onExport,
}: {
  selected: Period
  payouts: Payout[]
  total: number
  onExport: () => void
}) {
  return (
    <div className="card" style={{ marginTop: 14 }}>
      <div className="card-head">
        <div>
          <h2 className="card-title">Rincian {formatDateOnly(selected.period_start)} – {formatDateOnly(selected.period_end)}</h2>
          <p className="card-sub">{payouts.length} tutor · total {rupiah(total)}</p>
        </div>
        <div className="head-actions">
          <button className="btn btn-secondary btn-sm" onClick={onExport} disabled={payouts.length === 0}>
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
  )
}
