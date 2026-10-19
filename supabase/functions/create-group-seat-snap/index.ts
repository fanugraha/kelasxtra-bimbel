import { createClient } from 'npm:@supabase/supabase-js@2'
import { cachedQris, cors, createQris, json, type Qris, qrisFields } from '../_shared/midtrans.ts'
import { CREDIT_METHOD, creditPlan, readCreditBalance } from '../_shared/credits.ts'
import { applyPaymentOutcome } from '../_shared/paymentApply.ts'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })
  if (req.method !== 'POST') return json({ error: 'Metode tidak diizinkan' }, 405)

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  if (!Deno.env.get('MIDTRANS_SERVER_KEY')) {
    return json({ error: 'MIDTRANS_SERVER_KEY belum diset' }, 500)
  }
  const admin = createClient(supabaseUrl, serviceKey)

  const caller = createClient(supabaseUrl, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } },
  })
  const { data: userData, error: userErr } = await caller.auth.getUser()
  if (userErr || !userData.user) return json({ error: 'Tidak terautentikasi' }, 401)
  const uid = userData.user.id

  const { data: profile } = await admin.from('profiles').select('role').eq('id', uid).single()
  if (profile?.role !== 'student') return json({ error: 'Hanya siswa yang bisa ambil kursi' }, 403)

  let body: { group_class_id?: string; use_credits?: boolean }
  try {
    body = await req.json()
  } catch {
    return json({ error: 'Body tidak valid' }, 400)
  }
  const groupClassId = body.group_class_id
  if (!groupClassId) return json({ error: 'group_class_id wajib' }, 400)

  const { data: cls } = await admin
    .from('group_classes')
    .select('id, status, jenjang, duration_minutes, mode, price_total, seats_taken, max_seats')
    .eq('id', groupClassId)
    .maybeSingle()
  if (!cls) return json({ error: 'Kelas tidak ditemukan' }, 404)

  // Pakai ulang kursi pending yang lock-nya masih hidup (idempoten).
  const { data: existingSeat } = await admin
    .from('group_seats')
    .select('id, price_paid')
    .eq('group_class_id', groupClassId)
    .eq('student_id', uid)
    .eq('status', 'pending_payment')
    .gt('lock_expires_at', new Date().toISOString())
    .maybeSingle()

  let seatId: string
  let base: number
  let createdNow = false

  if (existingSeat) {
    seatId = existingSeat.id as string
    base = Number(existingSeat.price_paid ?? 0)
  } else {
    if (cls.status !== 'open' || cls.seats_taken >= cls.max_seats) {
      return json({ error: 'Kursi tidak tersedia' }, 400)
    }
    const { data: seat, error: sErr } = await admin.rpc('reserve_group_seat', {
      p_group_class_id: groupClassId,
      p_student: uid,
    })
    if (sErr) return json({ error: sErr.message }, 400)
    seatId = seat as string
    createdNow = true
    const { data: seatRow } = await admin
      .from('group_seats')
      .select('price_paid')
      .eq('id', seatId)
      .single()
    base = Number(seatRow?.price_paid ?? 0)
  }

  const orderId = `GS-${seatId}`

  // Poin siswa (bila diminta): potong sebanyak mungkin, maksimal sebesar harga.
  // Poin baru dibukukan saat pembayaran lunas (lihat paymentApply).
  let creditApplied = 0
  if (body.use_credits) {
    creditApplied = creditPlan(await readCreditBalance(admin, uid), base)
  }
  const amount = base - creditApplied

  const { data: student } = await admin
    .from('students')
    .select('full_name')
    .eq('id', uid)
    .maybeSingle()

  // QRIS sudah terbit untuk order ini → tagihan terkunci; pakai ulang apa adanya
  // (Midtrans menolak charge kedua dengan order_id yang sama).
  const { data: pay } = await admin
    .from('payments')
    .select('amount, credit_amount, raw')
    .eq('order_id', orderId)
    .eq('status', 'pending')
    .maybeSingle()
  const cached = cachedQris(pay?.raw)
  if (pay && cached) {
    return json({
      order_id: orderId,
      seat_id: seatId,
      ...qrisFields(cached),
      amount: Number(pay.amount),
      credit_applied: Math.floor(Number(pay.credit_amount ?? 0)),
      paid: false,
      reused: true,
    })
  }

  // Poin menutup seluruh harga → lunas tanpa Midtrans.
  if (amount === 0 && creditApplied > 0) {
    const { data: existing } = await admin
      .from('payments')
      .select('id, status')
      .eq('order_id', orderId)
      .maybeSingle()
    if (existing?.status === 'settlement') {
      return json({
        order_id: orderId,
        seat_id: seatId,
        amount: 0,
        credit_applied: creditApplied,
        paid: true,
        reused: true,
      })
    }
    let paymentId = existing?.id as string | undefined
    if (paymentId) {
      const { error } = await admin
        .from('payments')
        .update({
          amount: 0,
          credit_amount: creditApplied,
          raw: { method: CREDIT_METHOD },
        })
        .eq('id', paymentId)
      if (error) return json({ error: error.message }, 400)
    } else {
      const { data: ins, error } = await admin
        .from('payments')
        .insert({
          order_id: orderId,
          type: 'group_seat',
          group_seat_id: seatId,
          amount: 0,
          credit_amount: creditApplied,
          status: 'pending',
          raw: { method: CREDIT_METHOD },
        })
        .select('id')
        .single()
      if (error || !ins) return json({ error: error?.message ?? 'Gagal membuat pembayaran' }, 400)
      paymentId = ins.id as string
    }

    const applied = await applyPaymentOutcome(
      admin,
      {
        id: paymentId,
        order_id: orderId,
        status: 'pending',
        booking_id: null,
        package_purchase_id: null,
        group_seat_id: seatId,
        subscription_id: null,
        credit_amount: creditApplied,
      },
      { paid: true, newStatus: 'settlement', bookingStatus: null },
      { method: CREDIT_METHOD },
    )
    if (!applied.ok) {
      return json({ error: 'Gagal menyelesaikan kursi dengan poin' }, 502)
    }
    return json({
      order_id: orderId,
      seat_id: seatId,
      amount: 0,
      credit_applied: creditApplied,
      paid: true,
      reused: false,
    })
  }

  let qris: Qris
  try {
    qris = await createQris(
      orderId,
      amount,
      `Kursi kelas grup · ${cls.jenjang} · ${cls.duration_minutes} menit`,
      { first_name: student?.full_name ?? 'Siswa', email: userData.user.email ?? undefined },
    )
  } catch (e) {
    if (createdNow) {
      await admin.from('payments').delete().eq('order_id', orderId)
      await admin.rpc('release_group_seat', { p_seat_id: seatId })
    }
    return json({ error: (e as Error).message }, 502)
  }

  const { data: existingPay } = await admin
    .from('payments')
    .select('id')
    .eq('order_id', orderId)
    .maybeSingle()

  if (existingPay) {
    await admin
      .from('payments')
      .update({
        amount,
        credit_amount: creditApplied,
        raw: qris,
      })
      .eq('order_id', orderId)
  } else {
    const { error: pErr } = await admin.from('payments').insert({
      order_id: orderId,
      type: 'group_seat',
      group_seat_id: seatId,
      amount,
      credit_amount: creditApplied,
      status: 'pending',
      raw: qris,
    })
    if (pErr) return json({ error: pErr.message }, 400)
  }

  return json({
    order_id: orderId,
    seat_id: seatId,
    ...qrisFields(qris),
    amount,
    credit_applied: creditApplied,
    paid: false,
    reused: false,
  })
})
