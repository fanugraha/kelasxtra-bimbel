import { useEffect, useMemo, useState } from 'react'
import { formatDateOnly, isoDate } from '../../lib/format'
import { supabase } from '../../lib/supabase'
import { BookingCorrectionCard } from './BookingCorrectionCard'
import { MonitoringSummary } from './MonitoringSummary'
import { MonitoringToolbar } from './MonitoringToolbar'
import { StudentProgressCard } from './StudentProgressCard'
import { TutorListItem } from './TutorListItem'
import { STATUS_OPTIONS } from './types'
import type { BookingRow, Metrics, MonitoringFilter, TutorSort } from './types'

export function Monitoring() {
  const now = new Date()
  const [from, setFrom] = useState(isoDate(new Date(now.getFullYear(), now.getMonth(), 1)))
  const [to, setTo] = useState(isoDate(now))
  const [metrics, setMetrics] = useState<Metrics | null>(null)
  const [bookings, setBookings] = useState<BookingRow[]>([])
  const [loading, setLoading] = useState(true)
  const [notice, setNotice] = useState<string | null>(null)
  const [filter, setFilter] = useState<MonitoringFilter>('attention')
  const [search, setSearch] = useState('')
  const [sort, setSort] = useState<TutorSort>('pay')
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
          <MonitoringSummary
            attentionTutors={attentionTutors}
            held={held}
            inProgress={metrics?.ops.in_progress ?? 0}
            pendingBookings={metrics?.ops.pending_bookings ?? 0}
            groupsOpen={metrics?.ops.groups_open ?? 0}
            completed={metrics?.bookings.completed ?? 0}
            total={metrics?.bookings.total ?? 0}
            completedRate={completedRate}
          />

          <div className="card">
            <div className="card-head">
              <div>
                <h2 className="card-title">Tutor &amp; kendala kelas</h2>
                <p className="card-sub">
                  {metrics?.users.tutors_active ?? 0} tutor aktif · {formatDateOnly(from)} sampai {formatDateOnly(to)}
                </p>
              </div>
              <p className="mtr-count" aria-live="polite">
                {tutors.length} dari {metrics?.tutors.length ?? 0} tutor
              </p>
            </div>

            <MonitoringToolbar
              filter={filter}
              onFilter={setFilter}
              search={search}
              onSearch={setSearch}
              sort={sort}
              onSort={setSort}
              attentionCount={attentionTutors}
              totalCount={metrics?.tutors.length ?? 0}
            />

            <div className="mtr-list">
              {tutors.length === 0 ? (
                <div className="empty-state">
                  <strong>Tidak ada tutor yang cocok</strong>
                  <span>Ubah filter atau kata kunci pencarian.</span>
                </div>
              ) : (
                tutors.map((t) => (
                  <TutorListItem
                    key={t.id}
                    t={t}
                    open={expanded === t.id}
                    onToggle={() => setExpanded(expanded === t.id ? null : t.id)}
                  />
                ))
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

          <StudentProgressCard students={metrics?.students ?? []} />

          <BookingCorrectionCard bookings={bookings} onCorrect={correct} />
        </>
      )}
    </section>
  )
}
