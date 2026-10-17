import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { supabase } from '../lib/supabase'

interface Metrics {
  bookings: { today: number }
  revenue: { gross: number }
  ops: { complaints_open: number; in_progress: number; pending_bookings: number }
}

interface PaymentRow {
  amount: number
  status: string
  paid_at: string | null
  created_at: string
}

interface BookingRow {
  id: string
  student_id: string
  tutor_id: string
  subject_id: string
  scheduled_at: string
  status: string
  mode: string
  studentName: string
  tutorName: string
  subjectName: string
}

const rupiah = (n: number) => 'Rp' + n.toLocaleString('id-ID')
const compact = (n: number) =>
  n >= 1_000_000 ? `Rp${(n / 1_000_000).toLocaleString('id-ID', { maximumFractionDigits: 2 })} jt` : rupiah(n)
const dateKey = (value: string | Date) =>
  new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Jakarta',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(typeof value === 'string' ? new Date(value) : value)

const STATUS_LABEL: Record<string, { label: string; tone: string }> = {
  pending_payment: { label: 'Menunggu bayar', tone: 'warn' },
  confirmed: { label: 'Terkonfirmasi', tone: 'ok' },
  in_progress: { label: 'Berlangsung', tone: 'warn' },
  completed: { label: 'Selesai', tone: 'ok' },
  cancelled: { label: 'Batal', tone: 'warn' },
  expired: { label: 'Kedaluwarsa', tone: 'warn' },
  no_show_tutor: { label: 'Tutor tidak hadir', tone: 'warn' },
  no_show_student: { label: 'Siswa tidak hadir', tone: 'warn' },
  disputed: { label: 'Komplain', tone: 'warn' },
  refunded: { label: 'Dikembalikan', tone: 'warn' },
  rescheduled: { label: 'Dijadwalkan ulang', tone: 'warn' },
}

function greeting() {
  const hour = Number(
    new Intl.DateTimeFormat('en-GB', { hour: '2-digit', hour12: false, timeZone: 'Asia/Jakarta' }).format(new Date()),
  )
  if (hour < 11) return 'Selamat pagi.'
  if (hour < 15) return 'Selamat siang.'
  if (hour < 19) return 'Selamat sore.'
  return 'Selamat malam.'
}

