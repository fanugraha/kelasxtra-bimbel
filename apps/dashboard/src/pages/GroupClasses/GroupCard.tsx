import { formatDateShort, formatTime, rupiah } from '../../lib/format'
import { SEAT_META, STATUS_META } from './types'
import type { GroupClass, Seat } from './types'
import { fullDate, relative, sessionRange } from './utils'

export function GroupCard({
  row,
  open,
  seats,
  onToggleSeats,
  onCancelToCredit,
}: {
  row: GroupClass
  open: boolean
  seats: Seat[] | undefined
  onToggleSeats: () => void
  onCancelToCredit: (seat: Seat) => void
}) {
  const meta = STATUS_META[row.status] ?? { label: row.status, tone: 'neutral' }
  const span = sessionRange(row)
  const fill = Math.round((row.seats_taken / row.max_seats) * 100)
  const lacking = Math.max(0, row.min_seats - row.seats_taken)

  return (
    <div>
      <article className="grp-item">
        <div className="grp-item-main">
          <div className="grp-title">
            <h3>{row.subjects?.name ?? 'Kelas grup'}</h3>
            <span className={`badge ${meta.tone}`}>{meta.label}</span>
          </div>
          <p className="grp-meta">
            {row.tutors?.full_name ?? '—'} · {row.jenjang} ·{' '}
            {row.mode === 'online' ? 'Online' : `Offline · ${row.rooms?.name ?? '—'}`}
          </p>
        </div>
        <div className="grp-schedule">
          <span className="grp-date">
            {span.first ? formatDateShort(span.first) : '—'} – {span.last ? formatDateShort(span.last) : '—'}
          </span>
          <span className="grp-time">{span.first ? formatTime(span.first) : '—'} WIB · {row.total_sesi}×</span>
        </div>
        <div className="grp-fill">
          <div className="progress-row">
            <span className={`progress${row.seats_taken >= row.max_seats ? ' done' : row.seats_taken < row.min_seats ? ' warn' : ''}`}>
              <span style={{ width: `${fill}%` }} />
            </span>
            <span className="num">{row.seats_taken}/{row.max_seats}</span>
          </div>
          <span className={`grp-fill-note${lacking > 0 ? ' is-danger' : ''}`}>
            {lacking > 0 ? `Kurang ${lacking} siswa` : row.seats_taken >= row.max_seats ? 'Kursi penuh' : `Sisa ${row.max_seats - row.seats_taken} kursi`}
          </span>
        </div>
        <div className="grp-due">
          <span className="grp-date">{formatDateShort(row.min_confirm_deadline)}</span>
          <span className="grp-time">{relative(row.min_confirm_deadline)}</span>
        </div>
        <div className="grp-actions">
          <button className="btn btn-secondary btn-sm" onClick={onToggleSeats}>
            {open ? 'Tutup' : 'Kelola kursi'}
          </button>
        </div>
      </article>
      <div className="grp-detail" hidden={!open}>
        <div className="grp-detail-panel">
          <dl className="grp-detail-grid">
            <div>
              <dt>Tempat</dt>
              <dd>
                {row.mode === 'online' ? 'Online' : row.rooms?.name ?? '—'}
                <span>{row.mode === 'online' ? 'Tautan dikirim H-1' : `${row.jenjang} · ${row.duration_minutes} menit`}</span>
              </dd>
            </div>
            <div>
              <dt>Harga / sesi</dt>
              <dd>{rupiah(row.price_per_session)}<span>per siswa</span></dd>
            </div>
            <div>
              <dt>Kursi</dt>
              <dd>{row.seats_taken} dari {row.max_seats}<span>minimal {row.min_seats}</span></dd>
            </div>
            <div>
              <dt>Batas waktu</dt>
              <dd>{fullDate(row.min_confirm_deadline)}<span>{relative(row.min_confirm_deadline)}</span></dd>
            </div>
          </dl>

          <div className="table-wrap" style={{ marginTop: 14 }}>
            <table className="data-table" style={{ minWidth: 560 }}>
              <thead>
                <tr>
                  <th>Siswa</th>
                  <th>Status</th>
                  <th className="num">Dibayar</th>
                  <th className="num">Poin</th>
                  <th />
                </tr>
              </thead>
              <tbody>
                {seats === undefined ? (
                  <tr>
                    <td colSpan={5}>
                      <div className="empty-state">
                        <strong>Memuat kursi…</strong>
                      </div>
                    </td>
                  </tr>
                ) : seats.length === 0 ? (
                  <tr>
                    <td colSpan={5}>
                      <div className="empty-state">
                        <strong>Belum ada kursi diambil</strong>
                        <span>Kursi tampil setelah siswa membayar.</span>
                      </div>
                    </td>
                  </tr>
                ) : (
                  seats.map((seat) => {
                    const seatMeta = SEAT_META[seat.status] ?? { label: seat.status, tone: 'neutral' }
                    return (
                      <tr key={seat.id}>
                        <td>{seat.students?.full_name ?? '—'}</td>
                        <td><span className={`badge ${seatMeta.tone}`}>{seatMeta.label}</span></td>
                        <td className="num">{rupiah(seat.price_paid)}</td>
                        <td className="num">{seat.refund_amount ? rupiah(seat.refund_amount) : '—'}</td>
                        <td>
                          <div className="row-actions">
                            {seat.status === 'refund_pending' || seat.status === 'active' ? (
                              <button className="btn btn-secondary btn-sm" onClick={() => onCancelToCredit(seat)}>
                                Batalkan → poin
                              </button>
                            ) : null}
                          </div>
                        </td>
                      </tr>
                    )
                  })
                )}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  )
}
