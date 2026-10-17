import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'

interface AuditRow {
  id: number
  actor_id: string | null
  action: string
  entity: string
  entity_id: string | null
  before_data: unknown
  after_data: unknown
  created_at: string
  profiles: { full_name: string; email: string | null } | null
}

export function AuditLog() {
  const [rows, setRows] = useState<AuditRow[]>([])
  const [filter, setFilter] = useState('')
  const [loading, setLoading] = useState(true)
  const [notice, setNotice] = useState<string | null>(null)

  async function load() {
    setLoading(true)
    setNotice(null)
    let q = supabase
      .from('audit_logs')
      .select(
        'id, actor_id, action, entity, entity_id, before_data, after_data, ' +
          'created_at, profiles(full_name, email)',
      )
      .order('created_at', { ascending: false })
      .limit(200)
    if (filter.trim()) q = q.ilike('action', `%${filter.trim()}%`)
    const { data, error } = await q
    if (error) setNotice(`Gagal memuat: ${error.message}`)
    setRows((data as unknown as AuditRow[]) ?? [])
    setLoading(false)
  }

  useEffect(() => {
    queueMicrotask(load)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  const pretty = (v: unknown) => {
    if (v == null) return '—'
    try {
      return JSON.stringify(v)
    } catch {
      return String(v)
    }
  }

  return (
    <section>
      <h1>Audit Log</h1>
      <p className="muted">
        Jejak aksi sensitif: refund, koreksi absensi, perubahan status soal, payroll,
        transfer paket. Hanya admin yang bisa membaca.
      </p>

      <div className="tutor-form">
        <input
          placeholder="Filter aksi (mis. payroll / booking.correct)"
          value={filter}
          onChange={(e) => setFilter(e.target.value)}
        />
        <button onClick={load} disabled={loading}>
          {loading ? 'Memuat…' : 'Cari'}
        </button>
      </div>

      {notice && <pre className="notice-line">{notice}</pre>}

      {loading ? (
        <p className="muted">Memuat…</p>
      ) : rows.length === 0 ? (
        <p className="muted">Belum ada catatan.</p>
      ) : (
        <table className="table">
          <thead>
            <tr>
              <th>Waktu</th>
              <th>Aktor</th>
              <th>Aksi</th>
              <th>Entitas</th>
              <th>ID</th>
              <th>Sebelum</th>
              <th>Sesudah</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((r) => (
              <tr key={r.id}>
                <td className="muted">{new Date(r.created_at).toLocaleString('id-ID')}</td>
                <td>{r.profiles?.full_name ?? r.actor_id ?? 'sistem'}</td>
                <td>{r.action}</td>
                <td>{r.entity}</td>
                <td className="muted" style={{ fontSize: 12 }}>
                  {r.entity_id ?? '—'}
                </td>
                <td className="muted" style={{ fontSize: 12, maxWidth: 220, wordBreak: 'break-word' }}>
                  {pretty(r.before_data)}
                </td>
                <td className="muted" style={{ fontSize: 12, maxWidth: 260, wordBreak: 'break-word' }}>
                  {pretty(r.after_data)}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </section>
  )
}
