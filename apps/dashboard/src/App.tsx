import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom'
import type { ComponentType } from 'react'
import { AuthProvider } from './lib/auth'
import { useAuth } from './lib/auth-context'
import { isSupabaseConfigured } from './lib/supabase'
import { Layout } from './components/Layout'
import { Login } from './pages/Login'
import { Overview } from './pages/Overview'
import { ModulePlaceholder } from './components/ModulePlaceholder'
import { Tutors } from './pages/Tutors'
import { Activate } from './pages/Activate'
import { Pricing } from './pages/Pricing'
import { Vouchers } from './pages/Vouchers'
import { Packages } from './pages/Packages'
import { Rooms } from './pages/Rooms'
import { GroupClasses } from './pages/GroupClasses'
import { QuestionCms } from './pages/QuestionCms'
import { Disputes } from './pages/Disputes'
import { Payroll } from './pages/Payroll'
import { modules } from './modules/registry'
import type { ModuleDef } from './modules/registry'

// Modul yang sudah punya layar; sisanya memakai placeholder.
const modulePages: Record<string, ComponentType> = {
  tutors: Tutors,
  pricing: Pricing,
  vouchers: Vouchers,
  packages: Packages,
  rooms: Rooms,
  'group-classes': GroupClasses,
  'question-cms': QuestionCms,
  disputes: Disputes,
  payroll: Payroll,
}

function ModulePage({ module }: { module: ModuleDef }) {
  const Page = modulePages[module.path]
  return Page ? <Page /> : <ModulePlaceholder module={module} />
}

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
          <Route key={m.path} path={m.path} element={<ModulePage module={m} />} />
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
