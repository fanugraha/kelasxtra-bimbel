import { useEffect, useMemo, useState } from 'react'
import { formatDate, rupiah } from '../lib/format'
import { supabase } from '../lib/supabase'

interface PackagePriceRow {
  id: string
  jenjang: string
  duration_minutes: number
  mode: string
  total_sesi: number
  price: number
  active: boolean
  effective_from: string
}

interface SessionPriceRow {
  jenjang: string
  duration_minutes: number
  mode: string
  price: number
}

const JENJANG = ['SD', 'SMP', 'SMA']
const DURATIONS = [60, 90, 120]
const MODES = ['online', 'offline']
const SIZES = [4, 8, 12]

const sizeLabel = (size: number) =>
  `${size} pertemuan · ${size === 4 ? '1 bulan' : size === 8 ? '2 bulan' : '3 bulan'}`

export function PackagePricing() {
  const [rows, setRows] = useState<PackagePriceRow[]>([])
  const [sessionPrices, setSessionPrices] = useState<SessionPriceRow[]>([])
  const [loading, setLoading] = useState(true)
  const [size, setSize] = useState(4)
  const [draft, setDraft] = useState<Record<string, string>>({})
  const [busy, setBusy] = useState(false)
  const [notice, setNotice] = useState<string | null>(null)

  async function load() {
    const [packages, sessions] = await Promise.all([
      supabase
        .from('package_prices')
        .select('id, jenjang, duration_minutes, mode, total_sesi, price, active, effective_from')
        .order('effective_from', { ascending: false }),
      supabase
        .from('price_matrix')
        .select('jenjang, duration_minutes, mode, price')
        .eq('type', 'privat')
        .eq('active', true),
    ])
    setRows((packages.data as PackagePriceRow[]) ?? [])
    setSessionPrices((sessions.data as SessionPriceRow[]) ?? [])
    setLoading(false)
  }

  useEffect(() => {
    queueMicrotask(load)
  }, [])

  const activeRows = useMemo(
    () => rows.filter((r) => r.active && r.total_sesi === size),
    [rows, size],
  )
  const byKey = useMemo(() => {
    const map = new Map<string, PackagePriceRow>()
    activeRows.forEach((r) => map.set(`${r.jenjang}-${r.duration_minutes}-${r.mode}`, r))
    return map
  }, [activeRows])

  // Batas bawah sehat: bagian tutor (75% harga sesi normal) untuk seluruh pertemuan.
  const minPrice = (jenjang: string, duration: number, mode: string) => {
    const session = sessionPrices.find(
      (p) =>
        p.jenjang === jenjang && p.duration_minutes === duration && p.mode === mode,
    )
    if (!session) return null
    return Math.floor((session.price * 75) / 100) * size
  }

  const changes = rows.filter(
    (r) =>
      r.active &&
      r.total_sesi === size &&
      draft[r.id] !== undefined &&
      Number(draft[r.id]) !== r.price,
  )
  const risky = activeRows.filter((r) => {
    const value = draft[r.id] !== undefined ? Number(draft[r.id]) : r.price
    const min = minPrice(r.jenjang, r.duration_minutes, r.mode)
    return min !== null && value < min
  })
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
        `Simpan ${changes.length} harga paket?\n` +
          'Harga lama disimpan sebagai riwayat. Pembelian lama tidak berubah.',
      )
    )
      return
    setBusy(true)
    setNotice(null)
    for (const row of changes) {
      const { error } = await supabase.rpc('set_package_price', {
        p_jenjang: row.jenjang,
        p_duration_minutes: row.duration_minutes,
        p_mode: row.mode,
        p_total_sesi: row.total_sesi,
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
    setNotice(`${changes.length} harga paket disimpan.`)
    load()
  }

  return (
    <section>
      <div className="page-head">
        <div>
          <p className="eyebrow">Bisnis · Harga paket</p>
          <h1 className="page-title">Harga paket belajar</h1>
          <p className="page-sub">
            Siswa hanya bisa membeli paket (pertemuan mingguan). Harga di sini
            ditetapkan langsung — bukan hitungan diskon otomatis.
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
          <div className="segmented" role="group" aria-label="Jumlah pertemuan">
            {SIZES.map((s) => (
              <button key={s} aria-pressed={size === s} onClick={() => setSize(s)}>
                {sizeLabel(s)}
              </button>
            ))}
          </div>
          <div className="spacer" />
          <span className="sub" style={{ fontSize: 11, color: 'var(--muted)' }}>
            Harga dalam rupiah · WIB
          </span>
        </div>
        <div className="card-body" style={{ paddingTop: 6 }}>
          {loading ? (
            <div className="empty-state">
              <strong>Memuat harga paket…</strong>
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
                          const min = minPrice(jenjang, duration, mode)
                          if (!row) {
                            return (
                              <td key={`${jenjang}-${duration}-${mode}`}>
                                <span className="muted">—</span>
                              </td>
                            )
                          }
                          const value = draft[row.id] !== undefined ? Number(draft[row.id]) : row.price
                          const below = min !== null && value < min
                          return (
                            <td key={row.id}>
                              <input
                                className="input price-input"
                                type="number"
                                min={0}
                                aria-label={`Harga paket ${jenjang} ${duration} menit ${mode}`}
                                value={draft[row.id] ?? row.price}
                                onChange={(e) =>
                                  setDraft((current) => ({ ...current, [row.id]: e.target.value }))
                                }
                              />
                              {row.price > 0 && (
                                <div style={{ fontSize: 10.5, color: 'var(--muted)', marginTop: 3 }}>
                                  ≈ {rupiah(Math.round(value / size))}/pertemuan
                                </div>
                              )}
                              {below && min !== null && (
                                <div style={{ fontSize: 10.5, color: 'var(--danger, #dc2626)', marginTop: 2 }}>
                                  di bawah bagian tutor ({rupiah(min)})
                                </div>
                              )}
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
                Setiap paket sudah termasuk masa berlaku {size === 4 ? '1 bulan' : size === 8 ? '2 bulan' : '3 bulan'}.
                Siswa memilih hari &amp; jam saat membeli; sistem membuat semua pertemuan mingguan.
              </span>
            </div>
            <div className="note warn">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
                <path d="M12 3 2.5 20h19L12 3Z" />
                <path d="M12 9v4.5M12 17h.01" />
              </svg>
              <span>
                Tutor selalu menerima 75% harga sesi normal per pertemuan. Bila harga paket di bawah
                bagian tutor, sisa biaya ditanggung platform{risky.length > 0 ? ` — saat ini ${risky.length} harga berisiko.` : '.'}
              </span>
            </div>
          </div>
        </div>
      </div>

      <div className="card" style={{ marginTop: 14 }}>
        <div className="card-head">
          <div>
            <h2 className="card-title">Riwayat perubahan</h2>
            <p className="card-sub">{history.length} harga paket lama tersimpan</p>
          </div>
        </div>
        <div className="table-wrap" style={{ marginTop: 12 }}>
          <table className="data-table">
            <thead>
              <tr>
                <th>Berlaku sejak</th>
                <th>Kombinasi</th>
                <th className="num">Harga lama</th>
              </tr>
            </thead>
            <tbody>
              {history.map((row) => (
                <tr key={row.id}>
                  <td className="num">{formatDate(row.effective_from)}</td>
                  <td>
                    {row.jenjang} · {row.duration_minutes} menit ·{' '}
                    {row.mode === 'online' ? 'Online' : 'Offline'} · {row.total_sesi} pertemuan
                  </td>
                  <td className="num">{rupiah(row.price)}</td>
                </tr>
              ))}
              {history.length === 0 && (
                <tr>
                  <td colSpan={3}>
                    <div className="empty-state">
                      <strong>Belum ada riwayat</strong>
                      <span>Riwayat muncul setelah harga paket pertama kali diubah.</span>
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
