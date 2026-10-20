import { useEffect, useMemo, useState } from 'react'
import type { FormEvent } from 'react'
import { formatDate } from '../lib/format'
import { invokeFn } from '../lib/functions'
import { supabase } from '../lib/supabase'
import { initials } from '../lib/text'

interface TutorRow {
  id: string
  full_name: string
  status: 'diundang' | 'aktif' | 'suspend'
  education: string | null
  bank_name: string | null
  invite_expires_at: string | null
  created_at: string
}

const STATUS_LABEL: Record<TutorRow['status'], { label: string; tone: string }> = {
  diundang: { label: 'Diundang', tone: 'warning' },
  aktif: { label: 'Aktif', tone: 'success' },
  suspend: { label: 'Nonaktif', tone: 'neutral' },
}

export function Tutors() {
  const [rows, setRows] = useState<TutorRow[]>([])
  const [loading, setLoading] = useState(true)
  const [busyId, setBusyId] = useState<string | null>(null)
  const [notice, setNotice] = useState<string | null>(null)
  const [search, setSearch] = useState('')
  const [showInvite, setShowInvite] = useState(false)

  const [email, setEmail] = useState('')
  const [fullName, setFullName] = useState('')
  const [phone, setPhone] = useState('')
  const [creating, setCreating] = useState(false)

  async function load() {
    const { data } = await supabase
      .from('tutors')
      .select('id, full_name, status, education, bank_name, invite_expires_at, created_at')
      .order('created_at', { ascending: false })
    setRows((data as TutorRow[]) ?? [])
    setLoading(false)
  }

  useEffect(() => {
    queueMicrotask(load)
  }, [])

  async function onCreate(e: FormEvent) {
    e.preventDefault()
    setCreating(true)
    setNotice(null)
    const { data, error } = await invokeFn<{ activation_link: string; email_sent: boolean }>(
      'invite-tutor',
      { email: email.trim(), full_name: fullName.trim(), phone: phone.trim() || undefined },
    )
    setCreating(false)
    if (error) {
      setNotice(`Gagal: ${error}`)
      return
    }
    setEmail('')
    setFullName('')
    setPhone('')
    setNotice(
      data?.email_sent
        ? 'Undangan terkirim via email.'
        : `Email belum dikonfigurasi. Salin tautan ini dan kirim ke tutor:\n${data?.activation_link}`,
    )
    load()
  }

  async function onAction(id: string, action: 'suspend' | 'reactivate' | 'resend_invite') {
    if (action === 'suspend' && !confirm('Suspend tutor ini? Tutor tak bisa login sampai diaktifkan lagi.')) return
    setBusyId(id)
    setNotice(null)
    const reason = action === 'suspend' ? prompt('Alasan suspend (opsional):') ?? undefined : undefined
    const { data, error } = await invokeFn<{ activation_link?: string }>('manage-tutor', {
      tutor_id: id,
      action,
      reason,
    })
    setBusyId(null)
    if (error) {
      setNotice(`Gagal: ${error}`)
      return
    }
    if (action === 'resend_invite') {
      setNotice(`Tautan undangan baru:\n${data?.activation_link}`)
    }
    load()
  }

  async function copy(text: string) {
    try {
      await navigator.clipboard.writeText(text)
      setNotice('Tautan disalin.')
    } catch {
      setNotice('Gagal menyalin. Salin tautan secara manual.')
    }
  }

  const filtered = useMemo(() => {
    const term = search.trim().toLowerCase()
    return term ? rows.filter((t) => t.full_name.toLowerCase().includes(term)) : rows
  }, [rows, search])

  const counts = {
    aktif: rows.filter((t) => t.status === 'aktif').length,
    diundang: rows.filter((t) => t.status === 'diundang').length,
    suspend: rows.filter((t) => t.status === 'suspend').length,
  }

  return (
    <section>
      <div className="page-head">
        <div>
          <p className="eyebrow">Operasional · Tutor</p>
          <h1 className="page-title">Tutor &amp; undangan</h1>
          <p className="page-sub">
            Undangan berlaku 7 hari. Tutor membuktikan kepemilikan email dengan kode verifikasi saat aktivasi.
          </p>
        </div>
        <div className="head-actions">
          <button className="btn btn-primary" onClick={() => setShowInvite((value) => !value)}>
            {showInvite ? 'Tutup formulir' : 'Undang tutor'}
          </button>
        </div>
      </div>

      {showInvite && (
        <div className="card" style={{ marginBottom: 14 }}>
          <div className="card-head">
            <div>
              <h2 className="card-title">Undang tutor baru</h2>
              <p className="card-sub">Akun dibuat oleh admin. Tutor melengkapi profil saat aktivasi.</p>
            </div>
          </div>
          <form className="card-body" onSubmit={onCreate}>
            <div className="form-grid">
              <label className="field">
                <span>Nama lengkap</span>
                <input
                  className="input"
                  placeholder="Nama sesuai KTP"
                  value={fullName}
                  onChange={(e) => setFullName(e.target.value)}
                  required
                />
              </label>
              <label className="field">
                <span>Email</span>
                <input
                  className="input"
                  type="email"
                  placeholder="tutor@email.com"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  required
                />
              </label>
              <label className="field">
                <span>No. HP (opsional)</span>
                <input
                  className="input"
                  placeholder="08xx"
                  value={phone}
                  onChange={(e) => setPhone(e.target.value)}
                />
              </label>
            </div>
            <div className="head-actions" style={{ marginTop: 14 }}>
              <button className="btn btn-primary" type="submit" disabled={creating}>
                {creating ? 'Memproses…' : 'Buat & kirim undangan'}
              </button>
              <button className="btn btn-secondary" type="button" onClick={() => setShowInvite(false)}>
                Batal
              </button>
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
          <span style={{ whiteSpace: 'pre-wrap', wordBreak: 'break-all', flex: 1 }}>{notice}</span>
          {notice.includes('http') && (
            <button className="btn btn-secondary btn-sm" onClick={() => copy(notice.split('\n').pop() ?? '')}>
              Salin
            </button>
          )}
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
              placeholder="Cari nama tutor"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              aria-label="Cari tutor"
            />
          </div>
          <button className="btn btn-ghost btn-sm" type="button" onClick={() => setSearch('')}>
            Reset filter
          </button>
          <div className="spacer" />
          <span className="badge success">{counts.aktif} aktif</span>
          <span className="badge warning">{counts.diundang} diundang</span>
          <span className="badge neutral">{counts.suspend} nonaktif</span>
        </div>

        <div className="table-wrap">
          <table className="data-table" style={{ minWidth: 800 }}>
            <thead>
              <tr>
                <th>Tutor</th>
                <th>Pendidikan</th>
                <th>Bank</th>
                <th>Status</th>
                <th>Undangan</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan={6}>
                    <div className="empty-state">
                      <strong>Memuat tutor…</strong>
                    </div>
                  </td>
                </tr>
              ) : filtered.length === 0 ? (
                <tr>
                  <td colSpan={6}>
                    <div className="empty-state">
                      <strong>Belum ada tutor</strong>
                      <span>Undang tutor pertama lewat tombol di kanan atas.</span>
                    </div>
                  </td>
                </tr>
              ) : (
                filtered.map((t) => {
                  const meta = STATUS_LABEL[t.status]
                  const expired =
                    t.status === 'diundang' &&
                    t.invite_expires_at !== null &&
                    new Date(t.invite_expires_at) < new Date()
                  return (
                    <tr key={t.id}>
                      <td>
                        <div className="cell-person">
                          <span className="avatar">{initials(t.full_name)}</span>
                          <span>
                            <span className="strong">{t.full_name}</span>
                            <span className="sub">Bergabung {formatDate(t.created_at)}</span>
                          </span>
                        </div>
                      </td>
                      <td>{t.education ?? '—'}</td>
                      <td>{t.bank_name ?? '—'}</td>
                      <td>
                        <span className={`badge ${expired ? 'danger' : meta.tone}`}>
                          {expired ? 'Kedaluwarsa' : meta.label}
                        </span>
                      </td>
                      <td>
                        <span className="sub">
                          {t.status === 'diundang'
                            ? t.invite_expires_at
                              ? `Berlaku sampai ${formatDate(t.invite_expires_at)}`
                              : 'Belum ada tautan'
                            : '—'}
                        </span>
                      </td>
                      <td>
                        <div className="row-actions">
                          {t.status === 'diundang' && (
                            <button
                              className="btn btn-secondary btn-sm"
                              disabled={busyId === t.id}
                              onClick={() => onAction(t.id, 'resend_invite')}
                            >
                              Kirim ulang
                            </button>
                          )}
                          {t.status === 'aktif' && (
                            <button
                              className="btn btn-secondary btn-sm"
                              disabled={busyId === t.id}
                              onClick={() => onAction(t.id, 'suspend')}
                            >
                              Nonaktifkan
                            </button>
                          )}
                          {t.status === 'suspend' && (
                            <button
                              className="btn btn-secondary btn-sm"
                              disabled={busyId === t.id}
                              onClick={() => onAction(t.id, 'reactivate')}
                            >
                              Aktifkan
                            </button>
                          )}
                        </div>
                      </td>
                    </tr>
                  )
                })
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
            <span>Tautan undangan hanya bisa dipakai sekali. Setelah aktif, tutor melengkapi profil, pendidikan, dan rekening bank.</span>
          </div>
        </div>
      </div>
    </section>
  )
}
