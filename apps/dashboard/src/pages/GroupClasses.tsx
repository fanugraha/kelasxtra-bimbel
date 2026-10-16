import { Fragment, useEffect, useMemo, useState } from 'react'
import type { FormEvent } from 'react'
import { supabase } from '../lib/supabase'

interface Option {
  id: string
  name: string
}

interface Session {
  seq: number
  scheduled_at: string
}

interface GroupClass {
  id: string
  jenjang: string
  mode: string
  duration_minutes: number
  total_sesi: number
  discount_percent: number
  price_per_session: number
  price_total: number
  min_seats: number
  max_seats: number
  seats_taken: number
  status: string
  min_confirm_deadline: string
  tutors: { full_name: string } | null
  subjects: { name: string } | null
  rooms: { name: string } | null
  group_sessions: Session[]
}

interface Seat {
  id: string
  status: string
  price_paid: number
  refund_amount: number | null
  students: { full_name: string } | null
}

const DAYS: { iso: number; label: string }[] = [
  { iso: 1, label: 'Sen' },
  { iso: 2, label: 'Sel' },
  { iso: 3, label: 'Rab' },
  { iso: 4, label: 'Kam' },
  { iso: 5, label: 'Jum' },
  { iso: 6, label: 'Sab' },
  { iso: 7, label: 'Min' },
]

const STATUS_CLASS: Record<string, string> = {
  open: 'status-diundang',
  confirmed: 'status-aktif',
  cancelled: 'status-suspend',
  completed: 'status-aktif',
}

const STATUS_LABEL: Record<string, string> = {
  open: 'Dibuka',
  confirmed: 'Jalan',
  cancelled: 'Batal',
  completed: 'Selesai',
}

const SEAT_LABEL: Record<string, string> = {
  pending_payment: 'Menunggu bayar',
  active: 'Aktif',
  refund_pending: 'Perlu refund',
  refunded: 'Sudah refund',
  cancelled: 'Batal',
}

const rupiah = (n: number) => 'Rp' + n.toLocaleString('id-ID')

const emptyForm = {
  tutor: '',
  subject: '',
  jenjang: 'SMA',
  mode: 'offline',
  room: '',
  duration: 90,
  totalSesi: 8,
  days: [2, 4] as number[],
  startDate: '',
  time: '16:00',
}

