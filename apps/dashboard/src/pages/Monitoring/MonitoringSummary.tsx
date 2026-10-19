import { rupiah } from '../../lib/format'

export function MonitoringSummary({
  attentionTutors,
  held,
  inProgress,
  pendingBookings,
  groupsOpen,
  completed,
  total,
  completedRate,
}: {
  attentionTutors: number
  held: number
  inProgress: number
  pendingBookings: number
  groupsOpen: number
  completed: number
  total: number
  completedRate: number
}) {
  return (
    <div className="mtr-summary">
      <article className="mtr-summary-card">
        <p className="ov-label">
          <span className="mtr-summary-dot" aria-hidden="true" />
          Perlu koreksi
        </p>
        <p className="ov-value">
          {attentionTutors}
          <span className="mtr-unit">tutor</span>
        </p>
        <p className="ov-note">{rupiah(held)} gaji tertahan</p>
      </article>
      <article className="mtr-summary-card">
        <p className="ov-label">Kelas berjalan</p>
        <p className="ov-value">{inProgress}</p>
        <p className="ov-note">
          {pendingBookings} menunggu bayar · {groupsOpen} kelas grup
        </p>
      </article>
      <article className="mtr-summary-card">
        <p className="ov-label">Sesi selesai</p>
        <p className="ov-value">
          {completed}
          <span className="mtr-unit">/{total}</span>
        </p>
        <p className="ov-note">{completedRate}% dari seluruh sesi</p>
      </article>
    </div>
  )
}
