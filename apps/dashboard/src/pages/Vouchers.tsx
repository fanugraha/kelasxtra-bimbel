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

export function Vouchers() {
  const [rows, setRows] = useState<Voucher[]>([])
  const [report, setReport] = useState<Record<string, VoucherReport>>({})
  const [loading, setLoading] = useState(true)
  const [form, setForm] = useState(emptyForm)
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
      supabase.from('bookings').select('voucher_id, discount').not('voucher_id', 'is', null),
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

  return (
    <section>
      <h1>Voucher &amp; Promo</h1>
      <p className="muted">1 voucher per transaksi. Kuota dikunci saat bayar (race-safe). Diskon 100% ditanggung platform.</p>

      <form className="tutor-form" onSubmit={onCreate}>
        <input placeholder="Kode" value={form.code} onChange={(e) => setForm({ ...form, code: e.target.value })} required />
        <select value={form.discount_type} onChange={(e) => setForm({ ...form, discount_type: e.target.value as Voucher['discount_type'] })}>
          <option value="percent">Persen (%)</option>
          <option value="nominal">Nominal (Rp)</option>
        </select>
        <input type="number" placeholder="Nilai diskon" value={form.discount_value} onChange={(e) => setForm({ ...form, discount_value: e.target.value })} required />
        <input type="number" placeholder="Min. belanja" value={form.min_purchase} onChange={(e) => setForm({ ...form, min_purchase: e.target.value })} />
        <input type="number" placeholder="Kuota (kosong = ∞)" value={form.quota} onChange={(e) => setForm({ ...form, quota: e.target.value })} />
        <input type="date" value={form.expires_at} onChange={(e) => setForm({ ...form, expires_at: e.target.value })} />
        <button type="submit" disabled={busy}>{busy ? 'Menyimpan…' : 'Tambah voucher'}</button>
      </form>

      {notice && <pre className="notice-line">{notice}</pre>}

      {loading ? (
        <p className="muted">Memuat…</p>
      ) : rows.length === 0 ? (
        <p className="muted">Belum ada voucher.</p>
      ) : (
        <table className="table">
          <thead>
            <tr>
              <th>Kode</th>
              <th>Diskon</th>
              <th>Min</th>
              <th>Kuota</th>
              <th>Berakhir</th>
              <th>Status</th>
              <th>Aksi</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((v) => (
              <tr key={v.id}>
                <td>{v.code}</td>
                <td>{label(v)}</td>
                <td>{v.min_purchase ? 'Rp' + v.min_purchase.toLocaleString('id-ID') : '—'}</td>
                <td>{v.used}/{v.quota ?? '∞'}</td>
                <td className="muted">{v.expires_at ? new Date(v.expires_at).toLocaleDateString('id-ID') : '—'}</td>
                <td>
                  <span className={`status status-${v.active ? 'aktif' : 'suspend'}`}>{v.active ? 'Aktif' : 'Nonaktif'}</span>
                </td>
                <td className="actions">
                  <button onClick={() => toggleActive(v)}>{v.active ? 'Nonaktifkan' : 'Aktifkan'}</button>
                  <button onClick={() => onDelete(v)}>Hapus</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}

      <h2>Laporan pemakaian</h2>
      <table className="table">
        <thead>
          <tr>
            <th>Kode</th>
            <th>Terpakai</th>
            <th>Dikunci (belum bayar)</th>
            <th>Total diskon</th>
            <th>Kuota</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((v) => {
            const r = report[v.id] ?? { used: 0, locked: 0, discount: 0 }
            return (
              <tr key={v.id}>
                <td>{v.code}</td>
                <td>{r.used}</td>
                <td>{r.locked}</td>
                <td>{`Rp${r.discount.toLocaleString('id-ID')}`}</td>
                <td className="muted">{v.quota ?? 'Tanpa batas'}</td>
              </tr>
            )
          })}
        </tbody>
      </table>
    </section>
  )
}
