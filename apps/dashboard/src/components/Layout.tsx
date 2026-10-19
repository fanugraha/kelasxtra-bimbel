import type { ReactNode } from 'react'
import { useEffect, useState } from 'react'
import { NavLink, Outlet, useLocation } from 'react-router-dom'
import { groupLabels, modules } from '../modules/registry'
import type { ModuleGroup } from '../modules/registry'
import { useAuth } from '../lib/auth-context'
import { initials } from '../lib/text'

const icons: Record<string, ReactNode> = {
  overview: (
    <>
      <rect x="3" y="3" width="7" height="7" rx="1.5" />
      <rect x="14" y="3" width="7" height="7" rx="1.5" />
      <rect x="3" y="14" width="7" height="7" rx="1.5" />
      <rect x="14" y="14" width="7" height="7" rx="1.5" />
    </>
  ),
  monitoring: <path d="M3 12h4l2.5-6 4 12 2.5-6h5" />,
  tutors: (
    <>
      <circle cx="9" cy="8" r="3.1" />
      <path d="M3.5 19c.6-3 2.7-4.6 5.5-4.6s4.9 1.6 5.5 4.6" />
      <path d="M16 5.6a3 3 0 0 1 0 5.6M17.4 14.9c1.8.6 2.9 2 3.2 4.1" />
    </>
  ),
  'group-classes': (
    <>
      <circle cx="8" cy="9" r="2.7" />
      <circle cx="16" cy="9" r="2.7" />
      <path d="M2.8 19c.4-2.7 2.3-4.2 5.2-4.2s4.8 1.5 5.2 4.2M13.4 19c.4-2.2 1.9-3.5 4.1-3.5 1 0 1.9.2 2.6.7" />
    </>
  ),
  rooms: (
    <>
      <path d="M4 21V5.5A1.5 1.5 0 0 1 5.5 4h9A1.5 1.5 0 0 1 16 5.5V21" />
      <path d="M16 10h3.5A1.5 1.5 0 0 1 21 11.5V21M2 21h20M8 8h4M8 12h4M8 16h4" />
    </>
  ),
  payroll: (
    <>
      <rect x="3" y="5" width="18" height="14" rx="2.5" />
      <path d="M3 10h18M7 15h4" />
    </>
  ),
  finance: <path d="M4 20V10M10 20V4M16 20v-7M22 20H2" />,
  packages: (
    <>
      <path d="M12 3 3 7.5 12 12l9-4.5L12 3Z" />
      <path d="m3 12.5 9 4.5 9-4.5M3 17.5 12 22l9-4.5" />
    </>
  ),
  pricing: (
    <>
      <path d="M20.5 13.5 13.5 20.5a2 2 0 0 1-2.8 0L3.5 13.3V4.5a1 1 0 0 1 1-1h8.8l7.2 7.2a2 2 0 0 1 0 2.8Z" />
      <circle cx="8" cy="8" r="1.3" />
    </>
  ),
  vouchers: (
    <>
      <path d="M3 9V6.5A1.5 1.5 0 0 1 4.5 5h15A1.5 1.5 0 0 1 21 6.5V9a3 3 0 0 0 0 6v2.5a1.5 1.5 0 0 1-1.5 1.5h-15A1.5 1.5 0 0 1 3 17.5V15a3 3 0 0 0 0-6Z" />
      <path d="M14 5v14" strokeDasharray="2 2.5" />
    </>
  ),
  moderation: (
    <>
      <path d="M12 3.2 5 6v6c0 4.2 2.9 7.4 7 8.8 4.1-1.4 7-4.6 7-8.8V6l-7-2.8Z" />
      <path d="M12 9v4M12 15.6h.01" />
    </>
  ),
  disputes: (
    <>
      <path d="M21 12a8.5 8.5 0 0 1-8.5 8.5H4l2-3.2A8.5 8.5 0 1 1 21 12Z" />
      <path d="M12 8v4.5M12 16h.01" />
    </>
  ),
  'question-cms': (
    <>
      <path d="M7 3h7l4 4v14H7a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2Z" />
      <path d="M14 3v5h4M9 13h6M9 17h4" />
    </>
  ),
  'audit-log': (
    <>
      <circle cx="12" cy="12" r="8.5" />
      <path d="M12 7.5V12l3 2" />
    </>
  ),
}

