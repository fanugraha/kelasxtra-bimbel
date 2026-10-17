import { useEffect, useMemo, useState } from 'react'
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
const JENJANG = ['SD', 'SMP', 'SMA']
const DURATIONS = [60, 90, 120]
const MODES = ['online', 'offline']

const tanggal = (value: string) =>
  new Intl.DateTimeFormat('id-ID', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    timeZone: 'Asia/Jakarta',
  }).format(new Date(value))

export function Pricing() {
  const [rows, setRows] = useState<PriceRow[]>([])
  const [loading, setLoading] = useState(true)
  const [tab, setTab] = useState<'privat' | 'grup'>('privat')
  const [draft, setDraft] = useState<Record<string, string>>({})
  const [busy, setBusy] = useState(false)
  const [notice, setNotice] = useState<string | null>(null)

  async function load() {
    const { data } = await supabase
      .from('price_matrix')
      .select('id, jenjang, duration_minutes, mode, type, price, active, effective_from')
      .order('effective_from', { ascending: false })
    setRows((data as PriceRow[]) ?? [])
    setLoading(false)
  }

  useEffect(() => {
    queueMicrotask(load)
  }, [])

  const activeRows = useMemo(() => rows.filter((r) => r.active && r.type === tab), [rows, tab])
  const byKey = useMemo(() => {
    const map = new Map<string, PriceRow>()
    activeRows.forEach((r) => map.set(`${r.jenjang}-${r.duration_minutes}-${r.mode}`, r))
    return map
  }, [activeRows])

  const changes = rows.filter(
    (r) => r.active && draft[r.id] !== undefined && Number(draft[r.id]) !== r.price,
  )
  const history = rows.filter((r) => !r.active).slice(0, 8)

  async function onSave() {
    if (changes.length === 0) return
    for (const row of changes) {
      const value = Number(draft[row.id])
      if (!Number.isInteger(value) || value < 0) {
        setNotice('Harga harus angka bulat ≥ 0.')
        return
      }
    }
    if (
      !confirm(
        `Simpan ${changes.length} perubahan harga?\n` +
          'Harga lama disimpan sebagai riwayat. Transaksi lama tidak berubah.',
      )
    )
      return
    setBusy(true)
    setNotice(null)
    for (const row of changes) {
      const { error } = await supabase.rpc('set_price', {
        p_jenjang: row.jenjang,
        p_duration_minutes: row.duration_minutes,
        p_mode: row.mode,
        p_type: row.type,
        p_price: Number(draft[row.id]),
      })
      if (error) {
        setBusy(false)
        setNotice(`Gagal menyimpan ${row.jenjang} ${row.duration_minutes} menit: ${error.message}`)
        load()
        return
      }
    }
    setBusy(false)
    setDraft({})
    setNotice(`${changes.length} harga disimpan. Riwayat mencatat harga lama dan baru.`)
    load()
  }

  return (
    <section>
      <div className="page-head">
        <div>
          <p className="eyebrow">Bisnis · Daftar harga</p>
          <h1 className="page-title">Daftar harga</h1>
          <p className="page-sub">
            Harga akhir dihitung otomatis oleh sistem. Perubahan hanya berlaku untuk transaksi baru dan tersimpan di riwayat.
          </p>
        </div>
        <div className="head-actions">
          <button className="btn btn-primary" disabled={busy || changes.length === 0} onClick={onSave}>
            {busy ? 'Menyimpan…' : changes.length > 0 ? `Simpan ${changes.length} perubahan` : 'Simpan perubahan'}
          </button>
        </div>
      </div>

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
        <div className="toolbar">
          <div className="segmented" role="group" aria-label="Tipe sesi">
            <button aria-pressed={tab === 'privat'} onClick={() => setTab('privat')}>
              Privat
            </button>
            <button aria-pressed={tab === 'grup'} onClick={() => setTab('grup')}>
              Kelas grup
            </button>
          </div>
          <div className="spacer" />
          <span className="sub" style={{ fontSize: 11, color: 'var(--muted)' }}>
            Harga dalam rupiah · WIB
          </span>
        </div>
        <div className="card-body" style={{ paddingTop: 6 }}>
          {loading ? (
            <div className="empty-state">
              <strong>Memuat harga…</strong>
            </div>
          ) : (
            <div className="matrix-wrap">
              <table className="matrix">
                <thead>
                  <tr>
                    <th>Jenjang</th>
                    {DURATIONS.map((duration) =>
                      MODES.map((mode) => (
                        <th key={`${duration}-${mode}`}>
                          {duration} menit
                          <br />
                          {mode === 'online' ? 'Online' : 'Offline'}
                        </th>
                      )),
                    )}
                  </tr>
                </thead>
                <tbody>
                  {JENJANG.map((jenjang) => (
                    <tr key={jenjang}>
                      <td>
                        <strong>{jenjang}</strong>
                      </td>
                      {DURATIONS.map((duration) =>
                        MODES.map((mode) => {
                          const row = byKey.get(`${jenjang}-${duration}-${mode}`)
                          if (!row) {
                            return (
                              <td key={`${jenjang}-${duration}-${mode}`}>
                                <span className="muted">—</span>
                              </td>
                            )
                          }
                          return (
                            <td key={row.id}>
                              <input
                                className="input price-input"
                                type="number"
                                min={0}
                                aria-label={`Harga ${jenjang} ${duration} menit ${mode}`}
                                value={draft[row.id] ?? row.price}
                                onChange={(e) =>
                                  setDraft((current) => ({ ...current, [row.id]: e.target.value }))
                                }
                              />
                            </td>
                          )
                        }),
                      )}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
          <div className="grid-2" style={{ marginTop: 16 }}>
            <div className="note">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
                <circle cx="12" cy="12" r="9" />
                <path d="M12 11v5M12 8h.01" />
              </svg>
              <span>
                Kombinasi tanpa harga tampil sebagai “—”. Siswa melihat tombol nonaktif dengan pesan “Harga belum tersedia, hubungi admin.”
              </span>
            </div>
            <div className="note warn">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
                <path d="M12 3 2.5 20h19L12 3Z" />
                <path d="M12 9v4.5M12 17h.01" />
              </svg>
              <span>Menyimpan harga membuka konfirmasi. Riwayat mencatat harga lama → baru, pelaku, dan waktu.</span>
            </div>
          </div>
        </div>
      </div>

      <div className="card" style={{ marginTop: 14 }}>
        <div className="card-head">
          <div>
            <h2 className="card-title">Riwayat perubahan</h2>
            <p className="card-sub">{history.length} harga lama tersimpan</p>
          </div>
        </div>
        <div className="table-wrap" style={{ marginTop: 12 }}>
          <table className="data-table">
            <thead>
              <tr>
                <th>Berlaku sejak</th>
                <th>Kombinasi</th>
                <th>Tipe</th>
                <th className="num">Harga lama</th>
              </tr>
            </thead>
            <tbody>
              {history.map((row) => (
                <tr key={row.id}>
                  <td className="num">{tanggal(row.effective_from)}</td>
                  <td>
                    {row.jenjang} · {row.duration_minutes} menit · {row.mode === 'online' ? 'Online' : 'Offline'}
                  </td>
                  <td>{row.type === 'privat' ? 'Privat' : 'Kelas grup'}</td>
                  <td className="num">{rupiah(row.price)}</td>
                </tr>
              ))}
              {history.length === 0 && (
                <tr>
                  <td colSpan={4}>
                    <div className="empty-state">
                      <strong>Belum ada riwayat</strong>
                      <span>Riwayat muncul setelah harga pertama kali diubah.</span>
                    </div>
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    </section>
  )
}
