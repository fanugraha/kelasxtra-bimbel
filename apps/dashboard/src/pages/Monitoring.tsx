import { useEffect, useState } from 'react'
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

export function Monitoring() {
  const now = new Date()
  const [from, setFrom] = useState(iso(new Date(now.getFullYear(), now.getMonth(), 1)))
  const [to, setTo] = useState(iso(now))
  const [metrics, setMetrics] = useState<Metrics | null>(null)
  const [bookings, setBookings] = useState<BookingRow[]>([])
  const [loading, setLoading] = useState(true)
  const [notice, setNotice] = useState<string | null>(null)

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

  return (
    <section>
      <h1>Monitoring</h1>
      <p className="muted">
        Ringkasan operasional, performa tutor, progres siswa, dan koreksi absensi.
        Semua koreksi masuk audit log.
      </p>

      <div className="tutor-form">
        <label>
          Dari
          <input type="date" value={from} onChange={(e) => setFrom(e.target.value)} />
        </label>
        <label>
          Sampai
          <input type="date" value={to} onChange={(e) => setTo(e.target.value)} />
        </label>
        <button onClick={load} disabled={loading}>
          {loading ? 'Memuat…' : 'Terapkan'}
        </button>
      </div>

      {notice && <pre className="notice-line">{notice}</pre>}

      {metrics && (
        <>
          <div className="cards">
            <div className="card">
              <h3>Sesi</h3>
              <p className="muted">
                {metrics.bookings.total} total · {metrics.bookings.completed} selesai ·{' '}
                {metrics.bookings.no_show} no-show · {metrics.bookings.cancelled} batal
              </p>
              <span className="badge">{metrics.bookings.today} hari ini</span>
            </div>
            <div className="card">
              <h3>Operasional</h3>
              <p className="muted">
                {metrics.ops.in_progress} berlangsung · {metrics.ops.pending_bookings}{' '}
                menunggu bayar · {metrics.ops.groups_open} kelas grup dibuka
              </p>
              <span className="badge">{metrics.ops.complaints_open} komplain terbuka</span>
            </div>
            <div className="card">
              <h3>Pengguna</h3>
              <p className="muted">
                {metrics.users.students} siswa · {metrics.users.tutors_active} tutor aktif
              </p>
              <span className="badge">
                {metrics.users.subscriptions_active} langganan aktif
              </span>
            </div>
            <div className="card">
              <h3>Honor</h3>
              <p className="muted">Belum dibayar {rupiah(metrics.revenue.tutor_unpaid)}</p>
              <span className="badge">Sudah {rupiah(metrics.revenue.tutor_paid)}</span>
            </div>
          </div>

          <h2>Performa Tutor</h2>
          <table className="table">
            <thead>
              <tr>
                <th>Tutor</th>
                <th>Rating</th>
                <th>Selesai</th>
                <th>Batal</th>
                <th>No-show</th>
                <th>Honor tertahan/belum bayar</th>
              </tr>
            </thead>
            <tbody>
              {metrics.tutors.map((t) => (
                <tr key={t.id}>
                  <td>{t.full_name}</td>
                  <td>{Number(t.rating_avg).toFixed(2)}</td>
                  <td>{t.completed}</td>
                  <td>{t.cancelled}</td>
                  <td>{t.no_show}</td>
                  <td>{rupiah(t.unpaid)}</td>
                </tr>
              ))}
            </tbody>
          </table>

          <h2>Progres Siswa</h2>
          <table className="table">
            <thead>
              <tr>
                <th>Siswa</th>
                <th>Jenjang</th>
                <th>Sesi selesai</th>
                <th>Latihan bank soal</th>
              </tr>
            </thead>
            <tbody>
              {metrics.students.map((s) => (
                <tr key={s.id}>
                  <td>{s.full_name}</td>
                  <td>{s.jenjang}</td>
                  <td>{s.sessions}</td>
                  <td>{s.attempts}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </>
      )}

      <h2>Koreksi Absensi (10 sesi terbaru)</h2>
      <table className="table">
        <thead>
          <tr>
            <th>Jadwal</th>
            <th>Siswa</th>
            <th>Tutor</th>
            <th>Status</th>
            <th>Aksi</th>
          </tr>
        </thead>
        <tbody>
          {bookings.map((b) => (
            <tr key={b.id}>
              <td className="muted">{new Date(b.scheduled_at).toLocaleString('id-ID')}</td>
              <td>{b.studentName ?? '—'}</td>
              <td>{b.tutorName ?? '—'}</td>
              <td>{b.status}</td>
              <td className="actions">
                <button onClick={() => correct(b)}>Koreksi</button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </section>
  )
}
