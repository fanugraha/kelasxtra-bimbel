import { useEffect, useMemo, useState } from 'react'
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

const STATUS_META: Record<string, { label: string; tone: string }> = {
  open: { label: 'Dibuka', tone: 'info' },
  confirmed: { label: 'Terkonfirmasi', tone: 'success' },
  cancelled: { label: 'Batal', tone: 'danger' },
  completed: { label: 'Selesai', tone: 'neutral' },
}

const SEAT_META: Record<string, { label: string; tone: string }> = {
  pending_payment: { label: 'Menunggu bayar', tone: 'warning' },
  active: { label: 'Aktif', tone: 'success' },
  refund_pending: { label: 'Perlu refund', tone: 'danger' },
  refunded: { label: 'Sudah refund', tone: 'neutral' },
  cancelled: { label: 'Batal', tone: 'neutral' },
}

const rupiah = (n: number) => 'Rp' + n.toLocaleString('id-ID')

const shortDate = (iso?: string) =>
  iso
    ? new Intl.DateTimeFormat('id-ID', {
        day: '2-digit',
        month: 'short',
        timeZone: 'Asia/Jakarta',
      }).format(new Date(iso))
    : '—'

const fullDate = (iso?: string) =>
  iso
    ? new Intl.DateTimeFormat('id-ID', {
        dateStyle: 'medium',
        timeStyle: 'short',
        timeZone: 'Asia/Jakarta',
      }).format(new Date(iso))
    : '—'

const timeOf = (iso?: string) =>
  iso
    ? new Intl.DateTimeFormat('id-ID', {
        hour: '2-digit',
        minute: '2-digit',
        hour12: false,
        timeZone: 'Asia/Jakarta',
      }).format(new Date(iso))
    : '—'

