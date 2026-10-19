import { rupiah } from '../../lib/format'
import { initials } from '../../lib/text'
import type { TutorStat } from './types'

export function TutorListItem({
  t,
  open,
  onToggle,
}: {
  t: TutorStat
  open: boolean
  onToggle: () => void
}) {
  const total = t.completed + t.cancelled + t.no_show
  const rate = total ? Math.round((t.completed / total) * 100) : 0
  const isAttention = t.no_show > 0 || t.cancelled > 0 || t.unpaid > 0
  const tone = t.no_show > 0 ? 'is-danger' : t.cancelled > 0 ? 'is-warning' : 'is-muted'

  return (
    <div>
      <article className="mtr-item">
        <div className="mtr-person">
          <span className="avatar" aria-hidden="true">{initials(t.full_name)}</span>
          <div>
            <h3>{t.full_name}</h3>
            <p>Rating {Number(t.rating_avg).toFixed(1)}</p>
          </div>
        </div>
        <div className="mtr-sessions">
          <span className="mtr-label">Sesi selesai</span>
          <div className="progress-row">
            <span className={`progress${rate >= 100 ? ' done' : rate < 90 ? ' warn' : ''}`}>
              <span style={{ width: `${rate}%` }} />
            </span>
            <span className="num">
              {t.completed}/{total}
            </span>
          </div>
        </div>
        <div className="mtr-issue">
          <span className="mtr-label">Kendala</span>
          <span className={`mtr-issue-text ${tone}`}>
            <i aria-hidden="true" />
            {t.no_show > 0
              ? `${t.no_show} tidak hadir · ${t.cancelled} batal`
              : t.cancelled > 0
                ? `${t.cancelled} sesi batal`
                : 'Tidak ada kendala'}
          </span>
        </div>
        <div className="mtr-pay">
          <span className="mtr-label">Gaji tertahan</span>
          <span className={`mtr-amount${Number(t.unpaid) > 0 ? '' : ' is-zero'}`}>
            {Number(t.unpaid) > 0 ? rupiah(Number(t.unpaid)) : '—'}
          </span>
        </div>
        <div className="mtr-actions">
          {isAttention && (
            <button
              className="btn btn-secondary btn-sm"
              onClick={() =>
                document
                  .getElementById('koreksi-absensi')
                  ?.scrollIntoView({ behavior: 'smooth' })
              }
            >
              Perbaiki
            </button>
          )}
          <button
            className="mtr-toggle"
            type="button"
            aria-expanded={open}
            aria-controls={`mon-detail-${t.id}`}
            onClick={onToggle}
          >
            Rincian
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.9" aria-hidden="true">
              <path d="m6 9 6 6 6-6" />
            </svg>
          </button>
        </div>
      </article>
      <div className="mtr-detail" id={`mon-detail-${t.id}`} hidden={!open}>
        <div className="mtr-detail-panel">
          <dl className="mtr-detail-grid">
            <div>
              <dt>Rating</dt>
              <dd>{Number(t.rating_avg).toFixed(1)}<span>rata-rata</span></dd>
            </div>
            <div>
              <dt>Sesi</dt>
              <dd>{t.completed} selesai<span>dari {total} sesi</span></dd>
            </div>
            <div>
              <dt>Gaji tertahan</dt>
              <dd>{Number(t.unpaid) > 0 ? rupiah(Number(t.unpaid)) : 'Tidak ada'}<span>masuk rekap berikutnya</span></dd>
            </div>
            <div>
              <dt>Kendala</dt>
              <dd>{t.no_show + t.cancelled} sesi<span>{t.no_show} tidak hadir</span></dd>
            </div>
          </dl>
          <p className="mtr-note">
            <span>Catatan</span>
            Gaji tertahan selama kendala sesi belum ditutup. Setelah absensi diperbaiki atau komplain diputuskan, nominal masuk rekap periode berikutnya.
          </p>
        </div>
      </div>
    </div>
  )
}
