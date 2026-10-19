// Tindak lanjut manual pembayaran yang gagal diproses otomatis (`review_required`).
//
// Dipakai dashboard admin. Dua aksi:
//   retry   — jalankan ulang langkah aktivasi (paket/kursi/langganan/booking).
//             Bila payment masih `pending`, status ditanyakan dulu ke Midtrans.
//             Semua RPC lanjutan dijaga statusnya sendiri, jadi aman diulang.
//   dismiss — admin menangani di luar sistem (mis. refund manual); tanda dilepas
//             dan alasannya dicatat di audit_logs.
//
// Butuh env: MIDTRANS_SERVER_KEY (hanya untuk jalur `pending`).

import { createClient } from 'npm:@supabase/supabase-js@2'
import { transactionStatus } from '../_shared/midtrans.ts'
import {
  applyPaymentOutcome,
  outcomeFromMidtrans,
  outcomeFromPaymentStatus,
} from '../_shared/paymentApply.ts'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  })

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })
  if (req.method !== 'POST') return json({ error: 'Metode tidak diizinkan' }, 405)

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!
  const admin = createClient(supabaseUrl, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)

  // Identifikasi admin dari JWT pemanggil.
  const caller = createClient(supabaseUrl, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } },
  })
  const { data: userData, error: userErr } = await caller.auth.getUser()
  if (userErr || !userData.user) return json({ error: 'Tidak terautentikasi' }, 401)

  const { data: profile } = await admin
    .from('profiles')
    .select('role')
    .eq('id', userData.user.id)
    .single()
  if (profile?.role !== 'admin') return json({ error: 'Hanya admin' }, 403)

  let payload: { payment_id?: string; action?: string; note?: string }
  try {
    payload = await req.json()
  } catch {
    return json({ error: 'Body tidak valid' }, 400)
  }
  const paymentId = payload.payment_id?.trim()
  const action = payload.action
  if (!paymentId) return json({ error: 'payment_id wajib' }, 400)
  if (action !== 'retry' && action !== 'dismiss') {
    return json({ error: 'aksi harus retry atau dismiss' }, 400)
  }

  const { data: payment, error: readErr } = await admin
    .from('payments')
    .select(
      'id, order_id, status, booking_id, package_purchase_id, group_seat_id, ' +
        'subscription_id, credit_amount, review_required, review_note',
    )
    .eq('id', paymentId)
    .maybeSingle()
  if (readErr) return json({ error: readErr.message }, 500)
  if (!payment) return json({ error: 'Pembayaran tidak ditemukan' }, 404)

  // ---- Tandai sudah ditangani manual ----
  if (action === 'dismiss') {
    const note = payload.note?.trim().slice(0, 500)
    if (!note) return json({ error: 'Catatan penanganan wajib diisi' }, 400)

    const { error } = await admin
      .from('payments')
      .update({ review_required: false, review_note: null })
      .eq('id', payment.id)
    if (error) return json({ error: error.message }, 500)

    await admin.from('audit_logs').insert({
      actor_id: userData.user.id,
      action: 'payments.review_dismissed',
      entity: 'payments',
      entity_id: payment.id,
      after_data: { order_id: payment.order_id, note },
    })
    return json({ ok: true, status: payment.status, review_required: false, review_note: null })
  }

  // ---- Proses ulang ----
  let raw: unknown = null
  let outcome
  if (payment.status === 'pending') {
    if (!Deno.env.get('MIDTRANS_SERVER_KEY')) {
      return json({ error: 'MIDTRANS_SERVER_KEY belum diset' }, 500)
    }
    let res
    try {
      res = await transactionStatus(payment.order_id)
    } catch (e) {
      return json({ error: `Midtrans tidak terjangkau: ${(e as Error).message}` }, 502)
    }
    outcome = res.found
      ? outcomeFromMidtrans(res.body?.transaction_status ?? 'pending', res.body?.fraud_status)
      : outcomeFromMidtrans('expire')
    raw = res.found ? (res.body ?? null) : { reason: 'order_id tidak dikenal Midtrans' }

    if (outcome.newStatus === 'pending') {
      return json({
        ok: true,
        status: payment.status,
        review_required: true,
        review_note: payment.review_note,
        message: 'Midtrans masih menyatakan transaksi berjalan; belum ada yang bisa diproses ulang.',
      })
    }
  } else {
    // Status payment kita sudah menentukan (mis. `settlement`): cukup jalankan
    // ulang langkah aktivasi, tanpa menurunkan status yang sudah lunas.
    outcome = outcomeFromPaymentStatus(payment.status)
  }

  // Tanda lama dibersihkan dulu; bila masih gagal, `flagReview` akan menandai ulang
  // dengan catatan yang baru.
  await admin
    .from('payments')
    .update({ review_required: false, review_note: null })
    .eq('id', payment.id)

  const result = await applyPaymentOutcome(admin, payment, outcome, raw, { force: true })

  const { data: after } = await admin
    .from('payments')
    .select('status, review_required, review_note')
    .eq('id', payment.id)
    .single()

  if (after?.review_required) {
    return json({
      ok: false,
      status: after.status,
      review_required: true,
      review_note: after.review_note,
      message: `Masih gagal diproses: ${after.review_note ?? 'lihat catatan'}`,
    })
  }

  await admin.from('audit_logs').insert({
    actor_id: userData.user.id,
    action: 'payments.review_resolved',
    entity: 'payments',
    entity_id: payment.id,
    before_data: { status: payment.status, review_note: payment.review_note },
    after_data: { status: after?.status ?? result.status },
  })

  return json({
    ok: true,
    status: after?.status ?? result.status,
    review_required: false,
    review_note: null,
    message: 'Pembayaran berhasil diproses ulang.',
  })
})