function relative(iso: string) {
  const days = Math.ceil((new Date(iso).getTime() - Date.now()) / 86_400_000)
  if (days < 0) return 'terlewat'
  if (days === 0) return 'hari ini'
  if (days === 1) return 'besok'
  return `${days} hari lagi`
}

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
  const [showForm, setShowForm] = useState(false)
  const [busy, setBusy] = useState(false)
  const [notice, setNotice] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)
  const [search, setSearch] = useState('')
  const [filter, setFilter] = useState<'all' | 'attention'>('all')
  const [sort, setSort] = useState<'fill' | 'due' | 'name'>('fill')

  async function load() {
    const [t, s, r, g] = await Promise.all([
      supabase.from('tutors').select('id, full_name').eq('status', 'aktif').order('full_name'),
      supabase.from('subjects').select('id, name').eq('active', true).order('name'),
      supabase.from('rooms').select('id, name').eq('active', true).order('name'),
      supabase
        .from('group_classes')
        .select(
          'id, jenjang, mode, duration_minutes, total_sesi, discount_percent, price_per_session, ' +
            'price_total, min_seats, max_seats, seats_taken, status, min_confirm_deadline, ' +
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
    queueMicrotask(load)
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
    setShowForm(false)
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

  function range(row: GroupClass) {
    const sorted = [...(row.group_sessions ?? [])].sort((a, b) => a.seq - b.seq)
    return { first: sorted[0]?.scheduled_at, last: sorted[sorted.length - 1]?.scheduled_at }
  }

  const shown = useMemo(() => {
    const term = search.trim().toLowerCase()
    const list = rows.filter((row) => {
      if (filter === 'attention' && !(row.status === 'open' && row.seats_taken < row.min_seats)) {
        return false
      }
      if (!term) return true
      return [row.subjects?.name, row.tutors?.full_name]
        .filter(Boolean)
        .some((value) => value!.toLowerCase().includes(term))
    })
    return list.sort((a, b) => {
      if (sort === 'name') return (a.subjects?.name ?? '').localeCompare(b.subjects?.name ?? '')
      if (sort === 'due') return new Date(a.min_confirm_deadline).getTime() - new Date(b.min_confirm_deadline).getTime()
      return a.seats_taken / a.max_seats - b.seats_taken / b.max_seats
    })
  }, [rows, filter, search, sort])

  const attention = rows.filter((row) => row.status === 'open' && row.seats_taken < row.min_seats)
  const totalSeats = rows.reduce((sum, row) => sum + row.seats_taken, 0)
  const totalCap = rows.reduce((sum, row) => sum + row.max_seats, 0)
  const nearest = rows
    .filter((row) => row.status === 'open' || row.status === 'confirmed')
    .sort((a, b) => new Date(a.min_confirm_deadline).getTime() - new Date(b.min_confirm_deadline).getTime())[0]

  return (
    <section>
      <div className="page-head">
        <div>
          <p className="eyebrow">Operasional · Kelas grup</p>
          <h1 className="page-title">Kelas grup</h1>
          <p className="page-sub">
            Kuota minimum 3 siswa, maksimal 5 kursi. Program batal otomatis bila kuota tidak terpenuhi pada tenggat H-1 20:00 WIB.
          </p>
        </div>
        <div className="head-actions">
          <button className="btn btn-primary" onClick={() => setShowForm((value) => !value)}>
            {showForm ? 'Tutup formulir' : 'Buat program'}
          </button>
        </div>
      </div>

      {showForm && (
        <div className="card" style={{ marginBottom: 14 }}>
          <div className="card-head">
            <div>
              <h2 className="card-title">Program baru</h2>
              <p className="card-sub">Pertemuan disusun otomatis 2× per minggu sesuai hari yang dipilih.</p>
            </div>
          </div>
          <form className="card-body" onSubmit={onSubmit}>
            <div className="form-grid">
              <label className="field">
                <span>Tutor</span>
                <select className="select" value={form.tutor} onChange={(e) => setForm({ ...form, tutor: e.target.value })} required>
                  <option value="">Pilih tutor…</option>
                  {tutors.map((t) => <option key={t.id} value={t.id}>{t.full_name}</option>)}
                </select>
              </label>
              <label className="field">
                <span>Mata pelajaran</span>
                <select className="select" value={form.subject} onChange={(e) => setForm({ ...form, subject: e.target.value })} required>
                  <option value="">Pilih mapel…</option>
                  {subjects.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
                </select>
              </label>
              <label className="field">
                <span>Jenjang</span>
                <select className="select" value={form.jenjang} onChange={(e) => setForm({ ...form, jenjang: e.target.value })}>
                  {['SD', 'SMP', 'SMA'].map((j) => <option key={j} value={j}>{j}</option>)}
                </select>
              </label>
              <label className="field">
                <span>Mode</span>
                <select className="select" value={form.mode} onChange={(e) => setForm({ ...form, mode: e.target.value, room: '' })}>
                  <option value="offline">Offline</option>
                  <option value="online">Online</option>
                </select>
              </label>
              {form.mode === 'offline' && (
                <label className="field">
                  <span>Ruangan</span>
                  <select className="select" value={form.room} onChange={(e) => setForm({ ...form, room: e.target.value })} required>
                    <option value="">Pilih ruangan…</option>
                    {rooms.map((r) => <option key={r.id} value={r.id}>{r.name}</option>)}
                  </select>
                </label>
              )}
              <label className="field">
                <span>Durasi</span>
                <select className="select" value={form.duration} onChange={(e) => setForm({ ...form, duration: Number(e.target.value) })}>
                  {[60, 90, 120].map((d) => <option key={d} value={d}>{d} menit</option>)}
                </select>
              </label>
              <label className="field">
                <span>Jumlah sesi</span>
                <select className="select" value={form.totalSesi} onChange={(e) => setForm({ ...form, totalSesi: Number(e.target.value) })}>
                  {[4, 8, 12].map((n) => <option key={n} value={n}>{n} sesi</option>)}
                </select>
              </label>
              <label className="field">
                <span>Mulai</span>
                <input className="input" type="date" value={form.startDate} onChange={(e) => setForm({ ...form, startDate: e.target.value })} required />
              </label>
              <label className="field">
                <span>Jam</span>
                <input className="input" type="time" value={form.time} onChange={(e) => setForm({ ...form, time: e.target.value })} required />
              </label>
              <div className="field">
                <span>Hari</span>
                <div className="head-actions">
                  {DAYS.map((d) => (
                    <label key={d.iso} className="btn btn-secondary btn-sm" style={{ gap: 5 }}>
                      <input
                        type="checkbox"
                        checked={form.days.includes(d.iso)}
                        onChange={() => toggleDay(d.iso)}
                        style={{ width: 14, height: 14, accentColor: 'var(--accent)' }}
                      />
                      {d.label}
                    </label>
                  ))}
                </div>
              </div>
            </div>
            <div className="head-actions" style={{ marginTop: 14 }}>
              <button className="btn btn-primary" type="submit" disabled={busy || !canSubmit}>
                {busy ? 'Menyimpan…' : 'Buat program'}
              </button>
              {canSubmit && <span className="sub">= {weeks} minggu</span>}
            </div>
          </form>
        </div>
      )}

      {notice && (
        <div className="note" style={{ marginBottom: 14 }}>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
            <circle cx="12" cy="12" r="9" />
            <path d="M12 11v5M12 8h.01" />
          </svg>
          <span>{notice}</span>
        </div>
      )}

      <div className="grp-summary">
        <article className="grp-summary-card">
          <p className="ov-label">
            <span className="grp-summary-dot" aria-hidden="true" />
            Perlu tindakan
          </p>
          <p className="ov-value">
            <span>{attention.length}</span>
            <span className="grp-unit">program</span>
          </p>
          <p className="ov-note">Kuota minimum belum terpenuhi</p>
        </article>
        <article className="grp-summary-card">
          <p className="ov-label">Kursi terisi</p>
          <p className="ov-value">
            {totalSeats}
            <span className="grp-unit">/{totalCap}</span>
          </p>
          <p className="ov-note">{rows.length} program</p>
        </article>
        <article className="grp-summary-card">
          <p className="ov-label">Batas terdekat</p>
          <p className="ov-value">{nearest ? shortDate(nearest.min_confirm_deadline) : '—'}</p>
          <p className="ov-note">
            {nearest ? `${nearest.subjects?.name ?? 'Program'} · ${relative(nearest.min_confirm_deadline)}` : 'Belum ada tenggat'}
          </p>
        </article>
      </div>

      <div className="card">
        <div className="card-head">
          <div>
            <h2 className="card-title">Program grup</h2>
            <p className="card-sub">Kuota minimum 3 siswa · maksimal 5 kursi</p>
          </div>
          <p className="grp-count">{shown.length} program</p>
        </div>

        <div className="toolbar grp-toolbar">
          <div className="segmented" role="group" aria-label="Saring program grup">
            <button aria-pressed={filter === 'all'} onClick={() => setFilter('all')}>
              Semua <span className="grp-filter-count">{rows.length}</span>
            </button>
            <button aria-pressed={filter === 'attention'} onClick={() => setFilter('attention')}>
              Perlu tindakan <span className="grp-filter-count">{attention.length}</span>
            </button>
          </div>
          <div className="spacer" />
          <div className="search grp-search">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" aria-hidden="true">
              <circle cx="11" cy="11" r="7" />
              <path d="m20 20-3.5-3.5" />
            </svg>
            <input
              className="input"
              type="search"
              placeholder="Cari program atau tutor"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              aria-label="Cari program"
            />
          </div>
          <select className="select grp-sort" value={sort} onChange={(e) => setSort(e.target.value as 'fill' | 'due' | 'name')} aria-label="Urutkan program">
            <option value="fill">Keterisian terendah</option>
            <option value="due">Batas waktu terdekat</option>
            <option value="name">Nama program A–Z</option>
          </select>
        </div>

        <div className="grp-list">
          {loading ? (
            <div className="empty-state">
              <strong>Memuat program…</strong>
            </div>
          ) : shown.length === 0 ? (
            <div className="empty-state">
              <strong>Belum ada program</strong>
              <span>Buat program baru lewat tombol di kanan atas.</span>
            </div>
          ) : (
            shown.map((row) => {
              const meta = STATUS_META[row.status] ?? { label: row.status, tone: 'neutral' }
              const span = range(row)
              const fill = Math.round((row.seats_taken / row.max_seats) * 100)
              const lacking = Math.max(0, row.min_seats - row.seats_taken)
              const open = openId === row.id
              return (
                <div key={row.id}>
                  <article className="grp-item">
                    <div className="grp-item-main">
                      <div className="grp-title">
                        <h3>{row.subjects?.name ?? 'Kelas grup'}</h3>
                        <span className={`badge ${meta.tone}`}>{meta.label}</span>
                      </div>
                      <p className="grp-meta">
                        {row.tutors?.full_name ?? '—'} · {row.jenjang} ·{' '}
                        {row.mode === 'online' ? 'Online' : `Offline · ${row.rooms?.name ?? '—'}`}
                      </p>
                    </div>
                    <div className="grp-schedule">
                      <span className="grp-date">
                        {shortDate(span.first)} – {shortDate(span.last)}
                      </span>
                      <span className="grp-time">{timeOf(span.first)} WIB · {row.total_sesi}×</span>
                    </div>
                    <div className="grp-fill">
                      <div className="progress-row">
                        <span className={`progress${row.seats_taken >= row.max_seats ? ' done' : row.seats_taken < row.min_seats ? ' warn' : ''}`}>
                          <span style={{ width: `${fill}%` }} />
                        </span>
                        <span className="num">{row.seats_taken}/{row.max_seats}</span>
                      </div>
                      <span className={`grp-fill-note${lacking > 0 ? ' is-danger' : ''}`}>
                        {lacking > 0 ? `Kurang ${lacking} siswa` : row.seats_taken >= row.max_seats ? 'Kursi penuh' : `Sisa ${row.max_seats - row.seats_taken} kursi`}
                      </span>
                    </div>
                    <div className="grp-due">
                      <span className="grp-date">{shortDate(row.min_confirm_deadline)}</span>
                      <span className="grp-time">{relative(row.min_confirm_deadline)}</span>
                    </div>
                    <div className="grp-actions">
                      <button className="btn btn-secondary btn-sm" onClick={() => openSeats(row.id)}>
                        {open ? 'Tutup' : 'Kelola kursi'}
                      </button>
                    </div>
                  </article>
                  <div className="grp-detail" hidden={!open}>
                    <div className="grp-detail-panel">
                      <dl className="grp-detail-grid">
                        <div>
                          <dt>Tempat</dt>
                          <dd>
                            {row.mode === 'online' ? 'Online' : row.rooms?.name ?? '—'}
                            <span>{row.mode === 'online' ? 'Tautan dikirim H-1' : `${row.jenjang} · ${row.duration_minutes} menit`}</span>
                          </dd>
                        </div>
                        <div>
                          <dt>Harga / sesi</dt>
                          <dd>{rupiah(row.price_per_session)}<span>per siswa</span></dd>
                        </div>
                        <div>
                          <dt>Kursi</dt>
                          <dd>{row.seats_taken} dari {row.max_seats}<span>minimal {row.min_seats}</span></dd>
                        </div>
                        <div>
                          <dt>Batas waktu</dt>
                          <dd>{fullDate(row.min_confirm_deadline)}<span>{relative(row.min_confirm_deadline)}</span></dd>
                        </div>
                      </dl>

                      <div className="table-wrap" style={{ marginTop: 14 }}>
                        <table className="data-table" style={{ minWidth: 560 }}>
                          <thead>
                            <tr>
                              <th>Siswa</th>
                              <th>Status</th>
                              <th className="num">Dibayar</th>
                              <th className="num">Refund</th>
                              <th />
                            </tr>
                          </thead>
                          <tbody>
                            {seats[row.id] === undefined ? (
                              <tr>
                                <td colSpan={5}>
                                  <div className="empty-state">
                                    <strong>Memuat kursi…</strong>
                                  </div>
                                </td>
                              </tr>
                            ) : seats[row.id].length === 0 ? (
                              <tr>
                                <td colSpan={5}>
                                  <div className="empty-state">
                                    <strong>Belum ada kursi diambil</strong>
                                    <span>Kursi tampil setelah siswa membayar.</span>
                                  </div>
                                </td>
                              </tr>
                            ) : (
                              seats[row.id].map((seat) => {
                                const seatMeta = SEAT_META[seat.status] ?? { label: seat.status, tone: 'neutral' }
                                return (
                                  <tr key={seat.id}>
                                    <td>{seat.students?.full_name ?? '—'}</td>
                                    <td><span className={`badge ${seatMeta.tone}`}>{seatMeta.label}</span></td>
                                    <td className="num">{rupiah(seat.price_paid)}</td>
                                    <td className="num">{seat.refund_amount ? rupiah(seat.refund_amount) : '—'}</td>
                                    <td>
                                      <div className="row-actions">
                                        {seat.status === 'refund_pending' || seat.status === 'active' ? (
                                          <button className="btn btn-secondary btn-sm" onClick={() => refund(seat)}>
                                            Refund
                                          </button>
                                        ) : null}
                                      </div>
                                    </td>
                                  </tr>
                                )
                              })
                            )}
                          </tbody>
                        </table>
                      </div>
                    </div>
                  </div>
                </div>
              )
            })
          )}
        </div>
      </div>
    </section>
  )
}
