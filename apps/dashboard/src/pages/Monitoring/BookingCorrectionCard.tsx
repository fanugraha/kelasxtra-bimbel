import { formatDateTime } from '../../lib/format'
import { STATUS_META } from './types'
import type { BookingRow } from './types'

export function BookingCorrectionCard({
  bookings,
  onCorrect,
}: {
  bookings: BookingRow[]
  onCorrect: (booking: BookingRow) => void
}) {
  return (
    <div className="card" id="koreksi-absensi" style={{ marginTop: 14 }}>
      <div className="card-head">
        <div>
          <h2 className="card-title">Koreksi absensi</h2>
          <p className="card-sub">10 sesi terbaru · setiap koreksi masuk audit log</p>
        </div>
      </div>
      <div className="table-wrap">
        <table className="data-table">
          <thead>
            <tr>
              <th>Jadwal</th>
              <th>Siswa</th>
              <th>Tutor</th>
              <th>Status</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {bookings.map((b) => {
              const meta = STATUS_META[b.status] ?? { label: b.status, tone: 'neutral' }
              return (
                <tr key={b.id}>
                  <td className="num">
                    {formatDateTime(b.scheduled_at)}
                  </td>
                  <td>{b.studentName ?? '—'}</td>
                  <td>{b.tutorName ?? '—'}</td>
                  <td>
                    <span className={`badge ${meta.tone}`}>{meta.label}</span>
                  </td>
                  <td>
                    <div className="row-actions">
                      <button className="btn btn-secondary btn-sm" onClick={() => onCorrect(b)}>
                        Koreksi
                      </button>
                    </div>
                  </td>
                </tr>
              )
            })}
            {bookings.length === 0 && (
              <tr>
                <td colSpan={5}>
                  <div className="empty-state">
                    <strong>Belum ada sesi</strong>
                    <span>Sesi terbaru akan tampil di sini.</span>
                  </div>
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  )
}
