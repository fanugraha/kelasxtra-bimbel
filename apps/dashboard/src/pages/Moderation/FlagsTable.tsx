import { formatDateTime } from '../../lib/format'
import { CONTEXT_LABEL, FILTERS, ROLE_LABEL } from './types'
import type { FlagRow } from './types'

export function FlagsTable({
  shown,
  loading,
  filter,
  onFilter,
  busy,
  onOpenDetail,
  onReview,
  onWarn,
  onSuspend,
}: {
  shown: FlagRow[]
  loading: boolean
  filter: string
  onFilter: (value: string) => void
  busy: string | null
  onOpenDetail: (row: FlagRow) => void
  onReview: (row: FlagRow) => void
  onWarn: (row: FlagRow) => void
  onSuspend: (row: FlagRow) => void
}) {
  return (
    <div className="card">
      <div className="toolbar">
        <div className="segmented" role="group" aria-label="Filter catatan moderasi">
          {FILTERS.map((item) => (
            <button key={item.value} aria-pressed={filter === item.value} onClick={() => onFilter(item.value)}>
              {item.label}
            </button>
          ))}
        </div>
        <div className="spacer" />
        <span className="badge neutral">{shown.length} catatan</span>
      </div>

      <div className="table-wrap">
        <table className="data-table" style={{ minWidth: 1000 }}>
          <thead>
            <tr>
              <th>Waktu</th>
              <th>Pengguna</th>
              <th>Di mana</th>
              <th>Alasan</th>
              <th>Cuplikan pesan</th>
              <th>Status</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan={7}>
                  <div className="empty-state">
                    <strong>Memuat catatan…</strong>
                  </div>
                </td>
              </tr>
            ) : shown.length === 0 ? (
              <tr>
                <td colSpan={7}>
                  <div className="empty-state">
                    <strong>Tidak ada catatan</strong>
                    <span>Pelanggaran aturan komunikasi akan tampil di sini.</span>
                  </div>
                </td>
              </tr>
            ) : (
              shown.map((r) => (
                <tr key={r.id}>
                  <td className="num">{formatDateTime(r.created_at)}</td>
                  <td>
                    {r.actor?.full_name ?? '—'}
                    {r.actor?.role && (
                      <span className="sub">{ROLE_LABEL[r.actor.role] ?? r.actor.role}</span>
                    )}
                  </td>
                  <td>{CONTEXT_LABEL[r.context] ?? r.context}</td>
                  <td>
                    <span className="badge warning">{r.matched ?? 'terdeteksi'}</span>
                  </td>
                  <td>
                    {r.excerpt ?? '—'}
                    {r.note && <span className="sub">Catatan: {r.note}</span>}
                  </td>
                  <td>
                    {r.reviewed_at ? (
                      <>
                        <span className="badge success">Sudah ditinjau</span>
                        {r.reviewer?.full_name && <span className="sub">{r.reviewer.full_name}</span>}
                      </>
                    ) : (
                      <span className="badge danger">Baru</span>
                    )}
                  </td>
                  <td>
                    <div className="row-actions">
                      <button className="btn btn-secondary btn-sm" onClick={() => onOpenDetail(r)}>
                        Konteks
                      </button>
                      {!r.reviewed_at && (
                        <button className="btn btn-primary btn-sm" disabled={busy === r.id} onClick={() => onReview(r)}>
                          Tinjau
                        </button>
                      )}
                      {r.actor_id && r.actor?.role !== 'admin' && (
                        <button className="btn btn-ghost btn-sm" disabled={busy === r.id} onClick={() => onWarn(r)}>
                          Peringatkan
                        </button>
                      )}
                      {r.actor_id && r.actor?.role === 'tutor' && (
                        <button className="btn btn-ghost btn-sm" disabled={busy === r.id} onClick={() => onSuspend(r)}>
                          Tangguhkan
                        </button>
                      )}
                    </div>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
      <div className="card-foot">
        <div className="note">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
            <circle cx="12" cy="12" r="9" />
            <path d="M12 11v5M12 8h.01" />
          </svg>
          <span>
            Pesan pelanggar tidak disimpan (hanya cuplikannya). Peringatan muncul di menu Notifikasi aplikasi
            pengguna; penangguhan hanya berlaku untuk akun tutor.
          </span>
        </div>
      </div>
    </div>
  )
}
