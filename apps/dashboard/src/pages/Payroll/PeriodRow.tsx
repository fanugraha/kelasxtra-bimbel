import { formatDateOnly, rupiah } from '../../lib/format'
import { STATUS_META } from './types'
import type { Period, PeriodStat } from './types'

function steps(status: string) {
  return {
    created: 'is-done',
    approved: status === 'draft' ? 'is-current' : 'is-done',
    transfer: status === 'paid' ? 'is-done' : status === 'approved' ? 'is-current' : '',
  }
}

export function PeriodRow({
  p,
  stat,
  busy,
  onSelect,
  onApprove,
  onCancel,
  onMarkPaid,
}: {
  p: Period
  stat: PeriodStat | undefined
  busy: boolean
  onSelect: (period: Period) => void
  onApprove: (period: Period) => void
  onCancel: (period: Period) => void
  onMarkPaid: (period: Period) => void
}) {
  const meta = STATUS_META[p.status] ?? { label: p.status, tone: 'neutral' }
  const track = steps(p.status)

  return (
    <article className="pay-row" style={{ cursor: 'pointer' }} onClick={() => onSelect(p)}>
      <div className="pay-row-main">
        <div className="pay-row-title">
          <h3>{formatDateOnly(p.period_start)} – {formatDateOnly(p.period_end)}</h3>
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
        <button className="btn btn-ghost btn-sm" onClick={(e) => { e.stopPropagation(); onSelect(p) }}>
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
}