export function GroupClasses() {
  const [tutors, setTutors] = useState<{ id: string; full_name: string }[]>([])
  const [subjects, setSubjects] = useState<Option[]>([])
  const [rooms, setRooms] = useState<Option[]>([])
  const [rows, setRows] = useState<GroupClass[]>([])
  const [seats, setSeats] = useState<Record<string, Seat[]>>({})
  const [openId, setOpenId] = useState<string | null>(null)
  const [form, setForm] = useState(emptyForm)
  const [busy, setBusy] = useState(false)
  const [notice, setNotice] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)

  async function load() {
    setLoading(true)
    const [t, s, r, g] = await Promise.all([
      supabase.from('tutors').select('id, full_name').eq('status', 'aktif').order('full_name'),
      supabase.from('subjects').select('id, name').eq('active', true).order('name'),
      supabase.from('rooms').select('id, name').eq('active', true).order('name'),
      supabase
        .from('group_classes')
        .select(
          'id, jenjang, mode, duration_minutes, total_sesi, discount_percent, price_per_session, '+ 
            'price_total, min_seats, max_seats, seats_taken, status, min_confirm_deadline, '+ 
            'tutors(full_name), subjects(name), rooms(name), group_sessions(seq, scheduled_at)',
        )
        .order('created_at', { ascending: false }),
    ])
    setTutors((t.data as unknown as { id: string; full_name: string }[]) ?? [])
    setSubjects((s.data as unknown as Option[]) ?? [])
    setRooms((r.data as unknown as Option[]) ?? [])
    setRows((g.data as unknown as GroupClass[]) ?? [])
    setLoading(false)
  }

  useEffect(() => {
    load()
  }, [])

  const weekMultiplier = form.days.length || 1
  const weeks = form.totalSesi / weekMultiplier
  const canSubmit =
    form.tutor && form.subject && form.days.length > 0 && form.startDate &&
    form.totalSesi % weekMultiplier === 0 &&
    (form.mode === 'online' || form.room)

  function toggleDay(iso: number) {
    setForm((f) => ({
      ...f,
      days: f.days.includes(iso) ? f.days.filter((d) => d !== iso) : [...f.days, iso].sort(),
    }))
  }

  async function onSubmit(e: FormEvent) {
    e.preventDefault()
    setBusy(true)
    setNotice(null)
    const { data, error } = await supabase.rpc('admin_create_group_class', {
      p_tutor: form.tutor,
      p_subject: form.subject,
      p_jenjang: form.jenjang,
      p_mode: form.mode,
      p_room_id: form.mode === 'offline' ? form.room : null,
      p_duration: Number(form.duration),
      p_total_sesi: Number(form.totalSesi),
      p_days: form.days,
      p_start_date: form.startDate,
      p_time: form.time,
    })
    setBusy(false)
    if (error) {
      setNotice(`Gagal: ${error.message}`)
      return
    }
    setNotice(`Program dibuat (${data}).`)
    load()
  }

  async function openSeats(id: string) {
    if (openId === id) {
      setOpenId(null)
      return
    }
    setOpenId(id)
    if (!seats[id]) {
      const { data } = await supabase
        .from('group_seats')
        .select('id, status, price_paid, refund_amount, students(full_name)')
        .eq('group_class_id', id)
        .order('created_at')
      setSeats((s) => ({ ...s, [id]: (data as unknown as Seat[]) ?? [] }))
    }
  }

  async function refund(seat: Seat) {
    if (!confirm(`Refund kursi ${seat.students?.full_name ?? ''} sebesar ${rupiah(seat.price_paid)}?\n\nHanya mencatat; dana dikembalikan manual via Midtrans.`)) return
    const { data, error } = await supabase.rpc('refund_group_seat', { p_seat_id: seat.id })
    if (error) {
      setNotice(`Gagal: ${error.message}`)
      return
    }
    setNotice(`Refund tercatat: ${rupiah(Number(data))}.`)
    setSeats({})
    setOpenId(null)
    load()
  }

  const summary = useMemo(
    () => rows.map((r) => {
      const sorted = [...(r.group_sessions ?? [])].sort((a, b) => a.seq - b.seq)
      return { first: sorted[0]?.scheduled_at, last: sorted[sorted.length - 1]?.scheduled_at }
    }),
    [rows],
  )

  const fmt = (iso?: string) =>
    iso ? new Date(iso).toLocaleString('id-ID', { dateStyle: 'medium', timeStyle: 'short' }) : '—'

  return (
    <section>
      <h1>Kelas Grup</h1>
      <p className="muted">
        Program jadwal tetap, maks 5 kursi, <strong>minimal 3</strong>. Kalau kurang dari 3 pada
        tenggat (H-1 20:00 WIB), program otomatis batal. Pembayaran sekali per kursi.
      </p>

      <form className="tutor-form" onSubmit={onSubmit}>
        <select value={form.tutor} onChange={(e) => setForm({ ...form, tutor: e.target.value })} required>
          <option value="">Tutor…</option>
          {tutors.map((t) => <option key={t.id} value={t.id}>{t.full_name}</option>)}
        </select>
        <select value={form.subject} onChange={(e) => setForm({ ...form, subject: e.target.value })} required>
          <option value="">Mapel…</option>
          {subjects.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
        </select>
        <select value={form.jenjang} onChange={(e) => setForm({ ...form, jenjang: e.target.value })}>
          {['SD', 'SMP', 'SMA'].map((j) => <option key={j} value={j}>{j}</option>)}
        </select>
        <select value={form.mode} onChange={(e) => setForm({ ...form, mode: e.target.value, room: '' })}>
          <option value="offline">Offline</option>
          <option value="online">Online</option>
        </select>
        {form.mode === 'offline' && (
          <select value={form.room} onChange={(e) => setForm({ ...form, room: e.target.value })} required>
            <option value="">Ruangan…</option>
            {rooms.map((r) => <option key={r.id} value={r.id}>{r.name}</option>)}
          </select>
        )}
        <select value={form.duration} onChange={(e) => setForm({ ...form, duration: Number(e.target.value) })}>
          {[60, 90, 120].map((d) => <option key={d} value={d}>{d} menit</option>)}
        </select>
        <select value={form.totalSesi} onChange={(e) => setForm({ ...form, totalSesi: Number(e.target.value) })}>
          {[4, 8, 12].map((n) => <option key={n} value={n}>{n} sesi</option>)}
        </select>
        <input type="date" value={form.startDate} onChange={(e) => setForm({ ...form, startDate: e.target.value })} required />
        <input type="time" value={form.time} onChange={(e) => setForm({ ...form, time: e.target.value })} required />

        <span className="toggle">
          Hari:
          {DAYS.map((d) => (
            <label key={d.iso} style={{ display: 'inline-flex', gap: 4, alignItems: 'center' }}>
              <input type="checkbox" checked={form.days.includes(d.iso)} onChange={() => toggleDay(d.iso)} />
              {d.label}
            </label>
          ))}
        </span>

        <button type="submit" disabled={busy || !canSubmit}>
          {busy ? 'Menyimpan…' : 'Buat program'}
        </button>
        {canSubmit && <span className="muted">= {weeks} minggu</span>}
      </form>

      {notice && <pre className="notice-line">{notice}</pre>}

      {loading ? (
        <p className="muted">Memuat…</p>
      ) : rows.length === 0 ? (
        <p className="muted">Belum ada program kelas grup.</p>
      ) : (
        <table className="table">
          <thead>
            <tr>
              <th>Tutor · Mapel</th>
              <th>Jadwal</th>
              <th>Sesi</th>
              <th>Kursi</th>
              <th>Harga/kursi</th>
              <th>Tenggat</th>
              <th>Status</th>
              <th>Aksi</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((r, i) => (
              <Fragment key={r.id}>
                <tr>
                  <td>
                    {r.tutors?.full_name ?? '—'} · {r.subjects?.name ?? '—'} · {r.jenjang}
                    <div className="muted">
                      {r.mode === 'online' ? 'Online' : `Offline · ${r.rooms?.name ?? '-'}`} ·{' '}
                      {r.duration_minutes} menit
                    </div>
                  </td>
                  <td className="muted">
                    {fmt(summary[i]?.first)}
                    <br />s/d {fmt(summary[i]?.last)}
                  </td>
                  <td>{r.total_sesi}× (−{r.discount_percent}%)</td>
                  <td>
                    <strong>{r.seats_taken}</strong>/{r.max_seats}
                    <div className="muted">min {r.min_seats}</div>
                  </td>
                  <td>{rupiah(r.price_total)}</td>
                  <td className="muted">{fmt(r.min_confirm_deadline)}</td>
                  <td>
                    <span className={`status ${STATUS_CLASS[r.status] ?? 'status-diundang'}`}>
                      {STATUS_LABEL[r.status] ?? r.status}
                    </span>
                  </td>
                  <td className="actions">
                    <button onClick={() => openSeats(r.id)}>
                      {openId === r.id ? 'Tutup' : 'Lihat kursi'}
                    </button>
                  </td>
                </tr>
                {openId === r.id && (
                  <tr key={`${r.id}-seats`}>
                    <td colSpan={8}>
                      {(seats[r.id] ?? []).length === 0 ? (
                        <span className="muted">Belum ada kursi diambil.</span>
                      ) : (
                        <table className="table">
                          <thead>
                            <tr>
                              <th>Siswa</th>
                              <th>Status</th>
                              <th>Dibayar</th>
                              <th>Refund</th>
                              <th>Aksi</th>
                            </tr>
                          </thead>
                          <tbody>
                            {(seats[r.id] ?? []).map((s) => (
                              <tr key={s.id}>
                                <td>{s.students?.full_name ?? '—'}</td>
                                <td>{SEAT_LABEL[s.status] ?? s.status}</td>
                                <td>{rupiah(s.price_paid)}</td>
                                <td className="muted">
                                  {s.refund_amount ? rupiah(s.refund_amount) : '—'}
                                </td>
                                <td className="actions">
                                  {s.status === 'refund_pending' || s.status === 'active' ? (
                                    <button onClick={() => refund(s)}>
                                      Refund {rupiah(s.price_paid)}
                                    </button>
                                  ) : (
                                    <span className="muted">—</span>
                                  )}
                                </td>
                              </tr>
                            ))}
                          </tbody>
                        </table>
                      )}
                    </td>
                  </tr>
                )}
              </Fragment>
            ))}
          </tbody>
        </table>
      )}
    </section>
  )
}
