import { useState } from 'react'
import type { FormEvent } from 'react'
import { useSearchParams } from 'react-router-dom'
import { supabase } from '../lib/supabase'

async function callActivate(body: Record<string, unknown>) {
  const { data, error } = await supabase.functions.invoke('activate-tutor', { body })
  if (error) {
    const detail = await (error as { context?: Response }).context?.json?.().catch(() => null)
    return { data: null, error: detail?.error ?? error.message }
  }
  if (data?.error) return { data: null, error: data.error }
  return { data, error: null }
}

export function Activate() {
  const [params] = useSearchParams()
  const token = params.get('token') ?? ''

  const [otp, setOtp] = useState('')
  const [otpSent, setOtpSent] = useState(false)
  const [emailHint, setEmailHint] = useState<string | null>(null)
  const [sending, setSending] = useState(false)
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

  async function onRequestOtp() {
    setSending(true)
    setError(null)
    const { data, error: fnErr } = await callActivate({ action: 'request_otp', token })
    setSending(false)
    if (fnErr) return setError(fnErr)
    setOtpSent(true)
    setEmailHint((data as { email_hint?: string } | null)?.email_hint ?? null)
    setOtp('')
  }

  async function onSubmit(e: FormEvent) {
    e.preventDefault()
    if (!otpSent) return setError('Minta kode verifikasi terlebih dahulu.')
    if (!/^\d{6}$/.test(otp)) return setError('Kode verifikasi wajib 6 digit.')
    if (password.length < 6) return setError('Kata sandi minimal 6 karakter.')
    if (password !== confirm) return setError('Kata sandi tidak sama.')
    setLoading(true)
    setError(null)
    const { error: fnErr } = await callActivate({
      action: 'activate',
      token,
      otp,
      password,
      education,
      bio,
      bank_name: bankName,
      bank_account_number: bankNumber,
      bank_account_holder: bankHolder,
    })
    setLoading(false)
    if (fnErr) return setError(fnErr)
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
        <p>
          Untuk membuktikan kepemilikan email, minta kode verifikasi. Kode dikirim ke email
          undangan, bukan ke tautan ini.
        </p>
        <button type="button" onClick={onRequestOtp} disabled={sending}>
          {sending ? 'Mengirim…' : otpSent ? 'Kirim ulang kode' : 'Kirim kode verifikasi'}
        </button>
        {otpSent && (
          <p className="hint">
            Kode dikirim ke {emailHint ?? 'email undangan'}. Berlaku 10 menit.
          </p>
        )}
        <label>
          Kode verifikasi (6 digit)
          <input
            inputMode="numeric"
            autoComplete="one-time-code"
            maxLength={6}
            value={otp}
            onChange={(e) => setOtp(e.target.value.replace(/\D/g, ''))}
            required
          />
        </label>
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
        <button type="submit" disabled={loading || !otpSent}>
          {loading ? 'Memproses…' : 'Aktifkan akun'}
        </button>
      </form>
    </div>
  )
}
