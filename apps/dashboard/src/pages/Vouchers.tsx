import { useEffect, useState } from 'react'
import type { FormEvent } from 'react'
import { supabase } from '../lib/supabase'

interface Voucher {
  id: string
  code: string
  discount_type: 'percent' | 'nominal'
  discount_value: number
  min_purchase: number
  quota: number | null
  used: number
  active: boolean
  expires_at: string | null
}

const emptyForm = {
  code: '',
  discount_type: 'percent' as Voucher['discount_type'],
  discount_value: '',
  min_purchase: '0',
  quota: '',
  expires_at: '',
}

interface VoucherReport {
  used: number
  locked: number
  discount: number
}

const rupiah = (n: number) => 'Rp' + n.toLocaleString('id-ID')
const tanggal = (value: string | null) =>
  value
    ? new Intl.DateTimeFormat('id-ID', {
        day: '2-digit',
        month: 'short',
        year: 'numeric',
        timeZone: 'Asia/Jakarta',
      }).format(new Date(value))
    : '—'

export function Vouchers() {
  const [rows, setRows] = useState<Voucher[]>([])
  const [report, setReport] = useState<Record<string, VoucherReport>>({})
  const [loading, setLoading] = useState(true)
  const [form, setForm] = useState(emptyForm)
  const [showForm, setShowForm] = useState(false)
  const [busy, setBusy] = useState(false)
  const [notice, setNotice] = useState<string | null>(null)

  async function load() {
    const { data } = await supabase
      .from('vouchers')
      .select('id, code, discount_type, discount_value, min_purchase, quota, used, active, expires_at')
      .order('created_at', { ascending: false })
    setRows((data as Voucher[]) ?? [])

    const [{ data: redemptions }, { data: usedBookings }] = await Promise.all([
      supabase.from('voucher_redemptions').select('voucher_id, status'),
      supabase.from('bookings_visible').select('voucher_id, discount').not('voucher_id', 'is', null),
    ])
    const map: Record<string, VoucherReport> = {}
    for (const r of (redemptions ?? []) as { voucher_id: string; status: string }[]) {
      const entry = (map[r.voucher_id] ??= { used: 0, locked: 0, discount: 0 })
      if (r.status === 'used') entry.used += 1
      if (r.status === 'locked') entry.locked += 1
    }
    for (const b of (usedBookings ?? []) as { voucher_id: string; discount: number }[]) {
      const entry = (map[b.voucher_id] ??= { used: 0, locked: 0, discount: 0 })
      entry.discount += b.discount ?? 0
    }
    setReport(map)
    setLoading(false)
  }

  useEffect(() => {
    queueMicrotask(load)
  }, [])

  async function onCreate(e: FormEvent) {
    e.preventDefault()
    setBusy(true)
    setNotice(null)
    const { error } = await supabase.from('vouchers').insert({
      code: form.code.trim().toUpperCase(),
      discount_type: form.discount_type,
      discount_value: Number(form.discount_value),
      min_purchase: Number(form.min_purchase || 0),
      quota: form.quota === '' ? null : Number(form.quota),
      expires_at: form.expires_at ? new Date(form.expires_at).toISOString() : null,
    })
    setBusy(false)
    if (error) {
      setNotice(`Gagal: ${error.message}`)
      return
    }
    setForm(emptyForm)
    setShowForm(false)
    setNotice('Voucher dibuat.')
    load()
  }

  async function toggleActive(v: Voucher) {
    await supabase.from('vouchers').update({ active: !v.active }).eq('id', v.id)
    load()
  }

  async function onDelete(v: Voucher) {
    if (!confirm(`Hapus voucher ${v.code}?`)) return
    await supabase.from('vouchers').delete().eq('id', v.id)
    load()
  }

  const label = (v: Voucher) =>
    v.discount_type === 'percent'
      ? `${v.discount_value}%`
      : 'Rp' + v.discount_value.toLocaleString('id-ID')

  const totals = rows.reduce(
    (sum, v) => {
      const r = report[v.id] ?? { used: 0, locked: 0, discount: 0 }
      return {
        used: sum.used + r.used,
        locked: sum.locked + r.locked,
        discount: sum.discount + r.discount,
        quota: sum.quota + (v.quota ?? 0),
      }
    },
    { used: 0, locked: 0, discount: 0, quota: 0 },
  )

  return (
    <section>
      <div className="page-head">
        <div>
          <p className="eyebrow">Bisnis · Voucher &amp; promo</p>
          <h1 className="page-title">Voucher &amp; promo</h1>
          <p className="page-sub">
            Kuota dikunci saat pembayaran dimulai dan dilepas bila pembayaran gagal atau kedaluwarsa.
          </p>
        </div>
        <div className="head-actions">
          <button className="btn btn-primary" onClick={() => setShowForm((value) => !value)}>
            {showForm ? 'Tutup formulir' : 'Buat voucher'}
          </button>
        </div>
      </div>

      {showForm && (
        <div className="card" style={{ marginBottom: 14 }}>
          <div className="card-head">
            <div>
              <h2 className="card-title">Voucher baru</h2>
              <p className="card-sub">Satu voucher per transaksi. Diskon 100% ditanggung platform.</p>
            </div>
          </div>
          <form className="card-body" onSubmit={onCreate}>
            <div className="form-grid">
              <label className="field">
                <span>Kode</span>
                <input
                  className="input"
                  placeholder="HEBAT10"
                  value={form.code}
                  onChange={(e) => setForm({ ...form, code: e.target.value.toUpperCase() })}
                  required
                />
              </label>
              <label className="field">
                <span>Jenis diskon</span>
                <select
                  className="select"
                  value={form.discount_type}
                  onChange={(e) => setForm({ ...form, discount_type: e.target.value as Voucher['discount_type'] })}
                >
                  <option value="percent">Persen (%)</option>
                  <option value="nominal">Nominal (Rp)</option>
                </select>
              </label>
              <label className="field">
                <span>Nilai diskon</span>
                <input
                  className="input"
                  type="number"
                  min={1}
                  placeholder={form.discount_type === 'percent' ? '10' : '25000'}
                  value={form.discount_value}
                  onChange={(e) => setForm({ ...form, discount_value: e.target.value })}
                  required
                />
              </label>
              <label className="field">
                <span>Minimum belanja</span>
                <input
                  className="input"
                  type="number"
                  min={0}
                  value={form.min_purchase}
                  onChange={(e) => setForm({ ...form, min_purchase: e.target.value })}
                />
              </label>
              <label className="field">
                <span>Kuota</span>
                <input
                  className="input"
                  type="number"
                  min={1}
                  placeholder="Kosong = tanpa batas"
                  value={form.quota}
                  onChange={(e) => setForm({ ...form, quota: e.target.value })}
                />
              </label>
              <label className="field">
                <span>Kedaluwarsa</span>
                <input
                  className="input"
                  type="date"
                  value={form.expires_at}
                  onChange={(e) => setForm({ ...form, expires_at: e.target.value })}
                />
              </label>
            </div>
            <div className="head-actions" style={{ marginTop: 14 }}>
              <button className="btn btn-primary" type="submit" disabled={busy}>
                {busy ? 'Menyimpan…' : 'Tambah voucher'}
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
          <table className="data-table" style={{ minWidth: 840 }}>
            <thead>
              <tr>
                <th>Kode</th>
                <th>Diskon</th>
                <th className="num">Minimum</th>
                <th className="num">Kuota</th>
                <th>Terpakai</th>
                <th>Kedaluwarsa</th>
                <th>Aktif</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan={8}>
                    <div className="empty-state">
                      <strong>Memuat voucher…</strong>
                    </div>
                  </td>
                </tr>
              ) : rows.length === 0 ? (
                <tr>
                  <td colSpan={8}>
                    <div className="empty-state">
                      <strong>Belum ada voucher</strong>
                      <span>Buat voucher pertama lewat tombol di kanan atas.</span>
                    </div>
                  </td>
                </tr>
              ) : (
                rows.map((v) => {
                  const r = report[v.id] ?? { used: 0, locked: 0, discount: 0 }
                  const totalUsed = Math.max(v.used, r.used)
                  const percent = v.quota ? Math.min(100, Math.round((totalUsed / v.quota) * 100)) : 0
                  return (
                    <tr key={v.id}>
                      <td>
                        <span className="strong">{v.code}</span>
                        <span className="sub">
                          {v.discount_type === 'percent' ? 'Persen' : 'Nominal'} · 1 per transaksi
                        </span>
                      </td>
                      <td>{label(v)}</td>
                      <td className="num">{v.min_purchase ? rupiah(v.min_purchase) : '—'}</td>
                      <td className="num">{v.quota ?? '∞'}</td>
                      <td>
                        <div className="progress-row">
                          <span className={`progress${percent >= 100 ? ' done' : ''}`}>
                            <span style={{ width: `${percent}%` }} />
                          </span>
                          <span className="num">{totalUsed}</span>
                        </div>
                      </td>
                      <td className="num">{tanggal(v.expires_at)}</td>
                      <td>
                        <button
                          className="switch"
                          role="switch"
                          aria-checked={v.active}
                          aria-label={`Aktifkan ${v.code}`}
                          onClick={() => toggleActive(v)}
                        />
                      </td>
                      <td>
                        <div className="row-actions">
                          <button className="btn btn-ghost btn-sm" onClick={() => onDelete(v)}>
                            Hapus
                          </button>
                        </div>
                      </td>
                    </tr>
                  )
                })
              )}
            </tbody>
          </table>
        </div>
        <div className="card-foot" style={{ display: 'flex', gap: 16, flexWrap: 'wrap', alignItems: 'center' }}>
          <span className="sub">
            {totals.used} terpakai · {totals.locked} dikunci · total diskon {rupiah(totals.discount)}
          </span>
          <span className="badge neutral" style={{ marginLeft: 'auto' }}>
            Kuota total {totals.quota || 'tanpa batas'}
          </span>
        </div>
      </div>
    </section>
  )
}
