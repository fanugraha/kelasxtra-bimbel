import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom'
import { AuthProvider, useAuth } from './lib/auth'
import { isSupabaseConfigured } from './lib/supabase'
import { Layout } from './components/Layout'
import { Login } from './pages/Login'
import { Overview } from './pages/Overview'
import { ModulePlaceholder } from './components/ModulePlaceholder'
import { Tutors } from './pages/Tutors'
import { Activate } from './pages/Activate'
import { Pricing } from './pages/Pricing'
import { Vouchers } from './pages/Vouchers'
import { modules } from './modules/registry'

function ConfigWarning() {
  return (
    <div className="login">
      <div className="notice">
        <h1>Konfigurasi belum lengkap</h1>
        <p>Salin <code>.env.example</code> menjadi <code>.env</code> dan isi
          <code> VITE_SUPABASE_URL</code> serta <code>VITE_SUPABASE_ANON_KEY</code>.</p>
      </div>
    </div>
  )
}

function Shell() {
  const { session, loading } = useAuth()
  if (loading) return <div className="login">Memuat…</div>
  return (
    <Routes>
      <Route path="/login" element={session ? <Navigate to="/" replace /> : <Login />} />
      <Route path="/activate" element={<Activate />} />
      <Route element={session ? <Layout /> : <Navigate to="/login" replace />}>
        <Route index element={<Overview />} />
        {modules.map((m) => (
          <Route
            key={m.path}
            path={m.path}
            element={
              m.path === 'tutors' ? <Tutors />
              : m.path === 'pricing' ? <Pricing />
              : m.path === 'vouchers' ? <Vouchers />
              : <ModulePlaceholder module={m} />
            }
          />
        ))}
      </Route>
    </Routes>
  )
}

export default function App() {
  if (!isSupabaseConfigured) return <ConfigWarning />
  return (
    <AuthProvider>
      <BrowserRouter>
        <Shell />
      </BrowserRouter>
    </AuthProvider>
  )
}
