import { useEffect, useState } from 'react'
import type { FormEvent } from 'react'
import { supabase } from '../lib/supabase'

interface Room {
  id: string
  name: string
  address: string | null
  active: boolean
  lat: number | null
  lng: number | null
}

const emptyForm = { name: '', address: '', lat: '', lng: '' }

export function Rooms() {
  const [rows, setRows] = useState<Room[]>([])
  const [loading, setLoading] = useState(true)
  const [form, setForm] = useState(emptyForm)
  const [busy, setBusy] = useState(false)
  const [notice, setNotice] = useState<string | null>(null)

  async function load() {
    const { data } = await supabase
      .from('rooms')
      .select('id, name, address, active')
      .order('name')
    setRows((data as Room[]) ?? [])
    setLoading(false)
  }

  useEffect(() => {
    queueMicrotask(load)
  }, [])

  async function onCreate(e: FormEvent) {
    e.preventDefault()
    setBusy(true)
    setNotice(null)
    const { error } = await supabase.from('rooms').insert({
      name: form.name.trim(),
      address: form.address.trim() || null,
      lat: form.lat.trim() ? Number(form.lat) : null,
      lng: form.lng.trim() ? Number(form.lng) : null,
    })
    setBusy(false)
    if (error) {
      setNotice(`Gagal: ${error.message}`)
      return
    }
    setForm(emptyForm)
    load()
  }

  async function toggleActive(r: Room) {
    await supabase.from('rooms').update({ active: !r.active }).eq('id', r.id)
    load()
  }

  async function editCoords(r: Room) {
    const lat = prompt('Latitude ruangan (contoh -7.7956):', String(r.lat ?? ''))
    if (lat === null) return
    const lng = prompt('Longitude ruangan (contoh 110.3695):', String(r.lng ?? ''))
    if (lng === null) return
    const { error } = await supabase
      .from('rooms')
      .update({
        lat: lat.trim() ? Number(lat) : null,
        lng: lng.trim() ? Number(lng) : null,
      })
      .eq('id', r.id)
    if (error) setNotice(`Gagal: ${error.message}`)
    load()
  }

  return (
    <section>
      <h1>Ruangan</h1>
      <p className="muted">
        Ruangan offline (minggu ini fokus Jogja). Dipakai saat membuat program kelas grup;
        sistem menolak jadwal yang bertabrakan di ruangan sama.
      </p>

      <form className="tutor-form" onSubmit={onCreate}>
        <input
          placeholder="Nama ruangan"
          value={form.name}
          onChange={(e) => setForm({ ...form, name: e.target.value })}
          required
        />
        <input
          placeholder="Alamat (opsional)"
          value={form.address}
          onChange={(e) => setForm({ ...form, address: e.target.value })}
        />
        <input
          type="number"
          step="any"
          placeholder="Latitude (opsional)"
          value={form.lat}
          onChange={(e) => setForm({ ...form, lat: e.target.value })}
        />
        <input
          type="number"
          step="any"
          placeholder="Longitude (opsional)"
          value={form.lng}
          onChange={(e) => setForm({ ...form, lng: e.target.value })}
        />
        <button type="submit" disabled={busy}>
          {busy ? 'Menyimpan…' : 'Tambah ruangan'}
        </button>
      </form>

      {notice && <pre className="notice-line">{notice}</pre>}

      {loading ? (
        <p className="muted">Memuat…</p>
      ) : rows.length === 0 ? (
        <p className="muted">Belum ada ruangan.</p>
      ) : (
        <table className="table">
          <thead>
            <tr>
              <th>Nama</th>
              <th>Alamat</th>
              <th>Koordinat</th>
              <th>Status</th>
              <th>Aksi</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((r) => (
              <tr key={r.id}>
                <td>{r.name}</td>
                <td className="muted">{r.address ?? '—'}</td>
                <td className="muted">
                  {r.lat != null && r.lng != null
                    ? `${r.lat}, ${r.lng}`
                    : '—'}{' '}
                  <button onClick={() => editCoords(r)}>Ubah</button>
                </td>
                <td>
                  <span className={`status status-${r.active ? 'aktif' : 'suspend'}`}>
                    {r.active ? 'Aktif' : 'Nonaktif'}
                  </span>
                </td>
                <td className="actions">
                  <button onClick={() => toggleActive(r)}>
                    {r.active ? 'Nonaktifkan' : 'Aktifkan'}
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </section>
  )
}
