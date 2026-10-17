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
  const [showForm, setShowForm] = useState(false)
  const [busy, setBusy] = useState(false)
  const [notice, setNotice] = useState<string | null>(null)

  async function load() {
    const { data } = await supabase
      .from('rooms')
      .select('id, name, address, active, lat, lng')
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
    setShowForm(false)
    setNotice('Ruangan ditambahkan.')
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
      <div className="page-head">
        <div>
          <p className="eyebrow">Operasional · Ruangan</p>
          <h1 className="page-title">Ruangan</h1>
          <p className="page-sub">
            Titik lokasi dipakai untuk memastikan siswa absen di sekitar tempat les (radius 200 meter). Tanpa titik lokasi, jarak tidak diperiksa.
          </p>
        </div>
        <div className="head-actions">
          <button className="btn btn-primary" onClick={() => setShowForm((value) => !value)}>
            {showForm ? 'Tutup formulir' : 'Tambah ruangan'}
          </button>
        </div>
      </div>

      {showForm && (
        <div className="card" style={{ marginBottom: 14 }}>
          <div className="card-head">
            <div>
              <h2 className="card-title">Ruangan baru</h2>
              <p className="card-sub">Titik lokasi opsional. Isi agar absensi offline diperiksa radiusnya.</p>
            </div>
          </div>
          <form className="card-body" onSubmit={onCreate}>
            <div className="form-grid">
              <label className="field">
                <span>Nama ruangan</span>
                <input
                  className="input"
                  placeholder="Ruang Melati"
                  value={form.name}
                  onChange={(e) => setForm({ ...form, name: e.target.value })}
                  required
                />
              </label>
              <label className="field">
                <span>Alamat</span>
                <input
                  className="input"
                  placeholder="Jl. Kaliurang Km 5, Sleman"
                  value={form.address}
                  onChange={(e) => setForm({ ...form, address: e.target.value })}
                />
              </label>
              <label className="field">
                <span>Latitude</span>
                <input
                  className="input"
                  type="number"
                  step="any"
                  placeholder="-7.7821"
                  value={form.lat}
                  onChange={(e) => setForm({ ...form, lat: e.target.value })}
                />
              </label>
              <label className="field">
                <span>Longitude</span>
                <input
                  className="input"
                  type="number"
                  step="any"
                  placeholder="110.3672"
                  value={form.lng}
                  onChange={(e) => setForm({ ...form, lng: e.target.value })}
                />
              </label>
            </div>
            <div className="head-actions" style={{ marginTop: 14 }}>
              <button className="btn btn-primary" type="submit" disabled={busy}>
                {busy ? 'Menyimpan…' : 'Tambah ruangan'}
              </button>
              <button className="btn btn-secondary" type="button" onClick={() => setShowForm(false)}>
                Batal
              </button>
            </div>
          </form>
        </div>
      )}

      {notice && (
        <div className="note" style={{ marginBottom: 14 }}>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
            <circle cx="12" cy="12" r="9" />
            <path d="M12 11v5M12 8h.01" />
          </svg>
          <span>{notice}</span>
        </div>
      )}

      <div className="card">
        <div className="table-wrap">
          <table className="data-table" style={{ minWidth: 760 }}>
            <thead>
              <tr>
                <th>Ruangan</th>
                <th>Alamat</th>
                <th>Titik lokasi</th>
                <th>Status</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan={5}>
                    <div className="empty-state">
                      <strong>Memuat ruangan…</strong>
                    </div>
                  </td>
                </tr>
              ) : rows.length === 0 ? (
                <tr>
                  <td colSpan={5}>
                    <div className="empty-state">
                      <strong>Belum ada ruangan</strong>
                      <span>Tambahkan ruangan offline lewat tombol di kanan atas.</span>
                    </div>
                  </td>
                </tr>
              ) : (
                rows.map((r) => (
                  <tr key={r.id}>
                    <td>
                      <span className="strong">{r.name}</span>
                    </td>
                    <td>{r.address ?? '—'}</td>
                    <td className="num">
                      {r.lat != null && r.lng != null ? `${r.lat}, ${r.lng}` : '—'}
                    </td>
                    <td>
                      <span className={`badge ${r.active ? 'success' : 'neutral'}`}>
                        {r.active ? 'Aktif' : 'Nonaktif'}
                      </span>
                    </td>
                    <td>
                      <div className="row-actions">
                        <button className="btn btn-secondary btn-sm" onClick={() => editCoords(r)}>
                          Atur lokasi
                        </button>
                        <button className="btn btn-ghost btn-sm" onClick={() => toggleActive(r)}>
                          {r.active ? 'Nonaktifkan' : 'Aktifkan'}
                        </button>
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
        <div className="card-foot">
          <div className="note">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
              <circle cx="12" cy="12" r="9" />
              <path d="M12 11v5M12 8h.01" />
            </svg>
            <span>Ruangan tanpa titik lokasi tetap bisa dipakai, tetapi jarak absen tidak diperiksa.</span>
          </div>
        </div>
      </div>
    </section>
  )
}
