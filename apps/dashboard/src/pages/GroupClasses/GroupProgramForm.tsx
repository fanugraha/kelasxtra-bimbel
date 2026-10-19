import type { FormEvent } from 'react'
import { DAYS } from './types'
import type { GroupFormState, Option } from './types'

export function GroupProgramForm({
  tutors,
  subjects,
  rooms,
  form,
  onPatch,
  onToggleDay,
  onSubmit,
  busy,
  canSubmit,
  weeks,
}: {
  tutors: { id: string; full_name: string }[]
  subjects: Option[]
  rooms: Option[]
  form: GroupFormState
  onPatch: (patch: Partial<GroupFormState>) => void
  onToggleDay: (iso: number) => void
  onSubmit: (e: FormEvent) => void
  busy: boolean
  canSubmit: boolean
  weeks: number
}) {
  return (
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
            <select className="select" value={form.tutor} onChange={(e) => onPatch({ tutor: e.target.value })} required>
              <option value="">Pilih tutor…</option>
              {tutors.map((t) => <option key={t.id} value={t.id}>{t.full_name}</option>)}
            </select>
          </label>
          <label className="field">
            <span>Mata pelajaran</span>
            <select className="select" value={form.subject} onChange={(e) => onPatch({ subject: e.target.value })} required>
              <option value="">Pilih mapel…</option>
              {subjects.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
            </select>
          </label>
          <label className="field">
            <span>Jenjang</span>
            <select className="select" value={form.jenjang} onChange={(e) => onPatch({ jenjang: e.target.value })}>
              {['SD', 'SMP', 'SMA'].map((j) => <option key={j} value={j}>{j}</option>)}
            </select>
          </label>
          <label className="field">
            <span>Mode</span>
            <select className="select" value={form.mode} onChange={(e) => onPatch({ mode: e.target.value, room: '' })}>
              <option value="offline">Offline</option>
              <option value="online">Online</option>
            </select>
          </label>
          {form.mode === 'offline' && (
            <label className="field">
              <span>Ruangan</span>
              <select className="select" value={form.room} onChange={(e) => onPatch({ room: e.target.value })} required>
                <option value="">Pilih ruangan…</option>
                {rooms.map((r) => <option key={r.id} value={r.id}>{r.name}</option>)}
              </select>
            </label>
          )}
          <label className="field">
            <span>Durasi</span>
            <select className="select" value={form.duration} onChange={(e) => onPatch({ duration: Number(e.target.value) })}>
              {[60, 90, 120].map((d) => <option key={d} value={d}>{d} menit</option>)}
            </select>
          </label>
          <label className="field">
            <span>Jumlah sesi</span>
            <select className="select" value={form.totalSesi} onChange={(e) => onPatch({ totalSesi: Number(e.target.value) })}>
              {[4, 8, 12].map((n) => <option key={n} value={n}>{n} sesi</option>)}
            </select>
          </label>
          <label className="field">
            <span>Mulai</span>
            <input className="input" type="date" value={form.startDate} onChange={(e) => onPatch({ startDate: e.target.value })} required />
          </label>
          <label className="field">
            <span>Jam</span>
            <input className="input" type="time" value={form.time} onChange={(e) => onPatch({ time: e.target.value })} required />
          </label>
          <div className="field">
            <span>Hari</span>
            <div className="head-actions">
              {DAYS.map((d) => (
                <label key={d.iso} className="btn btn-secondary btn-sm" style={{ gap: 5 }}>
                  <input
                    type="checkbox"
                    checked={form.days.includes(d.iso)}
                    onChange={() => onToggleDay(d.iso)}
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
  )
}
