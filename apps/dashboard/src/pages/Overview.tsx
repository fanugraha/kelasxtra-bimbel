import { modules } from '../modules/registry'

export function Overview() {
  return (
    <section>
      <h1>Ringkasan</h1>
      <p className="muted">
        Dashboard admin Kelasxtra Bimbel. Halaman ini fondasi Fase 0 (auth + RLS).
        Modul operasional menyusul per fase.
      </p>
      <div className="cards">
        {modules.map((m) => (
          <div key={m.path} className="card">
            <h3>{m.label}</h3>
            <p className="muted">{m.desc}</p>
            <span className="badge">{m.phase}</span>
          </div>
        ))}
      </div>
    </section>
  )
}