function NavIcon({ name }: { name: string }) {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" aria-hidden="true">
      {icons[name]}
    </svg>
  )
}

const groups: ModuleGroup[] = ['operasional', 'bisnis', 'layanan']

export function Layout() {
  const { session, signOut } = useAuth()
  const location = useLocation()
  const [open, setOpen] = useState(false)
  const [dark, setDark] = useState(
    () => document.documentElement.getAttribute('data-theme') === 'dark',
  )

  useEffect(() => setOpen(false), [location.pathname])

  useEffect(() => {
    if (dark) document.documentElement.setAttribute('data-theme', 'dark')
    else document.documentElement.removeAttribute('data-theme')
    try {
      localStorage.setItem('kx-admin-theme', dark ? 'dark' : 'light')
    } catch {
      /* storage bisa diblokir */
    }
  }, [dark])

  const email = session?.user.email ?? ''
  const name = (session?.user.user_metadata?.full_name as string | undefined) ?? email
  const current =
    location.pathname === '/' ? 'Ringkasan' : modules.find((m) => location.pathname.startsWith(`/${m.path}`))?.label ?? 'Ringkasan'

  const date = new Intl.DateTimeFormat('id-ID', {
    weekday: 'short',
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    timeZone: 'Asia/Jakarta',
  })
    .format(new Date())
    .toUpperCase()

  return (
    <div className="app">
      <aside className={`sidebar${open ? ' open' : ''}`} aria-label="Navigasi admin">
        <NavLink to="/" className="brand">
          <div className="brand-mark" aria-hidden="true">
            k
          </div>
          <div>
            <div className="brand-name">kelasxtra</div>
            <div className="brand-sub">Panel admin</div>
          </div>
        </NavLink>

        <div className="nav-scroll">
          {groups.map((group) => (
            <div className="nav-group" key={group}>
              <p className="nav-label">{groupLabels[group]}</p>
              {group === 'operasional' && (
                <NavLink to="/" end className="nav-link">
                  <NavIcon name="overview" />
                  <span className="nav-text">Ringkasan</span>
                </NavLink>
              )}
              {modules
                .filter((m) => m.group === group)
                .map((m) => (
                  <NavLink key={m.path} to={`/${m.path}`} className="nav-link">
                    <NavIcon name={m.path} />
                    <span className="nav-text">{m.label}</span>
                  </NavLink>
                ))}
            </div>
          ))}
        </div>

        <div className="sidebar-foot">
          <div className="admin-card">
            <span className="avatar">{initials(name)}</span>
            <div>
              <div className="admin-name">{name}</div>
              <div className="admin-role">Admin</div>
            </div>
            <button className="logout" aria-label="Keluar" onClick={() => signOut()}>
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7">
                <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9" />
              </svg>
            </button>
          </div>
        </div>
      </aside>
      <button
        className={`scrim${open ? ' show' : ''}`}
        aria-label="Tutup menu"
        tabIndex={-1}
        onClick={() => setOpen(false)}
      />

      <div className="main">
        <header className="topbar">
          <div className="topbar-left">
            <button className="icon-btn menu-btn" aria-label="Buka menu" onClick={() => setOpen(true)}>
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7">
                <path d="M4 7h16M4 12h16M4 17h16" />
              </svg>
            </button>
            <div className="crumb">
              <span>Kelasxtra</span>
              <span className="sep">/</span>
              <b>{current}</b>
            </div>
          </div>
          <div className="topbar-right">
            <span className="topdate">{date} · WIB</span>
            <button
              className="icon-btn theme-btn"
              aria-label={dark ? 'Mode terang' : 'Mode gelap'}
              onClick={() => setDark((value) => !value)}
            >
              <svg className="icon-moon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7">
                <path d="M20.5 14.8A8.6 8.6 0 1 1 9.2 3.5a6.9 6.9 0 0 0 11.3 11.3Z" />
              </svg>
              <svg className="icon-sun" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7">
                <circle cx="12" cy="12" r="4" />
                <path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4" />
              </svg>
            </button>
            <span className="avatar" aria-label={name}>
              {initials(name)}
            </span>
          </div>
        </header>

        <main className="page">
          <Outlet />
        </main>
      </div>
    </div>
  )
}
