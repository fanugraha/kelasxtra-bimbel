import { useEffect, useMemo, useState } from 'react'
import { supabase } from '../lib/supabase'

interface Metrics {
  bookings: {
    total: number
    completed: number
    cancelled: number
    no_show: number
    disputed: number
    today: number
  }
  revenue: {
    gross: number
    gateway_fee: number
    refunds: number
    platform_share: number
    tutor_earnings: number
    tutor_unpaid: number
    tutor_paid: number
  }
  users: { students: number; subscriptions_active: number; tutors_active: number }
  ops: {
    in_progress: number
    complaints_open: number
    pending_bookings: number
    groups_open: number
  }
  tutors: {
    id: string
    full_name: string
    rating_avg: number
    completed: number
    cancelled: number
    no_show: number
    unpaid: number
  }[]
  students: {
    id: string
    full_name: string
    jenjang: string
    sessions: number
    attempts: number
  }[]
}

interface BookingRow {
  id: string
  student_id: string
  tutor_id: string
  scheduled_at: string
  status: string
  studentName?: string
  tutorName?: string
}

const rupiah = (n: number) => 'Rp' + n.toLocaleString('id-ID')
const fmtDate = (value: string) =>
  new Intl.DateTimeFormat('id-ID', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    timeZone: 'Asia/Jakarta',
  }).format(new Date(`${value}T00:00:00+07:00`))
