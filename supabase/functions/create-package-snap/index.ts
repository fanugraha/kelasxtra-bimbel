import { createClient } from 'npm:@supabase/supabase-js@2'
import { cachedQris, cors, createQris, json, type Qris, qrisFields } from '../_shared/midtrans.ts'
import { CREDIT_METHOD, creditPlan, readCreditBalance } from '../_shared/credits.ts'
import { applyPaymentOutcome } from '../_shared/paymentApply.ts'
import { publishableKey, secretKey } from '../_shared/keys.ts'

type Admin = ReturnType<typeof createClient>

/// Kunci kuota voucher; mengembalikan diskon + id redemption (diekspor ulang
/// dari alur booking agar perilaku sama).
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

/// Beli paket (model paketan): siswa memilih jumlah pertemuan + hari/jam mulai.
/// Semua pertemuan mingguan ditahan 30 menit lewat `reserve_package_schedule`
/// supaya tidak dobel dengan pembeli lain. Harga paket diambil dari
/// `package_prices` (ditetapkan admin). Voucher opsional: diskon dari
/// `reserve_voucher` (kuota dikunci saat tagihan dibuat), uang bayar = harga - diskon.
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })
  if (req.method !== 'POST') return json({ error: 'Metode tidak diizinkan' }, 405)

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!
  const serviceKey = secretKey()
  if (!Deno.env.get('MIDTRANS_SERVER_KEY')) {
    return json({ error: 'MIDTRANS_SERVER_KEY belum diset' }, 500)
  }
  const admin = createClient(supabaseUrl, serviceKey)

  const caller = createClient(supabaseUrl, publishableKey(), {
    global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } },
  })
  const { data: userData, error: userErr } = await caller.auth.getUser()
  if (userErr || !userData.user) return json({ error: 'Tidak terautentikasi' }, 401)
  const uid = userData.user.id

  const { data: profile } = await admin.from('profiles').select('role').eq('id', uid).single()
  if (profile?.role !== 'student') return json({ error: 'Hanya siswa yang bisa membeli paket' }, 403)

  let body: {
    tutor_id?: string
    subject_id?: string
    jenjang?: string
    duration_minutes?: number
    mode?: string
    total_sesi?: number
    schedule_start_date?: string
    schedule_start_time?: string
    address?: string
    voucher_code?: string
    resume_package_id?: string
    use_credits?: boolean
  }
  try {
    body = await req.json()
  } catch {
    return json({ error: 'Body tidak valid' }, 400)
  }

  const isResume = Boolean(body.resume_package_id)
  const scheduleDate = (body.schedule_start_date ?? '').trim()
  const scheduleTime = (body.schedule_start_time ?? '').trim()
  const address = (body.address ?? '').trim()

  type PackageRow = {
    id: string
    status: string
    total_sesi: number
    jenjang: string
    duration_minutes: number
    mode: string
    price_total: number
    discount: number
    voucher_id: string | null
    schedule_start_date: string | null
    schedule_start_time: string | null
  }

  let pkg: PackageRow
  let createdNow = false
  let voucherId: string | null = null
  let discount = 0

  const pkgCols =
    'id, student_id, status, total_sesi, jenjang, duration_minutes, mode, price_total, ' +
    'discount, voucher_id, schedule_start_date, schedule_start_time'

  if (isResume) {
    const { data } = await admin
      .from('package_purchases')
      .select(pkgCols)
      .eq('id', body.resume_package_id!)
      .maybeSingle()
    if (!data) return json({ error: 'Paket tidak ditemukan' }, 404)
    if (data.student_id !== uid) return json({ error: 'Paket bukan milikmu' }, 403)
    if (data.status !== 'pending_payment') return json({ error: 'Paket tidak menunggu pembayaran' }, 400)
    pkg = data as PackageRow
    if (!pkg.schedule_start_date || !pkg.schedule_start_time) {
      return json({ error: 'Paket ini belum punya jadwal. Pilih jadwal dulu.' }, 400)
    }
    voucherId = pkg.voucher_id
    discount = Number(pkg.discount ?? 0)
  } else {
    const { tutor_id: tutorId, subject_id: subjectId, jenjang } = body
    const duration = body.duration_minutes
    const mode = body.mode
    const totalSesi = body.total_sesi
    if (!tutorId || !subjectId || !jenjang || !duration || !mode || !totalSesi) {
      return json({ error: 'tutor_id, subject_id, jenjang, duration_minutes, mode, total_sesi wajib' }, 400)
    }
    if (![60, 90, 120].includes(duration)) return json({ error: 'duration_minutes tidak valid' }, 400)
    if (mode !== 'online' && mode !== 'offline') return json({ error: 'mode tidak valid' }, 400)
    if (![4, 8, 12].includes(totalSesi)) return json({ error: 'Jumlah pertemuan harus 4, 8, atau 12' }, 400)
    if (!/^\d{4}-\d{2}-\d{2}$/.test(scheduleDate)) {
      return json({ error: 'Tanggal mulai pertemuan wajib dipilih' }, 400)
    }
    if (!/^\d{2}:\d{2}$/.test(scheduleTime)) {
      return json({ error: 'Jam mulai pertemuan wajib dipilih' }, 400)
    }
    if (mode === 'offline' && !address) {
      return json({ error: 'Alamat belajar wajib untuk paket offline' }, 400)
    }

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

    // Harga sesi normal (untuk bagi hasil tutor 75%) + harga paket (ditetapkan admin).
    const { data: priceRow } = await admin
      .from('price_matrix')
      .select('price')
      .eq('jenjang', jenjang)
      .eq('duration_minutes', duration)
      .eq('mode', mode)
      .eq('type', 'privat')
      .eq('active', true)
      .maybeSingle()
    if (!priceRow) return json({ error: 'Harga sesi belum diset untuk kombinasi ini' }, 400)

    const { data: pkgPrice } = await admin
      .from('package_prices')
      .select('price')
      .eq('jenjang', jenjang)
      .eq('duration_minutes', duration)
      .eq('mode', mode)
      .eq('total_sesi', totalSesi)
      .eq('active', true)
      .maybeSingle()
    if (!pkgPrice) return json({ error: 'Harga paket belum diset admin untuk kombinasi ini' }, 400)

    const scheduleDay = utcDayOfWeek(scheduleDate)

    // Paket pending yang lock-nya masih hidup untuk kombinasi sama (idempoten).
    const { data: existing } = await admin
      .from('package_purchases')
      .select(pkgCols)
      .eq('student_id', uid)
      .eq('tutor_id', tutorId)
      .eq('subject_id', subjectId)
      .eq('jenjang', jenjang)
      .eq('duration_minutes', duration)
      .eq('mode', mode)
      .eq('total_sesi', totalSesi)
      .eq('status', 'pending_payment')
      .gt('lock_expires_at', new Date().toISOString())
      .maybeSingle()

    if (existing) {
      pkg = existing as PackageRow
      // Voucher tetap seperti saat paket dibuat (tidak dikunci ulang).
      voucherId = pkg.voucher_id
      discount = Number((existing as PackageRow).discount ?? 0)
      const { error: uErr } = await admin
        .from('package_purchases')
        .update({
          schedule_day: scheduleDay,
          schedule_start_date: scheduleDate,
          schedule_start_time: scheduleTime,
          address: mode === 'offline' ? address : null,
          price_per_session: priceRow.price as number,
          price_total: pkgPrice.price as number,
        })
        .eq('id', pkg.id)
      if (uErr) return json({ error: uErr.message }, 400)
      pkg.price_total = pkgPrice.price as number
      pkg.schedule_start_date = scheduleDate
      pkg.schedule_start_time = scheduleTime
    } else {
      // Kunci kuota voucher (bila ada) sebelum paket dibuat.
      let redemptionId: string | null = null
      const voucherCode = (body.voucher_code ?? '').trim()
      if (voucherCode) {
        try {
          const r = await reserveVoucher(admin, voucherCode, uid, pkgPrice.price as number)
          voucherId = r.voucherId
          discount = r.discount
          redemptionId = r.redemptionId
        } catch (e) {
          return json({ error: (e as Error).message }, 400)
        }
      }

      const { data: inserted, error: pErr } = await admin
        .from('package_purchases')
        .insert({
          student_id: uid,
          tutor_id: tutorId,
          subject_id: subjectId,
          jenjang,
          duration_minutes: duration,
          mode,
          total_sesi: totalSesi,
          price_per_session: priceRow.price as number,
          discount_percent: 0,
          price_total: pkgPrice.price as number,
          voucher_id: voucherId,
          discount,
          status: 'pending_payment',
          schedule_day: scheduleDay,
          schedule_start_date: scheduleDate,
          schedule_start_time: scheduleTime,
          address: mode === 'offline' ? address : null,
          lock_expires_at: new Date(Date.now() + 30 * 60_000).toISOString(),
        })
        // Kolom lengkap: harga & detail dipakai untuk nominal dan nama item Midtrans.
        .select(pkgCols)
        .single()
      if (pErr || !inserted) {
        if (redemptionId) {
          await admin.rpc('release_voucher_redemption', { p_redemption_id: redemptionId })
        }
        return json({ error: pErr?.message ?? 'Gagal membuat paket' }, 400)
      }
      pkg = { ...(inserted as PackageRow), discount, voucher_id: voucherId }
      createdNow = true

      if (redemptionId) {
        await admin.rpc('attach_voucher_redemption_package', {
          p_redemption_id: redemptionId,
          p_package_id: pkg.id,
        })
      }
    }
  }

  const orderId = `PKG-${pkg.id}`
  const priceTotal = pkg.price_total as number
  const base = Math.max(0, priceTotal - discount)

  // Poin siswa (bila diminta): potong sebanyak mungkin, maksimal sebesar tagihan.
  // Poin baru benar-benar dibukukan saat pembayaran lunas (lihat paymentApply).
  let creditApplied = 0
  if (body.use_credits) {
    creditApplied = creditPlan(await readCreditBalance(admin, uid), base)
  }
  const amount = base - creditApplied

  // Tahan semua pertemuan mingguan (atau perbarui tahanannya).
  const { error: reserveErr } = await admin.rpc('reserve_package_schedule', { p_package_id: pkg.id })
  if (reserveErr) {
    if (createdNow) {
      await admin.rpc('release_voucher_for_package', { p_package_id: pkg.id })
      await admin.from('package_purchases').delete().eq('id', pkg.id)
    }
    return json({ error: reserveErr.message }, 400)
  }

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
      package_id: pkg.id,
      ...qrisFields(cached),
      amount: Number(pay.amount),
      discount,
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
        package_id: pkg.id,
        amount: 0,
        discount,
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
          voucher_id: voucherId,
          raw: { method: CREDIT_METHOD },
        })
        .eq('id', paymentId)
      if (error) return json({ error: error.message }, 400)
    } else {
      const { data: ins, error } = await admin
        .from('payments')
        .insert({
          order_id: orderId,
          type: 'package',
          package_purchase_id: pkg.id,
          amount: 0,
          credit_amount: creditApplied,
          status: 'pending',
          voucher_id: voucherId,
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
        package_purchase_id: pkg.id,
        group_seat_id: null,
        subscription_id: null,
        credit_amount: creditApplied,
      },
      { paid: true, newStatus: 'settlement', bookingStatus: 'confirmed' },
      { method: CREDIT_METHOD },
    )
    if (!applied.ok) {
      return json({ error: 'Gagal menyelesaikan paket dengan poin' }, 502)
    }
    return json({
      order_id: orderId,
      package_id: pkg.id,
      amount: 0,
      discount,
      credit_applied: creditApplied,
      paid: true,
      reused: false,
    })
  }

  const { data: student } = await admin.from('students').select('full_name').eq('id', uid).maybeSingle()

  let qris: Qris
  try {
    qris = await createQris(
      orderId,
      amount,
      `Paket ${pkg.total_sesi} pertemuan · ${pkg.jenjang} · ${pkg.duration_minutes} menit`,
      { first_name: student?.full_name ?? 'Siswa', email: userData.user.email ?? undefined },
    )
  } catch (e) {
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
        voucher_id: voucherId,
        raw: qris,
      })
      .eq('order_id', orderId)
  } else {
    const { error: payErr } = await admin.from('payments').insert({
      order_id: orderId,
      type: 'package',
      package_purchase_id: pkg.id,
      amount,
      credit_amount: creditApplied,
      status: 'pending',
      voucher_id: voucherId,
      raw: qris,
    })
    if (payErr) return json({ error: payErr.message }, 400)
  }

  return json({
    order_id: orderId,
    package_id: pkg.id,
    ...qrisFields(qris),
    amount,
    discount,
    credit_applied: creditApplied,
    paid: false,
    reused: false,
  })
})

/// Hari dalam seminggu (0 = Minggu) dari string YYYY-MM-DD, tanpa efek zona waktu.
function utcDayOfWeek(isoDate: string): number {
  const [y, m, d] = isoDate.split('-').map(Number)
  return new Date(Date.UTC(y, m - 1, d)).getUTCDay()
}
