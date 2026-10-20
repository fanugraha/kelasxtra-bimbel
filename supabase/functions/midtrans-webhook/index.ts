import { createClient } from 'npm:@supabase/supabase-js@2'
import { applyPaymentOutcome, flagReview, outcomeFromMidtrans } from '../_shared/paymentApply.ts'
import { secretKey } from '../_shared/keys.ts'

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } })

async function sha512Hex(input: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-512', new TextEncoder().encode(input))
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, '0')).join('')
}

type Payload = {
  order_id?: string
  status_code?: string
  gross_amount?: string
  signature_key?: string
  transaction_status?: string
  fraud_status?: string
  transaction_id?: string
  payment_type?: string
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json({ error: 'Metode tidak diizinkan' }, 405)

  const serverKey = Deno.env.get('MIDTRANS_SERVER_KEY')
  if (!serverKey) return json({ error: 'MIDTRANS_SERVER_KEY belum diset' }, 500)

  let p: Payload
  try {
    p = await req.json()
  } catch {
    return json({ error: 'Body tidak valid' }, 400)
  }

  const { order_id: orderId, status_code, gross_amount, signature_key, transaction_status } = p
  if (!orderId || !status_code || !gross_amount || !signature_key || !transaction_status) {
    return json({ error: 'Field webhook tidak lengkap' }, 400)
  }

  // Verifikasi signature SHA512 (order_id + status_code + gross_amount + server key).
  const expected = await sha512Hex(`${orderId}${status_code}${gross_amount}${serverKey}`)
  if (expected !== signature_key) return json({ error: 'Signature tidak sah' }, 401)

  const admin = createClient(Deno.env.get('SUPABASE_URL')!, secretKey())

  // Idempoten by order_id.
  const { data: payment } = await admin
    .from('payments')
    .select('id, order_id, status, amount, booking_id, package_purchase_id, group_seat_id, subscription_id, credit_amount')
    .eq('order_id', orderId)
    .maybeSingle()
  if (!payment) return json({ ok: false, reason: 'order_id tidak dikenal' })

  // Signature sah saja belum cukup: nominal harus sama dengan tagihan tersimpan.
  if (Math.round(Number(gross_amount)) !== Math.round(Number(payment.amount))) {
    await flagReview(admin, payment.id, `Nominal webhook ${gross_amount} != ${payment.amount}`)
    return json({ error: 'Nominal tidak cocok' }, 400)
  }

  const outcome = outcomeFromMidtrans(transaction_status, p.fraud_status)
  const result = await applyPaymentOutcome(admin, payment, outcome, p)

  return json({ ok: true, order_id: orderId, status: result.status, unchanged: result.unchanged ?? false })
})
