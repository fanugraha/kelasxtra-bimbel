import { createClient } from 'npm:@supabase/supabase-js@2'
import {
  cachedQris,
  cors,
  createQris,
  json,
  LOCK_MINUTES,
  type Qris,
  qrisFields,
} from '../_shared/midtrans.ts'
import { CREDIT_METHOD, creditPlan, readCreditBalance } from '../_shared/credits.ts'
import { applyPaymentOutcome } from '../_shared/paymentApply.ts'

type Admin = ReturnType<typeof createClient>

/// Kunci kuota voucher; mengembalikan diskon + id redemption (null bila kode kosong).
async function reserveVoucher(
  admin: Admin,
  code: string,
  studentId: string,
  price: number,
): Promise<{ voucherId: string; discount: number; redemptionId: string }> {
  const { data, error } = await admin.rpc('reserve_voucher', {
    p_code: code,
    p_student: studentId,
    p_price: price,
  })
  if (error) throw new Error(error.message)
  const row = Array.isArray(data) ? data[0] : data
  return {
    voucherId: row.voucher_id as string,
    discount: Number(row.discount),
    redemptionId: row.redemption_id as string,
  }
}

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
  if (profile?.role !== 'student') return json({ error: 'Hanya siswa yang bisa booking' }, 403)

  let body: {
    tutor_id?: string
    subject_id?: string
    jenjang?: string
    duration_minutes?: number
    mode?: string
    scheduled_at?: string
    address?: string
    voucher_code?: string
    use_credits?: boolean
  }
  try {
    body = await req.json()
  } catch {
    return json({ error: 'Body tidak valid' }, 400)
  }

  const { tutor_id: tutorId, subject_id: subjectId, jenjang } = body
  const duration = body.duration_minutes
  const mode = body.mode
  if (!tutorId || !subjectId || !jenjang || !duration || !mode || !body.scheduled_at) {
    return json({ error: 'tutor_id, subject_id, jenjang, duration_minutes, mode, scheduled_at wajib' }, 400)
  }
  if (![60, 90, 120].includes(duration)) return json({ error: 'duration_minutes tidak valid' }, 400)
  if (mode !== 'online' && mode !== 'offline') return json({ error: 'mode tidak valid' }, 400)

  const scheduled = new Date(body.scheduled_at)
  if (isNaN(scheduled.getTime())) return json({ error: 'scheduled_at tidak valid' }, 400)
  if (scheduled.getTime() < Date.now()) return json({ error: 'Jadwal sudah lewat' }, 400)

  // Tutor harus aktif & mengajar kombinasi mapel+jenjang ini.
  const { data: tutor } = await admin.from('tutors').select('status').eq('id', tutorId).maybeSingle()
  if (!tutor || tutor.status !== 'aktif') return json({ error: 'Tutor tidak aktif' }, 400)
  const { data: teaches } = await admin
    .from('tutor_subjects')
    .select('tutor_id')
    .eq('tutor_id', tutorId)
    .eq('subject_id', subjectId)
    .eq('jenjang', jenjang)
    .maybeSingle()
  if (!teaches) return json({ error: 'Tutor tidak mengajar kombinasi ini' }, 400)

  // Harga dari price matrix (snapshot ke booking). type=semi: privat dulu.
  const { data: priceRow } = await admin
    .from('price_matrix')
    .select('price')
    .eq('jenjang', jenjang)
    .eq('duration_minutes', duration)
    .eq('mode', mode)
    .eq('type', 'privat')
    .eq('active', true)
    .maybeSingle()
  if (!priceRow) return json({ error: 'Harga belum diset untuk kombinasi ini' }, 400)

  const scheduledIso = scheduled.toISOString()
  const nowIso = new Date().toISOString()

  // Pakai ulang booking pending yang lock-nya masih hidup (idempoten: hindari slot dobel).
  const { data: existing } = await admin
    .from('bookings')
    .select('id, discount, voucher_id')
    .eq('student_id', uid)
    .eq('tutor_id', tutorId)
    .eq('scheduled_at', scheduledIso)
    .eq('status', 'pending_payment')
    .gt('lock_expires_at', nowIso)
    .maybeSingle()

  let bookingId: string
  let orderId: string
  let base: number
  let voucherId: string | null = null
  let createdNow = false
  let pendingPay:
    | { order_id: string; amount: number; credit_amount: number; raw: unknown }
    | null = null

  if (existing) {
    bookingId = existing.id
    voucherId = (existing.voucher_id as string | null) ?? null
    const { data: pay } = await admin
      .from('payments')
      .select('order_id, amount, credit_amount, raw')
      .eq('booking_id', bookingId)
      .eq('status', 'pending')
      .maybeSingle()
    orderId = (pay?.order_id as string | undefined) ?? `BK-${bookingId}`
    if (pay) {
      pendingPay = {
        order_id: orderId,
        amount: Number(pay.amount),
        credit_amount: Math.floor(Number(pay.credit_amount ?? 0)),
        raw: pay.raw,
      }
    }
    base = Math.max(0, priceRow.price - Number(existing.discount ?? 0))
  } else {
    // Kunci voucher (bila ada) sebelum membuat booking.
    let discount = 0
    let redemptionId: string | null = null
    if (body.voucher_code && body.voucher_code.trim()) {
      try {
        const r = await reserveVoucher(admin, body.voucher_code.trim(), uid, priceRow.price)
        voucherId = r.voucherId
        discount = r.discount
        redemptionId = r.redemptionId
      } catch (e) {
        return json({ error: (e as Error).message }, 400)
      }
    }

    const { data: booking, error: bErr } = await admin
      .from('bookings')
      .insert({
        student_id: uid,
        tutor_id: tutorId,
        subject_id: subjectId,
        jenjang,
        duration_minutes: duration,
        mode,
        type: 'privat',
        scheduled_at: scheduledIso,
        price: priceRow.price,
        discount,
        voucher_id: voucherId,
        status: 'pending_payment',
        address: mode === 'offline' ? (body.address?.trim() || null) : null,
        lock_expires_at: new Date(Date.now() + LOCK_MINUTES * 60_000).toISOString(),
      })
      .select('id')
      .single()
    if (bErr || !booking) {
      if (redemptionId) {
        await admin.rpc('release_voucher_redemption', { p_redemption_id: redemptionId })
      }
      return json({ error: bErr?.message ?? 'Gagal membuat booking' }, 400)
    }
    bookingId = booking.id
    orderId = `BK-${bookingId}`
    base = Math.max(0, priceRow.price - discount)
    createdNow = true

    if (redemptionId) {
      await admin.rpc('attach_voucher_redemption', {
        p_redemption_id: redemptionId,
        p_booking_id: bookingId,
      })
    }
  }

  // Poin siswa (bila diminta): potong sebanyak mungkin, maksimal sebesar tagihan.
  // Poin baru dibukukan saat pembayaran lunas (lihat paymentApply).
  let creditApplied = 0
  if (body.use_credits) {
    creditApplied = creditPlan(await readCreditBalance(admin, uid), base)
  }
  const amount = base - creditApplied

  // QRIS sudah terbit untuk order ini → tagihan terkunci; pakai ulang apa adanya
  // (Midtrans menolak charge kedua dengan order_id yang sama).
  const cached = cachedQris(pendingPay?.raw)
  if (pendingPay && cached) {
    return json({
      order_id: orderId,
      booking_id: bookingId,
      ...qrisFields(cached),
      amount: pendingPay.amount,
      credit_applied: pendingPay.credit_amount,
      paid: false,
      reused: true,
    })
  }

  const { data: student } = await admin
    .from('students')
    .select('full_name')
    .eq('id', uid)
    .maybeSingle()

  // Poin menutup seluruh harga → lunas tanpa Midtrans.
  if (amount === 0 && creditApplied > 0) {
    if (pendingPay) {
      const { error } = await admin
        .from('payments')
        .update({
          amount: 0,
          credit_amount: creditApplied,
          voucher_id: voucherId,
          raw: { method: CREDIT_METHOD },
        })
        .eq('order_id', orderId)
      if (error) return json({ error: error.message }, 400)
    } else {
      const { error } = await admin.from('payments').insert({
        order_id: orderId,
        type: 'booking',
        booking_id: bookingId,
        amount: 0,
        credit_amount: creditApplied,
        status: 'pending',
        voucher_id: voucherId,
        raw: { method: CREDIT_METHOD },
      })
      if (error) return json({ error: error.message }, 400)
    }

    const { data: payRow } = await admin
      .from('payments')
      .select('id, status')
      .eq('order_id', orderId)
      .maybeSingle()
    if (payRow?.status === 'settlement') {
      return json({
        order_id: orderId,
        booking_id: bookingId,
        amount: 0,
        credit_applied: creditApplied,
        paid: true,
        reused: true,
      })
    }

    const applied = await applyPaymentOutcome(
      admin,
      {
        id: payRow!.id as string,
        order_id: orderId,
        status: 'pending',
        booking_id: bookingId,
        package_purchase_id: null,
        group_seat_id: null,
        subscription_id: null,
        credit_amount: creditApplied,
      },
      { paid: true, newStatus: 'settlement', bookingStatus: 'confirmed' },
      { method: CREDIT_METHOD },
    )
    if (!applied.ok) {
      return json({ error: 'Gagal menyelesaikan sesi dengan poin' }, 502)
    }
    return json({
      order_id: orderId,
      booking_id: bookingId,
      amount: 0,
      credit_applied: creditApplied,
      paid: true,
      reused: false,
    })
  }

  if (!pendingPay) {
    const { error } = await admin.from('payments').insert({
      order_id: orderId,
      type: 'booking',
      booking_id: bookingId,
      amount,
      credit_amount: creditApplied,
      status: 'pending',
      voucher_id: voucherId,
    })
    if (error) return json({ error: error.message }, 400)
  }

  let qris: Qris
  try {
    qris = await createQris(orderId, amount, `${jenjang} · ${duration} menit · ${mode}`, {
      first_name: student?.full_name ?? 'Siswa',
      email: userData.user.email ?? undefined,
    })
  } catch (e) {
    // Batalkan booking yang baru dibuat & lepas kunci voucher agar tidak nyangkut.
    if (createdNow) {
      await admin.rpc('release_voucher_for_booking', { p_booking_id: bookingId })
      await admin.from('payments').delete().eq('order_id', orderId)
      await admin.from('bookings').delete().eq('id', bookingId)
    }
    return json({ error: (e as Error).message }, 502)
  }

  await admin
    .from('payments')
    .update({
      amount,
      credit_amount: creditApplied,
      voucher_id: voucherId,
      raw: qris,
    })
    .eq('order_id', orderId)

  return json({
    order_id: orderId,
    booking_id: bookingId,
    ...qrisFields(qris),
    amount,
    credit_applied: creditApplied,
    paid: false,
    reused: false,
  })
})
