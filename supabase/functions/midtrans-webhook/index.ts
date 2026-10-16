import { createClient } from 'npm:@supabase/supabase-js@2'

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

  const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)

  // Idempoten by order_id.
  const { data: payment } = await admin
    .from('payments')
    .select('id, status, booking_id, package_purchase_id, group_seat_id')
    .eq('order_id', orderId)
    .maybeSingle()
  if (!payment) return json({ ok: false, reason: 'order_id tidak dikenal' })

  const paid =
    transaction_status === 'settlement' ||
    (transaction_status === 'capture' && p.fraud_status === 'accept')

  let newStatus: string
  let bookingStatus: string | null = null
  if (paid) {
    newStatus = 'settlement'
    bookingStatus = 'confirmed'
  } else if (transaction_status === 'deny' || transaction_status === 'cancel') {
    newStatus = transaction_status
    bookingStatus = 'cancelled'
  } else if (transaction_status === 'expire') {
    newStatus = 'expire'
    bookingStatus = 'expired'
  } else if (transaction_status === 'refund' || transaction_status === 'partial_refund') {
    newStatus = transaction_status
    bookingStatus = 'refunded'
  } else {
    // pending / challenge / capture non-accept → tetap menunggu.
    newStatus = 'pending'
  }

  if (payment.status === newStatus) return json({ ok: true, unchanged: true })

  await admin
    .from('payments')
    .update({
      status: newStatus,
      paid_at: paid ? new Date().toISOString() : null,
      raw: p,
    })
    .eq('id', payment.id)

  if (payment.booking_id && bookingStatus) {
    // Hanya ubah booking yang masih menunggu bayar (kecuali refund).
    const fromStatuses = newStatus === 'refund' || newStatus === 'partial_refund'
      ? ['confirmed', 'in_progress', 'completed']
      : ['pending_payment']
    await admin
      .from('bookings')
      .update({ status: bookingStatus, lock_expires_at: null })
      .eq('id', payment.booking_id)
      .in('status', fromStatuses)
  }

  // Voucher: tandai terpakai saat berhasil, lepas kuota saat gagal/kedaluwarsa/refund.
  if (payment.booking_id) {
    if (paid) {
      await admin.rpc('consume_voucher_for_booking', { p_booking_id: payment.booking_id })
    } else if (
      newStatus === 'deny' || newStatus === 'cancel' || newStatus === 'expire' ||
      newStatus === 'refund' || newStatus === 'partial_refund'
    ) {
      await admin.rpc('release_voucher_for_booking', { p_booking_id: payment.booking_id })
    }
  }

  // Paket sesi: aktifkan (masa berlaku 90 hari) atau tandai gagal.
  if (payment.package_purchase_id) {
    if (paid) {
      const now = new Date()
      const expires = new Date(now.getTime() + 90 * 24 * 60 * 60 * 1000)
      await admin
        .from('package_purchases')
        .update({
          status: 'active',
          purchased_at: now.toISOString(),
          expires_at: expires.toISOString(),
          lock_expires_at: null,
        })
        .eq('id', payment.package_purchase_id)
        .eq('status', 'pending_payment')
    } else if (newStatus === 'deny' || newStatus === 'cancel') {
      await admin
        .from('package_purchases')
        .update({ status: 'cancelled', lock_expires_at: null })
        .eq('id', payment.package_purchase_id)
        .eq('status', 'pending_payment')
    } else if (newStatus === 'expire') {
      await admin
        .from('package_purchases')
        .update({ status: 'expired', lock_expires_at: null })
        .eq('id', payment.package_purchase_id)
        .eq('status', 'pending_payment')
    } else if (newStatus === 'refund' || newStatus === 'partial_refund') {
      await admin
        .from('package_purchases')
        .update({ status: 'refunded' })
        .eq('id', payment.package_purchase_id)
        .eq('status', 'active')
    }
  }

  // Kursi kelas grup: aktifkan saat berhasil, lepas saat gagal/kedaluwarsa.
  if (payment.group_seat_id) {
    if (paid) {
      await admin.rpc('activate_group_seat', { p_seat_id: payment.group_seat_id })
    } else if (
      newStatus === 'deny' || newStatus === 'cancel' || newStatus === 'expire' ||
      newStatus === 'refund' || newStatus === 'partial_refund'
    ) {
      await admin.rpc('release_group_seat', { p_seat_id: payment.group_seat_id })
    }
  }

  return json({ ok: true, order_id: orderId, status: newStatus })
})
