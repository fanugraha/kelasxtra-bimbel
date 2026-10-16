import { useEffect, useState } from 'react'
import type { FormEvent } from 'react'
import { supabase } from '../lib/supabase'

interface TutorRow {
  id: string
  full_name: string
  status: 'diundang' | 'aktif' | 'suspend'
  education: string | null
  bank_name: string | null
  invite_expires_at: string | null
}

const STATUS_LABEL: Record<TutorRow['status'], string> = {
  diundang: 'Diundang',
  aktif: 'Aktif',
  suspend: 'Suspend',
}

async function invokeFn<T>(name: string, body: Record<string, unknown>): Promise<{ data: T | null; error: string | null }> {
  const { data, error } = await supabase.functions.invoke(name, { body })
  if (error) {
    const detail = await (error as { context?: Response }).context?.json?.().catch(() => null)
    return { data: null, error: detail?.error ?? error.message }
  }
  return { data: data as T, error: null }
}

export function Tutors() {
  const [rows, setRows] = useState<TutorRow[]>([])
  const [loading, setLoading] = useState(true)
  const [busyId, setBusyId] = useState<string | null>(null)
  const [notice, setNotice] = useState<string | null>(null)

  const [email, setEmail] = useState('')
  const [fullName, setFullName] = useState('')
  const [phone, setPhone] = useState('')
  const [creating, setCreating] = useState(false)

  async function load() {
    setLoading(true)
    const { data } = await supabase
      .from('tutors')
      .select('id, full_name, status, education, bank_name, invite_expires_at')
      .order('created_at', { ascending: false })
    setRows((data as TutorRow[]) ?? [])
    setLoading(false)
  }

  useEffect(() => {
    load()
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
        : `Email belum dikonfigurasi. Kirim tautan ini ke tutor:\n${data?.activation_link}`,
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

  return (
    <section>
      <h1>Tutor &amp; Undangan</h1>
      <p className="muted">Buat akun tutor, kirim ulang undangan, suspend/reaktivasi.</p>

      <form className="tutor-form" onSubmit={onCreate}>
        <input placeholder="Nama lengkap" value={fullName} onChange={(e) => setFullName(e.target.value)} required />
        <input type="email" placeholder="Email" value={email} onChange={(e) => setEmail(e.target.value)} required />
        <input placeholder="No. HP (opsional)" value={phone} onChange={(e) => setPhone(e.target.value)} />
        <button type="submit" disabled={creating}>
          {creating ? 'Memproses…' : 'Undang tutor'}
        </button>
      </form>

      {notice && <pre className="notice-line">{notice}</pre>}

      {loading ? (
        <p className="muted">Memuat…</p>
      ) : rows.length === 0 ? (
        <p className="muted">Belum ada tutor.</p>
      ) : (
        <table className="table">
          <thead>
            <tr>
              <th>Nama</th>
              <th>Status</th>
              <th>Pendidikan</th>
              <th>Bank</th>
              <th>Aksi</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((t) => (
              <tr key={t.id}>
                <td>{t.full_name}</td>
                <td>
                  <span className={`status status-${t.status}`}>{STATUS_LABEL[t.status]}</span>
                </td>
                <td>{t.education ?? '—'}</td>
                <td>{t.bank_name ?? '—'}</td>
                <td className="actions">
                  {t.status === 'diundang' && (
                    <button disabled={busyId === t.id} onClick={() => onAction(t.id, 'resend_invite')}>
                      Kirim ulang
                    </button>
                  )}
                  {t.status === 'aktif' && (
                    <button disabled={busyId === t.id} onClick={() => onAction(t.id, 'suspend')}>
                      Suspend
                    </button>
                  )}
                  {t.status === 'suspend' && (
                    <button disabled={busyId === t.id} onClick={() => onAction(t.id, 'reactivate')}>
                      Reaktivasi
                    </button>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </section>
  )
}
