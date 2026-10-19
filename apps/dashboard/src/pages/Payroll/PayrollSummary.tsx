import { formatDateOnly, rupiah } from '../../lib/format'
import type { Period, PeriodStat } from './types'

export function PayrollSummary({
  pendingCount,
  draftCount,
  approvedCount,
  selected,
  selectedStat,
  approvedTotal,
}: {
  pendingCount: number
  draftCount: number
  approvedCount: number
  selected: Period | null
  selectedStat: PeriodStat | undefined
  approvedTotal: number
}) {
  return (
    <div className="pay-summary">
      <article className="pay-summary-card">
        <p className="ov-label">
          <span className="pay-summary-dot" aria-hidden="true" />
          Perlu tindakan
        </p>
        <p className="ov-value">
          <span>{pendingCount}</span>
          <span className="pay-unit">rekap</span>
        </p>
        <p className="ov-note">{draftCount} persetujuan · {approvedCount} transfer</p>
      </article>
      <article className="pay-summary-card">
        <p className="ov-label">Periode terpilih</p>
        <p className="ov-value">{selectedStat ? rupiah(selectedStat.total) : '—'}</p>
        <p className="ov-note">
          {selected ? `${formatDateOnly(selected.period_start)} – ${formatDateOnly(selected.period_end)}` : 'Belum ada periode'}
          {selectedStat ? ` · ${selectedStat.count} tutor` : ''}
        </p>
      </article>
      <article className="pay-summary-card">
        <p className="ov-label">Menunggu transfer</p>
        <p className="ov-value">{rupiah(approvedTotal)}</p>
        <p className="ov-note">{approvedCount} rekap disetujui</p>
      </article>
    </div>
  )
}
