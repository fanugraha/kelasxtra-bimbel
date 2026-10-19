import { Fragment } from 'react'
import { MathText } from '../../components/MathText'
import { formatDateTime } from '../../lib/format'
import { STATUS_LABEL, STATUS_TONE } from './types'
import type { Option, QuestionRow, VersionRow } from './types'

export function QuestionTable({
  subjects,
  filterSubject,
  onFilterSubject,
  filterStatus,
  onFilterStatus,
  filtered,
  loading,
  versions,
  openVersions,
  onStartEdit,
  onSetStatus,
  onToggleVersions,
}: {
  subjects: Option[]
  filterSubject: string
  onFilterSubject: (value: string) => void
  filterStatus: string
  onFilterStatus: (value: string) => void
  filtered: QuestionRow[]
  loading: boolean
  versions: Record<string, VersionRow[]>
  openVersions: string | null
  onStartEdit: (row: QuestionRow) => void
  onSetStatus: (row: QuestionRow, status: string) => void
  onToggleVersions: (row: QuestionRow) => void
}) {
  return (
    <div className="card">
      <div className="toolbar">
        <select className="select" value={filterSubject} onChange={(e) => onFilterSubject(e.target.value)} aria-label="Filter mapel">
          <option value="">Semua mapel</option>
          {subjects.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
        </select>
        <select className="select" value={filterStatus} onChange={(e) => onFilterStatus(e.target.value)} aria-label="Filter status">
          <option value="">Semua status</option>
          {Object.entries(STATUS_LABEL).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
        </select>
        <div className="spacer" />
        <span className="badge neutral">{filtered.length} soal</span>
      </div>

      {loading ? (
        <div className="empty-state">
          <strong>Memuat soal…</strong>
        </div>
      ) : filtered.length === 0 ? (
        <div className="empty-state">
          <strong>Belum ada soal</strong>
          <span>Tulis soal pertama lewat tombol di kanan atas.</span>
        </div>
      ) : (
        <div className="table-wrap">
          <table className="data-table">
            <thead>
              <tr>
                <th>Soal</th>
                <th>Mapel · Topik</th>
                <th>Ver</th>
                <th>Status</th>
                <th>Aksi</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((r) => (
                <Fragment key={r.id}>
                  <tr>
                    <td>
                      {r.body ? <MathText text={r.body} /> : <span className="muted">(tanpa isi)</span>}
                      {r.image_url && <div className="muted">🖼 {r.image_url}</div>}
                    </td>
                    <td>
                      {r.subject_name ?? '—'} · {r.topic_name ?? '—'} · {r.jenjang}
                    </td>
                    <td className="num">v{r.current_version}</td>
                    <td>
                      <span className={`badge ${STATUS_TONE[r.status] ?? 'neutral'}`}>
                        {STATUS_LABEL[r.status] ?? r.status}
                      </span>
                    </td>
                    <td>
                      <div className="row-actions">
                        <button className="btn btn-secondary btn-sm" onClick={() => onStartEdit(r)}>Edit</button>
                        {r.status === 'draft' && <button className="btn btn-ghost btn-sm" onClick={() => onSetStatus(r, 'review')}>Ajukan review</button>}
                        {r.status === 'review' && <button className="btn btn-secondary btn-sm" onClick={() => onSetStatus(r, 'published')}>Tayangkan</button>}
                        {r.status === 'published' && <button className="btn btn-ghost btn-sm" onClick={() => onSetStatus(r, 'archived')}>Arsipkan</button>}
                        <button className="btn btn-ghost btn-sm" onClick={() => onToggleVersions(r)}>{openVersions === r.id ? 'Tutup' : 'Riwayat'}</button>
                      </div>
                    </td>
                  </tr>
                  {openVersions === r.id && (
                    <tr key={`${r.id}-v`}>
                      <td colSpan={5}>
                        {(versions[r.id] ?? []).map((v) => (
                          <div key={v.version} className="muted" style={{ padding: '4px 0' }}>
                            <strong>v{v.version}</strong> · {formatDateTime(v.created_at)} — <MathText text={v.body} />
                          </div>
                        ))}
                      </td>
                    </tr>
                  )}
                </Fragment>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}
