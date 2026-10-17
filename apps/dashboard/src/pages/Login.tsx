import { useState } from 'react'
import type { FormEvent } from 'react'
import { useAuth } from '../lib/auth-context'

export function Login() {
  const { signIn } = useAuth()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)

  async function onSubmit(e: FormEvent) {
    e.preventDefault()
    setLoading(true)
    setError(null)
    const err = await signIn(email.trim(), password)
    setError(err)
    setLoading(false)
  }

  return (
    <div className="login">
      <form onSubmit={onSubmit}>
        <div className="brand" style={{ padding: 0, marginBottom: 8 }}>
          <div className="brand-mark" aria-hidden="true">k</div>
          <div>
            <div className="brand-name">kelasxtra</div>
            <div className="brand-sub">Panel admin</div>
          </div>
        </div>
        <h1 style={{ fontFamily: 'var(--font-display)', fontSize: 26, letterSpacing: '-0.03em' }}>
          Masuk
        </h1>
        <p className="muted" style={{ marginTop: -6 }}>Gunakan akun admin Kelasxtra.</p>
        <label>
          Email
          <input
            type="email"
            autoComplete="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
          />
        </label>
        <label>
          Kata sandi
          <input
            type="password"
            autoComplete="current-password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
          />
        </label>
        {error && <p className="error">{error}</p>}
        <button type="submit" disabled={loading}>
          {loading ? 'Memproses…' : 'Masuk'}
        </button>
      </form>
    </div>
  )
}
