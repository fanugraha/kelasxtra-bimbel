import type { ModuleDef } from '../modules/registry'

export function ModulePlaceholder({ module }: { module: ModuleDef }) {
  return (
    <section>
      <h1>{module.label}</h1>
      <p className="muted">{module.desc}</p>
      <p>
        Modul ini dijadwalkan pada <strong>{module.phase}</strong>. Halaman masih
        placeholder — akan diisi pada fase terkait.
      </p>
    </section>
  )
}
