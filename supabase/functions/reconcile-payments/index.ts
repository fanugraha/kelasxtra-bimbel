// Sapuan tahanan pembayaran basi (bookings, paket, kursi grup, langganan).
//
// Prinsip: slot/kursi TIDAK dilepas berdasarkan waktu, melainkan setelah Midtrans
// memastikan transaksinya mati. Fungsi ini menanyakan `GET /v2/{order_id}/status`
// lalu menerapkan hasil yang sama seperti `midtrans-webhook` (satu modul logika).
// Dengan begitu tidak ada celah "pembayaran masuk setelah slot dilepas".
//
// Butuh env:
//   MIDTRANS_SERVER_KEY  (sudah dipakai webhook)
//   PUSH_CRON_SECRET     header `x-cron-secret` (sama seperti `send-push`)
//
// Panggil berkala (scheduler eksternal / pg_cron + pg_net), mis. tiap 1–5 menit:
//   curl -X POST .../functions/v1/reconcile-payments -H "x-cron-secret: ..."

import { createClient } from 'npm:@supabase/supabase-js@2'
import { transactionStatus } from '../_shared/midtrans.ts'
import { applyPaymentOutcome, flagReview, outcomeFromMidtrans } from '../_shared/paymentApply.ts'
import { secretKey } from '../_shared/keys.ts'

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } })

/// Tahanan dianggap basi setelah lock 30 menit QRIS lewat.
const STALE_MINUTES = 40
/// Bila Midtrans tidak bisa dimintai keterangan selama ini, admin diberi tanda.
const REVIEW_AFTER_HOURS = 24

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json({ error: 'Metode tidak diizinkan' }, 405)

  const secret = Deno.env.get('PUSH_CRON_SECRET')
  if (!secret || req.headers.get('x-cron-secret') !== secret) {
    return json({ error: 'Tidak diizinkan' }, 401)
  }
  if (!Deno.env.get('MIDTRANS_SERVER_KEY')) {
    return json({ error: 'MIDTRANS_SERVER_KEY belum diset' }, 500)
  }

  const admin = createClient(Deno.env.get('SUPABASE_URL')!, secretKey())

  const staleBefore = new Date(Date.now() - STALE_MINUTES * 60_000).toISOString()
  const reviewBefore = new Date(Date.now() - REVIEW_AFTER_HOURS * 3_600_000).toISOString()

  const { data: payments, error } = await admin
    .from('payments')
    .select('id, order_id, status, created_at, booking_id, package_purchase_id, group_seat_id, subscription_id, credit_amount')
    .eq('status', 'pending')
    .lt('created_at', staleBefore)
    .order('created_at', { ascending: true })
    .limit(40)
  if (error) return json({ error: error.message }, 500)

  const applied: { order_id: string; status: string }[] = []
  const skipped: string[] = []
  const flagged: string[] = []

  for (const payment of payments ?? []) {
    let res
    try {
      res = await transactionStatus(payment.order_id)
    } catch (e) {
      // Midtrans tidak terjangkau: jangan melepas apa pun; beri tanda bila lama.
      if (payment.created_at < reviewBefore) {
        await flagReview(admin, payment.id, `Midtrans tidak terjangkau: ${(e as Error).message}`)
        flagged.push(payment.order_id)
      } else {
        skipped.push(payment.order_id)
      }
      continue
    }

    if (!res.found) {
      // Midtrans tidak mengenal order_id → transaksi tidak pernah bisa dibayar.
      const outcome = outcomeFromMidtrans('expire')
      const result = await applyPaymentOutcome(admin, payment, outcome, { reason: 'order_id tidak dikenal Midtrans' })
      applied.push({ order_id: payment.order_id, status: result.status })
      continue
    }

    const status = res.body?.transaction_status
    if (!status) {
      if (payment.created_at < reviewBefore) {
        await flagReview(admin, payment.id, `Status Midtrans tidak jelas: ${JSON.stringify(res.body)}`)
        flagged.push(payment.order_id)
      } else {
        skipped.push(payment.order_id)
      }
      continue
    }

    const outcome = outcomeFromMidtrans(status, res.body?.fraud_status)
    if (outcome.newStatus === 'pending') {
      // Masih hidup menurut Midtrans (belum kedaluwarsa) → tunggu putaran berikutnya.
      skipped.push(payment.order_id)
      continue
    }

    const result = await applyPaymentOutcome(admin, payment, outcome, res.body)
    applied.push({ order_id: payment.order_id, status: result.status })
  }

  return json({
    ok: true,
    checked: payments?.length ?? 0,
    applied,
    skipped,
    flagged,
  })
})