const iso = (d: Date) =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(
    d.getDate(),
  ).padStart(2, '0')}`

const STATUS_OPTIONS = [
  'confirmed',
  'in_progress',
  'completed',
  'no_show_tutor',
  'no_show_student',
  'cancelled',
  'refunded',
]

const STATUS_META: Record<string, { label: string; tone: string }> = {
  pending_payment: { label: 'Menunggu bayar', tone: 'warning' },
  confirmed: { label: 'Terkonfirmasi', tone: 'success' },
  in_progress: { label: 'Berlangsung', tone: 'warning' },
  completed: { label: 'Selesai', tone: 'success' },
  cancelled: { label: 'Batal', tone: 'danger' },
  expired: { label: 'Kedaluwarsa', tone: 'neutral' },
  no_show_tutor: { label: 'Tutor tidak hadir', tone: 'danger' },
  no_show_student: { label: 'Siswa tidak hadir', tone: 'warning' },
  disputed: { label: 'Komplain', tone: 'danger' },
  refunded: { label: 'Dikembalikan', tone: 'neutral' },
  rescheduled: { label: 'Dijadwalkan ulang', tone: 'info' },
}

function initials(name: string) {
  return name
    .split(/\s+/)
    .slice(0, 2)
    .map((part) => part[0] ?? '')
    .join('')
    .toUpperCase()
}

export function Monitoring() {
  const now = new Date()
  const [from, setFrom] = useState(iso(new Date(now.getFullYear(), now.getMonth(), 1)))
  const [to, setTo] = useState(iso(now))
  const [metrics, setMetrics] = useState<Metrics | null>(null)
  const [bookings, setBookings] = useState<BookingRow[]>([])
  const [loading, setLoading] = useState(true)
  const [notice, setNotice] = useState<string | null>(null)
  const [filter, setFilter] = useState<'attention' | 'all'>('attention')
  const [search, setSearch] = useState('')
  const [sort, setSort] = useState<'pay' | 'sessions' | 'name'>('pay')
  const [expanded, setExpanded] = useState<string | null>(null)

  async function load() {
    setLoading(true)
    setNotice(null)
    const { data, error } = await supabase.rpc('admin_metrics', {
      p_from: from,
      p_to: to,
    })
    if (error) {
      setNotice(`Gagal metrik: ${error.message}`)
    } else {
      setMetrics(data as Metrics)
    }

    const { data: rows } = await supabase
      .from('bookings_visible')
      .select('id, student_id, tutor_id, scheduled_at, status')
      .order('scheduled_at', { ascending: false })
      .limit(10)
    const list = ((rows as unknown as BookingRow[]) ?? []).map((b) => ({ ...b }))

    const studentIds = [...new Set(list.map((b) => b.student_id))]
    const tutorIds = [...new Set(list.map((b) => b.tutor_id))]
    const [{ data: studentRows }, { data: tutorRows }] = await Promise.all([
      supabase.from('students').select('id, full_name').in('id', studentIds),
      supabase.from('tutors').select('id, full_name').in('id', tutorIds),
    ])
    const studentNames = Object.fromEntries(
      (studentRows ?? []).map((r) => [r.id, r.full_name]),
    )
    const tutorNames = Object.fromEntries(
      (tutorRows ?? []).map((r) => [r.id, r.full_name]),
    )
    setBookings(
      list.map((b) => ({
        ...b,
        studentName: studentNames[b.student_id] ?? '—',
        tutorName: tutorNames[b.tutor_id] ?? '—',
      })),
    )
    setLoading(false)
  }

  useEffect(() => {
    queueMicrotask(load)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  async function correct(b: BookingRow) {
    const status = prompt(
      `Status baru untuk sesi ${b.studentName ?? '-'} (${STATUS_OPTIONS.join(', ')}):`,
      b.status,
    )
    if (!status || !STATUS_OPTIONS.includes(status)) return
    const reason = prompt('Alasan koreksi (masuk audit log):')
    if (!reason) return
    if (
      !confirm(
        `Koreksi status ${b.status} → ${status}?\n` +
          'Booking yang earning-nya sudah masuk payroll akan ditolak server.',
      )
    )
      return
    const { error } = await supabase.rpc('admin_correct_booking', {
      p_booking: b.id,
      p_status: status,
      p_scheduled_at: null,
      p_reason: reason,
    })
    if (error) {
      setNotice(`Gagal koreksi: ${error.message}`)
      return
    }
    setNotice('Koreksi tersimpan & tercatat di audit log.')
    load()
  }

  const tutors = useMemo(() => {
    if (!metrics) return []
    const term = search.trim().toLowerCase()
    const list = metrics.tutors.filter((t) => {
      const attention = t.no_show > 0 || t.cancelled > 0 || t.unpaid > 0
      if (filter === 'attention' && !attention) return false
      return !term || t.full_name.toLowerCase().includes(term)
    })
    return list.sort((a, b) => {
      if (sort === 'name') return a.full_name.localeCompare(b.full_name)
      if (sort === 'sessions') return a.completed - b.completed
      return b.unpaid - a.unpaid
    })
  }, [metrics, filter, search, sort])

  const attentionTutors = metrics?.tutors.filter(
    (t) => t.no_show > 0 || t.cancelled > 0 || t.unpaid > 0,
  ).length ?? 0
  const held = metrics?.tutors.reduce((sum, t) => sum + Number(t.unpaid), 0) ?? 0
  const completedRate = metrics?.bookings.total
    ? Math.round((metrics.bookings.completed / metrics.bookings.total) * 100)
    : 0

  return (
    <section>
      <div className="page-head">
        <div>
          <p className="eyebrow">Operasional</p>
          <h1 className="page-title">Pantau kelas</h1>
          <p className="page-sub">
            {metrics?.ops.in_progress ?? 0} kelas berjalan sekarang. Absensi dikunci saat rekap gaji periode dibuat.
          </p>
        </div>
        <div className="head-actions">
          <label className="field mtr-period">
            <span className="hint">Dari</span>
            <input className="input" type="date" value={from} onChange={(e) => setFrom(e.target.value)} />
          </label>
          <label className="field mtr-period">
            <span className="hint">Sampai</span>
            <input className="input" type="date" value={to} onChange={(e) => setTo(e.target.value)} />
          </label>
          <button className="btn btn-secondary" onClick={load} disabled={loading}>
            {loading ? 'Memuat…' : 'Terapkan'}
          </button>
        </div>
      </div>

      {notice && (
        <div className="note warn" style={{ marginBottom: 14 }}>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
            <path d="M12 3 2.5 20h19L12 3Z" />
            <path d="M12 9v4.5M12 17h.01" />
          </svg>
          <span>{notice}</span>
        </div>
      )}

      {loading && !metrics ? (
        <div className="view-loading-card">
          <div className="view-loading-status">
            <span className="view-loading-spinner" /> Memuat data kelas…
          </div>
          <div className="sk-cards">
            {[0, 1, 2].map((i) => (
              <div className="sk-mini" key={i}>
                <span className="sk sk-bar sm" style={{ width: '42%' }} />
                <span className="sk sk-bar lg" style={{ width: '58%' }} />
              </div>
            ))}
          </div>
          <span className="sk sk-bar" style={{ width: '100%' }} />
          <span className="sk sk-bar" style={{ width: '84%' }} />
        </div>
      ) : (
        <>
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
              <p className="ov-value">{metrics?.ops.in_progress ?? 0}</p>
              <p className="ov-note">
                {metrics?.ops.pending_bookings ?? 0} menunggu bayar · {metrics?.ops.groups_open ?? 0} kelas grup
              </p>
            </article>
            <article className="mtr-summary-card">
              <p className="ov-label">Sesi selesai</p>
              <p className="ov-value">
                {metrics?.bookings.completed ?? 0}
                <span className="mtr-unit">/{metrics?.bookings.total ?? 0}</span>
              </p>
              <p className="ov-note">{completedRate}% dari seluruh sesi</p>
            </article>
          </div>

          <div className="card">
            <div className="card-head">
              <div>
                <h2 className="card-title">Tutor &amp; kendala kelas</h2>
                <p className="card-sub">
                  {metrics?.users.tutors_active ?? 0} tutor aktif · {fmtDate(from)} sampai {fmtDate(to)}
                </p>
              </div>
              <p className="mtr-count" aria-live="polite">
                {tutors.length} dari {metrics?.tutors.length ?? 0} tutor
              </p>
            </div>

            <div className="toolbar mtr-toolbar">
              <div className="segmented" role="group" aria-label="Saring daftar tutor">
                <button
                  type="button"
                  aria-pressed={filter === 'attention'}
                  onClick={() => setFilter('attention')}
                >
                  Perlu tindakan <span className="mtr-filter-count">{attentionTutors}</span>
                </button>
                <button
                  type="button"
                  aria-pressed={filter === 'all'}
                  onClick={() => setFilter('all')}
                >
                  Semua tutor <span className="mtr-filter-count">{metrics?.tutors.length ?? 0}</span>
                </button>
              </div>
              <div className="spacer" />
              <div className="search mtr-search">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" aria-hidden="true">
                  <circle cx="11" cy="11" r="7" />
                  <path d="m20 20-3.5-3.5" />
                </svg>
                <input
                  className="input"
                  type="search"
                  value={search}
                  onChange={(e) => setSearch(e.target.value)}
                  placeholder="Cari nama tutor"
                  aria-label="Cari tutor"
                />
              </div>
              <select
                className="select mtr-sort"
                value={sort}
                onChange={(e) => setSort(e.target.value as 'pay' | 'sessions' | 'name')}
                aria-label="Urutkan tutor"
              >
                <option value="pay">Gaji tertahan terbesar</option>
                <option value="sessions">Sesi tersedikit</option>
                <option value="name">Nama tutor A–Z</option>
              </select>
            </div>

            <div className="mtr-list">
              {tutors.length === 0 ? (
                <div className="empty-state">
                  <strong>Tidak ada tutor yang cocok</strong>
                  <span>Ubah filter atau kata kunci pencarian.</span>
                </div>
              ) : (
                tutors.map((t) => {
                  const total = t.completed + t.cancelled + t.no_show
                  const rate = total ? Math.round((t.completed / total) * 100) : 0
                  const isAttention = t.no_show > 0 || t.cancelled > 0 || t.unpaid > 0
                  const tone = t.no_show > 0 ? 'is-danger' : t.cancelled > 0 ? 'is-warning' : 'is-muted'
                  const open = expanded === t.id
                  return (
                    <div key={t.id}>
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
                            onClick={() => setExpanded(open ? null : t.id)}
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
                })
              )}
            </div>

            <div className="card-foot mtr-foot">
              <div className="note warn">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
                  <path d="M12 3 2.5 20h19L12 3Z" />
                  <path d="M12 9v4.5M12 17h.01" />
                </svg>
                <span>Absensi terkunci saat rekap gaji periode ini dibuat. Setelah itu, perbaikan hanya lewat Gaji Tutor.</span>
              </div>
            </div>
          </div>

          <div className="card" style={{ marginTop: 14 }}>
            <div className="card-head">
              <div>
                <h2 className="card-title">Progres siswa</h2>
                <p className="card-sub">{metrics?.students.length ?? 0} siswa pada periode ini</p>
              </div>
            </div>
            <div className="table-wrap">
              <table className="data-table">
                <thead>
                  <tr>
                    <th>Siswa</th>
                    <th>Jenjang</th>
                    <th className="num">Sesi selesai</th>
                    <th className="num">Latihan bank soal</th>
                  </tr>
                </thead>
                <tbody>
                  {(metrics?.students ?? []).slice(0, 12).map((s) => (
                    <tr key={s.id}>
                      <td className="strong">{s.full_name}</td>
                      <td>{s.jenjang}</td>
                      <td className="num">{s.sessions}</td>
                      <td className="num">{s.attempts}</td>
                    </tr>
                  ))}
                  {(metrics?.students ?? []).length === 0 && (
                    <tr>
                      <td colSpan={4}>
                        <div className="empty-state">
                          <strong>Belum ada data siswa</strong>
                          <span>Data muncul setelah ada sesi atau latihan pada periode ini.</span>
                        </div>
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>

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
                          {new Intl.DateTimeFormat('id-ID', {
                            day: '2-digit',
                            month: 'short',
                            hour: '2-digit',
                            minute: '2-digit',
                            timeZone: 'Asia/Jakarta',
                          }).format(new Date(b.scheduled_at))}
                        </td>
                        <td>{b.studentName ?? '—'}</td>
                        <td>{b.tutorName ?? '—'}</td>
                        <td>
                          <span className={`badge ${meta.tone}`}>{meta.label}</span>
                        </td>
                        <td>
                          <div className="row-actions">
                            <button className="btn btn-secondary btn-sm" onClick={() => correct(b)}>
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
        </>
      )}
    </section>
  )
}
