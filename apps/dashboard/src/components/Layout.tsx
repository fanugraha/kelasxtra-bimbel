import { NavLink, Outlet } from 'react-router-dom'
import { modules } from '../modules/registry'
import { useAuth } from '../lib/auth'

export function Layout() {
  const { session, signOut } = useAuth()

  return (
    <div className="layout">
      <aside className="sidebar">
        <div className="brand">Kelasxtra</div>
        <nav>
          <NavLink to="/" end>
            Ringkasan
          </NavLink>
          {modules.map((m) => (
            <NavLink key={m.path} to={`/${m.path}`}>
              {m.label}
            </NavLink>
          ))}
        </nav>
      </aside>
      <main className="content">
        <header className="topbar">
          <span>{session?.user.email}</span>
          <button onClick={signOut}>Keluar</button>
        </header>
        <div className="page">
          <Outlet />
        </div>
      </main>
    </div>
  )
}