export function Overview() {
  const navigate = useNavigate()
  const [metrics, setMetrics] = useState<Metrics | null>(null)
  const [payments, setPayments] = useState<PaymentRow[]>([])
  const [bookings, setBookings] = useState<BookingRow[]>([])
  const [payrollPending, setPayrollPending] = useState(0)
  const [invites, setInvites] = useState(0)
  const [loading, setLoading] = useState(true)
  const [notice, setNotice] = useState<string | null>(null)

  useEffect(() => {
    let cancelled = false

    async function load() {
      setLoading(true)
      setNotice(null)

      const now = new Date()
      const today = dateKey(now)
      const from = dateKey(new Date(now.getTime() - 6 * 86_400_000))
      const start = new Date(`${today}T00:00:00+07:00`)
      const end = new Date(start.getTime() + 86_400_000)

      const [metricRes, paymentRes, bookingRes, payrollRes, inviteRes] = await Promise.all([
        supabase.rpc('admin_metrics', { p_from: from, p_to: today }),
        supabase
          .from('payments')
          .select('amount, status, paid_at, created_at')
          .gte('created_at', new Date(start.getTime() - 6 * 86_400_000).toISOString()),
        supabase
          .from('bookings_visible')
          .select('id, student_id, tutor_id, subject_id, scheduled_at, status, mode')
          .gte('scheduled_at', start.toISOString())
          .lt('scheduled_at', end.toISOString())
          .order('scheduled_at'),
        supabase.from('payroll_periods').select('id', { count: 'exact', head: true }).in('status', ['draft', 'approved']),
        supabase.from('tutors').select('id', { count: 'exact', head: true }).eq('status', 'diundang'),
      ])

      if (cancelled) return
      if (metricRes.error) setNotice(`Gagal memuat ringkasan: ${metricRes.error.message}`)
      else setMetrics(metricRes.data as Metrics)

      setPayments((paymentRes.data as PaymentRow[]) ?? [])
      setPayrollPending(payrollRes.count ?? 0)
      setInvites(inviteRes.count ?? 0)

      const rows = (bookingRes.data as Omit<BookingRow, 'studentName' | 'tutorName' | 'subjectName'>[]) ?? []
      const studentIds = [...new Set(rows.map((r) => r.student_id))]
      const tutorIds = [...new Set(rows.map((r) => r.tutor_id))]
      const subjectIds = [...new Set(rows.map((r) => r.subject_id))]
      const [students, tutors, subjects] = await Promise.all([
        supabase.from('students').select('id, full_name').in('id', studentIds),
        supabase.from('tutors').select('id, full_name').in('id', tutorIds),
        supabase.from('subjects').select('id, name').in('id', subjectIds),
      ])
      if (cancelled) return
      const studentNames = Object.fromEntries((students.data ?? []).map((r) => [r.id, r.full_name]))
      const tutorNames = Object.fromEntries((tutors.data ?? []).map((r) => [r.id, r.full_name]))
      const subjectNames = Object.fromEntries((subjects.data ?? []).map((r) => [r.id, r.name]))
      setBookings(
        rows.map((r) => ({
          ...r,
          studentName: studentNames[r.student_id] ?? '—',
          tutorName: tutorNames[r.tutor_id] ?? '—',
          subjectName: subjectNames[r.subject_id] ?? '—',
        })),
      )
      setLoading(false)
    }

    load()
    return () => {
      cancelled = true
    }
  }, [])

  const days = Array.from({ length: 7 }, (_, index) => {
    const date = new Date(Date.now() - (6 - index) * 86_400_000)
    const key = dateKey(date)
    const total = payments
      .filter(
        (p) =>
          ['settlement', 'capture'].includes(p.status) &&
          dateKey(p.paid_at ?? p.created_at) === key,
      )
      .reduce((sum, p) => sum + Number(p.amount), 0)
    return {
      key,
      total,
      label: new Intl.DateTimeFormat('id-ID', { weekday: 'short', timeZone: 'Asia/Jakarta' }).format(date),
      today: key === dateKey(new Date()),
    }
  })
  const maxDay = Math.max(1, ...days.map((d) => d.total))
  const revenue7 = days.reduce((sum, d) => sum + d.total, 0)
  const sessionsToday = metrics?.bookings.today ?? 0
  const inProgress = bookings.filter((b) => b.status === 'in_progress').length
  const offline = bookings.filter((b) => b.mode === 'offline').length
  const online = bookings.filter((b) => b.mode === 'online').length
  const attention = (metrics?.ops.complaints_open ?? 0) + payrollPending
  const tasks = [
    payrollPending > 0 && {
      title: `Setujui ${payrollPending} rekap gaji`,
      note: 'Rekap menunggu persetujuan',
      action: 'Buka rekap',
      to: '/payroll',
    },
    (metrics?.ops.complaints_open ?? 0) > 0 && {
      title: `Putuskan ${metrics?.ops.complaints_open} komplain`,
      note: 'Komplain terbuka',
      action: 'Lihat',
      to: '/disputes',
    },
    invites > 0 && {
      title: `Kirim ulang ${invites} undangan tutor`,
      note: 'Tutor belum mengaktifkan akun',
      action: 'Buka',
      to: '/tutors',
    },
  ].filter(Boolean) as { title: string; note: string; action: string; to: string }[]

  const today = new Intl.DateTimeFormat('id-ID', {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
    year: 'numeric',
    timeZone: 'Asia/Jakarta',
  }).format(new Date())

  if (loading) {
    return (
      <section>
        <div className="view-loading-card">
          <div className="view-loading-status">
            <span className="view-loading-spinner" /> Memuat ringkasan…
          </div>
          <div className="sk-cards">
            {[0, 1, 2].map((i) => (
              <div className="sk-mini" key={i}>
                <span className="sk sk-bar sm" style={{ width: '42%' }} />
                <span className="sk sk-bar lg" style={{ width: '66%' }} />
              </div>
            ))}
          </div>
          <span className="sk sk-bar" style={{ width: '100%' }} />
          <span className="sk sk-bar" style={{ width: '86%' }} />
        </div>
      </section>
    )
  }

  return (
    <section>
      <div className="page-head">
        <div>
          <p className="eyebrow">Ringkasan · {today}</p>
          <h1 className="page-title">{greeting()}</h1>
          <p className="page-sub">
            {tasks.length} tugas menunggu keputusanmu · {sessionsToday} sesi hari ini.
          </p>
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

      <div className="ov-summary">
        <article className="ov-summary-card ov-summary-revenue">
          <div className="ov-revenue-head">
            <div>
              <p className="ov-label">Pendapatan 7 hari</p>
              <p className="ov-value">{compact(revenue7)}</p>
              <p className="ov-note">Pembayaran berhasil · WIB</p>
            </div>
            <span className="ov-range">7 hari terakhir</span>
          </div>
          <div className="ov-chart-body">
            <div className="ov-bars">
              {days.map((day) => (
                <div className="ov-bar-col" key={day.key} title={`${day.label} · ${rupiah(day.total)}`}>
                  <div
                    className={`ov-bar${day.today ? ' today' : ''}`}
                    style={{ height: `${Math.max(day.total > 0 ? 6 : 2, Math.round((day.total / maxDay) * 100))}%` }}
                  />
                </div>
              ))}
            </div>
            <div className="ov-days" aria-hidden="true">
              {days.map((day) => (
                <span className={day.today ? 'today' : ''} key={day.key}>
                  {day.label}
                </span>
              ))}
            </div>
          </div>
        </article>
        <div className="ov-summary-side">
          <article className="ov-summary-card">
            <p className="ov-label">Sesi hari ini</p>
            <p className="ov-value">{sessionsToday}</p>
            <p className="ov-note">
              {inProgress} berlangsung · {offline} offline · {online} online
            </p>
          </article>
          <article className="ov-summary-card">
            <p className="ov-label">Perlu perhatian</p>
            <p className={`ov-value${attention > 0 ? ' is-alert' : ''}`}>{attention}</p>
            <p className="ov-note">
              {metrics?.ops.complaints_open ?? 0} komplain · {payrollPending} rekap gaji
            </p>
          </article>
        </div>
      </div>

      <div className="ov-grid">
        <article className="card">
          <div className="card-head">
            <div>
              <h2 className="card-title">Perlu dikerjakan</h2>
              <p className="card-sub">Urut dari yang paling mendesak</p>
            </div>
            <p className="ov-task-count">{tasks.length} tugas</p>
          </div>
          <div className="card-body ov-work-body">
            {tasks.length === 0 ? (
              <div className="empty-state">
                <strong>Tidak ada tugas</strong>
                <span>Semua keputusan sudah ditangani.</span>
              </div>
            ) : (
              tasks.map((task, index) =>
                index === 0 ? (
                  <div className="ov-priority" key={task.title}>
                    <div className="ov-priority-main">
                      <p className="ov-kicker">
                        <span className="ov-kicker-dot" aria-hidden="true" />
                        Paling mendesak
                      </p>
                      <h3>{task.title}</h3>
                      <p className="ov-priority-meta">{task.note}</p>
                    </div>
                    <button className="btn btn-primary" onClick={() => navigate(task.to)}>
                      {task.action}
                    </button>
                  </div>
                ) : (
                  <div className="ov-task" key={task.title}>
                    <div className="ov-task-main">
                      <h3>{task.title}</h3>
                      <p>{task.note}</p>
                    </div>
                    <button className="btn btn-secondary btn-sm" onClick={() => navigate(task.to)}>
                      {task.action}
                    </button>
                  </div>
                ),
              )
            )}
          </div>
        </article>

        <article className="card">
          <div className="card-head">
            <div>
              <h2 className="card-title">Jadwal hari ini</h2>
              <p className="card-sub">
                {sessionsToday} sesi · {inProgress} berlangsung · {offline} offline
              </p>
            </div>
            <button className="card-link" onClick={() => navigate('/monitoring')}>
              Semua sesi →
            </button>
          </div>
          <div className="card-body ov-schedule-body">
            {bookings.length === 0 ? (
              <div className="empty-state">
                <strong>Belum ada sesi hari ini</strong>
                <span>Jadwal yang masuk akan tampil di sini.</span>
              </div>
            ) : (
              <div className="ov-timeline">
                {bookings.slice(0, 6).map((b) => {
                  const status = STATUS_LABEL[b.status] ?? { label: b.status, tone: 'ok' }
                  return (
                    <div className={`ov-slot${b.status === 'in_progress' ? ' is-live' : ''}`} key={b.id}>
                      <span className="ov-time">
                        {new Intl.DateTimeFormat('id-ID', {
                          hour: '2-digit',
                          minute: '2-digit',
                          hour12: false,
                          timeZone: 'Asia/Jakarta',
                        }).format(new Date(b.scheduled_at))}
                      </span>
                      <span className={`ov-dot ${status.tone}`} aria-hidden="true" />
                      <div>
                        <div className="ov-slot-name">
                          {b.studentName}
                          <span className={`ov-slot-status ${status.tone}`}>{status.label}</span>
                        </div>
                        <p className="ov-slot-meta">
                          {b.tutorName} · {b.subjectName} · {b.mode === 'online' ? 'Online' : 'Offline'}
                        </p>
                      </div>
                    </div>
                  )
                })}
              </div>
            )}
          </div>
        </article>
      </div>
    </section>
  )
}
