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

export function snapBase(): string {
  return Deno.env.get('MIDTRANS_IS_SANDBOX') === 'true'
    ? 'https://app.sandbox.midtrans.com'
    : 'https://app.midtrans.com'
}

/// Buat transaksi Snap. Melempar bila Midtrans menolak.
export async function createSnap(
  orderId: string,
  amount: number,
  itemName: string,
  customer: { first_name: string; email?: string },
): Promise<{ token: string; redirect_url: string }> {
  const serverKey = Deno.env.get('MIDTRANS_SERVER_KEY')!
  const res = await fetch(`${snapBase()}/snap/v1/transactions`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Accept: 'application/json',
      Authorization: `Basic ${btoa(`${serverKey}:`)}`,
    },
    body: JSON.stringify({
      transaction_details: { order_id: orderId, gross_amount: amount },
      item_details: [{ id: orderId, price: amount, quantity: 1, name: itemName.slice(0, 50) }],
      customer_details: customer,
      expiry: { unit: 'minutes', duration: LOCK_MINUTES },
    }),
  })
  const data = await res.json()
  if (!res.ok) {
    const msg = data?.error_messages?.join(', ') ?? 'Gagal membuat transaksi Midtrans'
    throw new Error(msg)
  }
  return { token: data.token, redirect_url: data.redirect_url }
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
