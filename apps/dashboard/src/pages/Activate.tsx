import { useState } from 'react'
import type { FormEvent } from 'react'
import { useSearchParams } from 'react-router-dom'
import { supabase } from '../lib/supabase'

export function Activate() {
  const [params] = useSearchParams()
  const token = params.get('token') ?? ''

  const [password, setPassword] = useState('')
  const [confirm, setConfirm] = useState('')
  const [education, setEducation] = useState('')
  const [bio, setBio] = useState('')
  const [bankName, setBankName] = useState('')
  const [bankNumber, setBankNumber] = useState('')
  const [bankHolder, setBankHolder] = useState('')
  const [loading, setLoading] = useState(false)
  const [done, setDone] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function onSubmit(e: FormEvent) {
    e.preventDefault()
    if (password.length < 6) return setError('Kata sandi minimal 6 karakter.')
    if (password !== confirm) return setError('Kata sandi tidak sama.')
    setLoading(true)
    setError(null)
    const { data, error: fnErr } = await supabase.functions.invoke('activate-tutor', {
      body: {
        token,
        password,
        education,
        bio,
        bank_name: bankName,
        bank_account_number: bankNumber,
        bank_account_holder: bankHolder,
      },
    })
    setLoading(false)
    if (fnErr) {
      const detail = await (fnErr as { context?: Response }).context?.json?.().catch(() => null)
      setError(detail?.error ?? fnErr.message)
      return
    }
    if (data?.error) return setError(data.error)
    setDone(true)
  }

  if (!token) {
    return (
      <div className="login">
        <div className="notice">
          <h1>Tautan tidak valid</h1>
          <p>Tautan undangan tidak memuat token. Minta tautan baru ke admin.</p>
        </div>
      </div>
    )
  }

  if (done) {
    return (
      <div className="login">
        <div className="notice">
          <h1>Akun tutor aktif</h1>
          <p>Kata sandi tersimpan. Silakan masuk lewat aplikasi tutor memakai email undanganmu.</p>
        </div>
      </div>
    )
  }

  return (
    <div className="login">
      <form onSubmit={onSubmit}>
        <h1>Aktivasi Tutor</h1>
        <label>
          Kata sandi (min 6)
          <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} required />
        </label>
        <label>
          Ulangi kata sandi
          <input type="password" value={confirm} onChange={(e) => setConfirm(e.target.value)} required />
        </label>
        <label>
          Pendidikan
          <input value={education} onChange={(e) => setEducation(e.target.value)} />
        </label>
        <label>
          Bio singkat
          <textarea value={bio} onChange={(e) => setBio(e.target.value)} rows={3} />
        </label>
        <label>
          Nama bank
          <input value={bankName} onChange={(e) => setBankName(e.target.value)} />
        </label>
        <label>
          Nomor rekening
          <input value={bankNumber} onChange={(e) => setBankNumber(e.target.value)} />
        </label>
        <label>
          Nama pemilik rekening
          <input value={bankHolder} onChange={(e) => setBankHolder(e.target.value)} />
        </label>
        {error && <p className="error">{error}</p>}
        <button type="submit" disabled={loading}>
          {loading ? 'Memproses…' : 'Aktifkan akun'}
        </button>
      </form>
    </div>
  )
}
