import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'

interface PriceRow {
  id: string
  jenjang: string
  duration_minutes: number
  mode: string
  type: string
  price: number
  active: boolean
  effective_from: string
}

const rupiah = (n: number) => 'Rp' + n.toLocaleString('id-ID')

export function Pricing() {
  const [rows, setRows] = useState<PriceRow[]>([])
  const [loading, setLoading] = useState(true)
  const [showHistory, setShowHistory] = useState(false)
  const [draft, setDraft] = useState<Record<string, string>>({})
  const [busy, setBusy] = useState<string | null>(null)
  const [notice, setNotice] = useState<string | null>(null)

  async function load() {
    const { data } = await supabase
      .from('price_matrix')
      .select('id, jenjang, duration_minutes, mode, type, price, active, effective_from')
      .order('jenjang')
      .order('duration_minutes')
      .order('mode')
      .order('type')
      .order('effective_from', { ascending: false })
    setRows((data as PriceRow[]) ?? [])
    setLoading(false)
  }

  useEffect(() => {
    queueMicrotask(load)
  }, [])

  const active = rows.filter((r) => r.active)
  const shown = showHistory ? rows : active

  async function onSave(r: PriceRow) {
    const value = Number(draft[r.id] ?? r.price)
    if (!Number.isInteger(value) || value < 0) {
      setNotice('Harga harus angka bulat ≥ 0.')
      return
    }
    if (value === r.price) return
    setBusy(r.id)
    setNotice(null)
    const { error } = await supabase.rpc('set_price', {
      p_jenjang: r.jenjang,
      p_duration_minutes: r.duration_minutes,
      p_mode: r.mode,
      p_type: r.type,
      p_price: value,
    })
    setBusy(null)
    if (error) {
      setNotice(`Gagal: ${error.message}`)
      return
    }
    setNotice(`Harga ${r.jenjang} ${r.duration_minutes}mnt ${r.mode} ${r.type} → ${rupiah(value)}`)
    setDraft((d) => ({ ...d, [r.id]: '' }))
    load()
  }

  return (
    <section>
      <h1>Price Matrix</h1>
      <p className="muted">
        Harga per jenjang × durasi × mode × tipe. Ubah harga → versi lama disimpan sebagai riwayat;
        transaksi lama tak berubah (harga di-snapshot saat checkout).
      </p>

      <label className="toggle">
        <input type="checkbox" checked={showHistory} onChange={(e) => setShowHistory(e.target.checked)} />
        Tampilkan riwayat (harga lama)
      </label>

      {notice && <pre className="notice-line">{notice}</pre>}

      {loading ? (
        <p className="muted">Memuat…</p>
      ) : (
        <table className="table">
          <thead>
            <tr>
              <th>Jenjang</th>
              <th>Durasi</th>
              <th>Mode</th>
              <th>Tipe</th>
              <th>Harga (Rp)</th>
              <th>Berlaku dari</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {shown.map((r) => (
              <tr key={r.id} style={r.active ? undefined : { opacity: 0.55 }}>
                <td>{r.jenjang}</td>
                <td>{r.duration_minutes} mnt</td>
                <td>{r.mode}</td>
                <td>{r.type}</td>
                <td>
                  {r.active ? (
                    <input
                      className="price-input"
                      type="number"
                      min={0}
                      value={draft[r.id] ?? r.price}
                      onChange={(e) => setDraft((d) => ({ ...d, [r.id]: e.target.value }))}
                    />
                  ) : (
                    rupiah(r.price)
                  )}
                </td>
                <td className="muted">{new Date(r.effective_from).toLocaleDateString('id-ID')}</td>
                <td>
                  {r.active && (
                    <button disabled={busy === r.id} onClick={() => onSave(r)}>
                      {busy === r.id ? '…' : 'Simpan'}
                    </button>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </section>
  )
}
