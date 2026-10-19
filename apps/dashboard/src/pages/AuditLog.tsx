import { useEffect, useState } from 'react'
import { formatDateTime } from '../lib/format'
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

  async function load(term = filter) {
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
    if (term.trim()) q = q.ilike('action', `%${term.trim()}%`)
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
      <div className="page-head">
        <div>
          <p className="eyebrow">Sistem · Riwayat aktivitas</p>
          <h1 className="page-title">Riwayat aktivitas</h1>
          <p className="page-sub">
            Hanya bisa dilihat. Menyimpan 200 kegiatan terakhir beserta perubahan datanya.
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

      <div className="card">
        <div className="toolbar">
          <div className="search">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" aria-hidden="true">
              <circle cx="11" cy="11" r="7" />
              <path d="m20 20-3.5-3.5" />
            </svg>
            <input
              className="input"
              type="search"
              placeholder="Filter aksi (mis. payroll)"
              value={filter}
              onChange={(e) => setFilter(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === 'Enter') load()
              }}
              aria-label="Filter aksi"
            />
          </div>
          <button className="btn btn-secondary btn-sm" onClick={() => load()} disabled={loading}>
            {loading ? 'Memuat…' : 'Cari'}
          </button>
          {filter && (
            <button
              className="btn btn-ghost btn-sm"
              onClick={() => {
                setFilter('')
                load('')
              }}
            >
              Reset filter
            </button>
          )}
          <div className="spacer" />
          <span className="badge neutral">{rows.length} catatan</span>
        </div>

        <div className="table-wrap">
          <table className="data-table" style={{ minWidth: 980 }}>
            <thead>
              <tr>
                <th>Waktu</th>
                <th>Pelaku</th>
                <th>Kegiatan</th>
                <th>Bagian</th>
                <th>Nomor</th>
                <th>Sebelum</th>
                <th>Sesudah</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan={7}>
                    <div className="empty-state">
                      <strong>Memuat catatan…</strong>
                    </div>
                  </td>
                </tr>
              ) : rows.length === 0 ? (
                <tr>
                  <td colSpan={7}>
                    <div className="empty-state">
                      <strong>Belum ada catatan</strong>
                      <span>Aksi sensitif akan tercatat di sini.</span>
                    </div>
                  </td>
                </tr>
              ) : (
                rows.map((r) => (
                  <tr key={r.id}>
                    <td className="num">
                      {formatDateTime(r.created_at)}
                    </td>
                    <td>{r.profiles?.full_name ?? r.profiles?.email ?? r.actor_id ?? 'sistem'}</td>
                    <td className="strong">{r.action}</td>
                    <td>{r.entity}</td>
                    <td className="num">{r.entity_id?.slice(0, 8) ?? '—'}</td>
                    <td className="sub" style={{ maxWidth: 220, wordBreak: 'break-word' }}>
                      {pretty(r.before_data)}
                    </td>
                    <td className="sub" style={{ maxWidth: 260, wordBreak: 'break-word' }}>
                      {pretty(r.after_data)}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
        <div className="card-foot">
          <div className="note">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
              <circle cx="12" cy="12" r="9" />
              <path d="M12 11v5M12 8h.01" />
            </svg>
            <span>Riwayat ini tidak bisa diubah atau dihapus dari halaman ini.</span>
          </div>
        </div>
      </div>
    </section>
  )
}
