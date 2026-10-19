import { useEffect, useMemo, useState } from 'react'
import type { FormEvent } from 'react'
import { rupiah } from '../../lib/format'
import { supabase } from '../../lib/supabase'
import { GroupCard } from './GroupCard'
import { GroupProgramForm } from './GroupProgramForm'
import { GroupSummary } from './GroupSummary'
import { GroupToolbar } from './GroupToolbar'
import { emptyForm } from './types'
import type {
  GroupClass,
  GroupFilter,
  GroupFormState,
  GroupSort,
  Option,
  Seat,
} from './types'

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
  const [filter, setFilter] = useState<GroupFilter>('all')
  const [sort, setSort] = useState<GroupSort>('fill')

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
  const canSubmit = Boolean(
    form.tutor && form.subject && form.days.length > 0 && form.startDate &&
      form.totalSesi % weekMultiplier === 0 &&
      (form.mode === 'online' || form.room),
  )

  function patchForm(patch: Partial<GroupFormState>) {
    setForm((f) => ({ ...f, ...patch }))
  }

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

  async function cancelToCredit(seat: Seat) {
    if (
      !confirm(
        `Batalkan kursi ${seat.students?.full_name ?? ''} sebesar ${rupiah(seat.price_paid)}?\n\n` +
          'Tidak ada pengembalian uang: nilainya masuk sebagai POIN siswa (1 poin = Rp1).',
      )
    )
      return
    const { data, error } = await supabase.rpc('cancel_group_seat_with_credit', {
      p_seat_id: seat.id,
      p_note: 'Pembatalan oleh admin',
    })
    if (error) {
      setNotice(`Gagal: ${error.message}`)
      return
    }
    setNotice(`Kursi dibatalkan. Poin siswa: ${rupiah(Number(data))}.`)
    setSeats({})
    setOpenId(null)
    load()
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
        <GroupProgramForm
          tutors={tutors}
          subjects={subjects}
          rooms={rooms}
          form={form}
          onPatch={patchForm}
          onToggleDay={toggleDay}
          onSubmit={onSubmit}
          busy={busy}
          canSubmit={canSubmit}
          weeks={weeks}
        />
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

      <GroupSummary
        attentionCount={attention.length}
        totalSeats={totalSeats}
        totalCap={totalCap}
        programCount={rows.length}
        nearest={nearest}
      />

      <div className="card">
        <div className="card-head">
          <div>
            <h2 className="card-title">Program grup</h2>
            <p className="card-sub">Kuota minimum 3 siswa · maksimal 5 kursi</p>
          </div>
          <p className="grp-count">{shown.length} program</p>
        </div>

        <GroupToolbar
          filter={filter}
          onFilter={setFilter}
          search={search}
          onSearch={setSearch}
          sort={sort}
          onSort={setSort}
          total={rows.length}
          attentionCount={attention.length}
        />

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
            shown.map((row) => (
              <GroupCard
                key={row.id}
                row={row}
                open={openId === row.id}
                seats={seats[row.id]}
                onToggleSeats={() => openSeats(row.id)}
                onCancelToCredit={cancelToCredit}
              />
            ))
          )}
        </div>
      </div>
    </section>
  )
}
