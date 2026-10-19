// Util bersama Edge Function Kelasxtra.

export const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

export const LOCK_MINUTES = 30

export const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  })

/// Basis API Core Midtrans (charge QRIS & status transaksi).
export function apiBase(): string {
  return Deno.env.get('MIDTRANS_IS_SANDBOX') === 'true'
    ? 'https://api.sandbox.midtrans.com'
    : 'https://api.midtrans.com'
}

/// Tanya status transaksi ke Midtrans. `found=false` bila Midtrans tidak kenal
/// order_id (transaksi tidak pernah benar-benar terbentuk).
export async function transactionStatus(orderId: string): Promise<{
  found: boolean
  status?: number
  body?: {
    transaction_status?: string
    fraud_status?: string
    status_code?: string
  }
}> {
  const serverKey = Deno.env.get('MIDTRANS_SERVER_KEY')!
  const res = await fetch(`${apiBase()}/v2/${orderId}/status`, {
    headers: {
      Accept: 'application/json',
      Authorization: `Basic ${btoa(`${serverKey}:`)}`,
    },
  })
  if (res.status === 404) return { found: false, status: 404 }
  let body: { transaction_status?: string; fraud_status?: string; status_code?: string } | undefined
  try {
    body = await res.json()
  } catch {
    body = undefined
  }
  if (!res.ok && !body) return { found: false, status: res.status }
  return { found: true, status: res.status, body }
}

/// QRIS dinamis hasil charge Core API. Disimpan apa adanya di `payments.raw`
/// agar bisa dipakai ulang selama belum kedaluwarsa.
export type Qris = {
  qr_string: string
  qr_url: string
  expires_at: string
}

/// QRIS yang sudah tersimpan untuk order ini. Midtrans menolak charge ulang
/// dengan order_id yang sama, jadi QR lama selalu dipakai ulang; masa berlakunya
/// sama dengan kunci tagihan (LOCK_MINUTES).
export function cachedQris(raw: unknown): Qris | null {
  const q = raw as Partial<Qris> | null
  return q?.qr_string && q.expires_at ? (q as Qris) : null
}

/// Field respons Edge Function untuk QRIS. `redirect_url` tetap diisi URL gambar
/// QR agar APK lama (yang masih membuka WebView) tetap bisa menampilkannya.
export const qrisFields = (q: Qris) => ({
  qr_string: q.qr_string,
  qr_url: q.qr_url,
  expires_at: q.expires_at,
  redirect_url: q.qr_url,
})

/// Buat QRIS dinamis (nominal sudah tertanam di QR) lewat Core API.
/// Melempar bila Midtrans menolak.
export async function createQris(
  orderId: string,
  amount: number,
  itemName: string,
  customer: { first_name: string; email?: string },
): Promise<Qris> {
  const serverKey = Deno.env.get('MIDTRANS_SERVER_KEY')!
  const res = await fetch(`${apiBase()}/v2/charge`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Accept: 'application/json',
      Authorization: `Basic ${btoa(`${serverKey}:`)}`,
    },
    body: JSON.stringify({
      payment_type: 'qris',
      transaction_details: { order_id: orderId, gross_amount: amount },
      item_details: [{ id: orderId, price: amount, quantity: 1, name: itemName.slice(0, 50) }],
      customer_details: customer,
      qris: { acquirer: 'gopay' },
      custom_expiry: { expiry_duration: LOCK_MINUTES, unit: 'minute' },
    }),
  })
  // Core API bisa membalas HTTP 200 dengan status_code gagal di body.
  const data = await res.json().catch(() => null)
  const code = String(data?.status_code ?? res.status)
  if (!res.ok || !code.startsWith('2') || !data?.qr_string) {
    throw new Error(data?.status_message ?? 'Gagal membuat QRIS Midtrans')
  }
  const qrUrl =
    (data.actions as { name: string; url: string }[] | undefined)
      ?.find((a) => a.name === 'generate-qr-code')?.url ?? ''
  // expiry_time dari Midtrans dalam WIB tanpa zona: "2026-10-19 13:30:00".
  const expiresAt = data.expiry_time
    ? new Date(`${String(data.expiry_time).replace(' ', 'T')}+07:00`).toISOString()
    : new Date(Date.now() + LOCK_MINUTES * 60_000).toISOString()
  return { qr_string: data.qr_string, qr_url: qrUrl, expires_at: expiresAt }
}

/// Ambil user dari header Authorization; null bila tidak sah.
export async function callerUser(
  supabaseUrl: string,
  anonKey: string,
  authHeader: string | null,
) {
  const { createClient } = await import('npm:@supabase/supabase-js@2')
  const client = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader ?? '' } },
  })
  const { data, error } = await client.auth.getUser()
  if (error || !data.user) return null
  return data.user
}
