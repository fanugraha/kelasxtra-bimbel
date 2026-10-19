import { formatDateShort } from '../../lib/format'
import { relative } from './utils'
import type { GroupClass } from './types'

export function GroupSummary({
  attentionCount,
  totalSeats,
  totalCap,
  programCount,
  nearest,
}: {
  attentionCount: number
  totalSeats: number
  totalCap: number
  programCount: number
  nearest: GroupClass | undefined
}) {
  return (
    <div className="grp-summary">
      <article className="grp-summary-card">
        <p className="ov-label">
          <span className="grp-summary-dot" aria-hidden="true" />
          Perlu tindakan
        </p>
        <p className="ov-value">
          <span>{attentionCount}</span>
          <span className="grp-unit">program</span>
        </p>
        <p className="ov-note">Kuota minimum belum terpenuhi</p>
      </article>
      <article className="grp-summary-card">
        <p className="ov-label">Kursi terisi</p>
        <p className="ov-value">
          {totalSeats}
          <span className="grp-unit">/{totalCap}</span>
        </p>
        <p className="ov-note">{programCount} program</p>
      </article>
      <article className="grp-summary-card">
        <p className="ov-label">Batas terdekat</p>
        <p className="ov-value">{nearest ? formatDateShort(nearest.min_confirm_deadline) : '—'}</p>
        <p className="ov-note">
          {nearest ? `${nearest.subjects?.name ?? 'Program'} · ${relative(nearest.min_confirm_deadline)}` : 'Belum ada tenggat'}
        </p>
      </article>
    </div>
  )
}
