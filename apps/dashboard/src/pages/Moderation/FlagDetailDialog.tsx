import type { RefObject } from 'react'
import { formatDateTime, formatTime } from '../../lib/format'
import { CONTEXT_LABEL } from './types'
import type { FlagRow, TranscriptMessage } from './types'

export function FlagDetailDialog({
  dialogRef,
  detail,
  messages,
  names,
  loadingDetail,
  onClose,
  onWarn,
  onSuspend,
  onReview,
}: {
  dialogRef: RefObject<HTMLDialogElement | null>
  detail: FlagRow | null
  messages: TranscriptMessage[]
  names: Record<string, string>
  loadingDetail: boolean
  onClose: () => void
  onWarn: (row: FlagRow) => void
  onSuspend: (row: FlagRow) => void
  onReview: (row: FlagRow) => void
}) {
  return (
    <dialog ref={dialogRef} className="wide" onClose={onClose}>
      <div className="modal-inner">
        <div className="modal-head">
          <div>
            <p className="modal-kicker">Konteks pelanggaran</p>
            <h2 className="modal-title">{detail?.actor?.full_name ?? 'Pengguna'}</h2>
            <p className="modal-sub">
              {detail ? `${CONTEXT_LABEL[detail.context] ?? detail.context} · ${formatDateTime(detail.created_at)}` : ''}
            </p>
          </div>
          <button className="btn btn-ghost btn-sm" onClick={() => dialogRef.current?.close()}>
            Tutup
          </button>
        </div>

        <div className="modal-body">
          <div className="note" style={{ marginBottom: 14 }}>
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
              <circle cx="12" cy="12" r="9" />
              <path d="M12 11v5M12 8h.01" />
            </svg>
            <span>
              Ditolak karena <strong>{detail?.matched ?? 'terdeteksi'}</strong>: “{detail?.excerpt ?? '—'}”
            </span>
          </div>

          {detail?.ref_table === 'conversations' ? (
            loadingDetail ? (
              <div className="empty-state">
                <strong>Memuat percakapan…</strong>
              </div>
            ) : messages.length === 0 ? (
              <div className="empty-state">
                <strong>Percakapan masih kosong</strong>
                <span>Pesan pelanggar tidak disimpan, jadi mungkin belum ada isi percakapan.</span>
              </div>
            ) : (
              <div className="group-list">
                {messages.map((m) => (
                  <div className="group-item" key={m.id}>
                    <div className="group-top">
                      <div>
                        <div className="group-name">{names[m.sender_id] ?? 'Pengguna'}</div>
                        <div className="group-meta">
                          {formatTime(m.created_at)} WIB
                          {m.flagged ? ' · pernah ditandai' : ''}
                        </div>
                      </div>
                    </div>
                    <p style={{ marginTop: 6, fontSize: 12.5 }}>{m.body}</p>
                  </div>
                ))}
              </div>
            )
          ) : (
            <div className="note">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
                <circle cx="12" cy="12" r="9" />
                <path d="M12 11v5M12 8h.01" />
              </svg>
              <span>
                Catatan dari {detail?.context ?? 'teks'} — teks utuh ada di modul terkait
                {detail?.ref_id ? ` (id ${detail.ref_id.slice(0, 8)}…)` : ''}.
              </span>
            </div>
          )}
        </div>

        <div className="modal-foot">
          <span className="modal-note">Peringatan tercatat di riwayat aktivitas admin.</span>
          {detail?.actor_id && detail?.actor?.role !== 'admin' && (
            <button className="btn btn-ghost" onClick={() => detail && onWarn(detail)}>
              Peringatkan
            </button>
          )}
          {detail?.actor_id && detail?.actor?.role === 'tutor' && (
            <button className="btn btn-ghost" onClick={() => detail && onSuspend(detail)}>
              Tangguhkan
            </button>
          )}
          {detail && !detail.reviewed_at && (
            <button className="btn btn-primary" onClick={() => onReview(detail)}>
              Tandai ditinjau
            </button>
          )}
        </div>
      </div>
    </dialog>
  )
}
