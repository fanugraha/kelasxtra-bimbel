import { createClient } from 'npm:@supabase/supabase-js@2'
import { cors, createSnap, json, LOCK_MINUTES } from '../_shared/midtrans.ts'

const DISCOUNT_BY_SESSIONS: Record<number, number> = { 4: 0, 8: 5, 12: 10 }

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
  if (profile?.role !== 'student') return json({ error: 'Hanya siswa yang bisa membeli paket' }, 403)

  let body: {
    tutor_id?: string
    subject_id?: string
    jenjang?: string
    duration_minutes?: number
    mode?: string
    total_sesi?: number
  }
  try {
    body = await req.json()
  } catch {
    return json({ error: 'Body tidak valid' }, 400)
  }

  const { tutor_id: tutorId, subject_id: subjectId, jenjang } = body
  const duration = body.duration_minutes
  const mode = body.mode
  const totalSesi = body.total_sesi
  if (!tutorId || !subjectId || !jenjang || !duration || !mode || !totalSesi) {
    return json({ error: 'tutor_id, subject_id, jenjang, duration_minutes, mode, total_sesi wajib' }, 400)
  }
  if (![60, 90, 120].includes(duration)) return json({ error: 'duration_minutes tidak valid' }, 400)
  if (mode !== 'online' && mode !== 'offline') return json({ error: 'mode tidak valid' }, 400)
  if (![4, 8, 12].includes(totalSesi)) return json({ error: 'total_sesi harus 4, 8, atau 12' }, 400)

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

  const pricePerSession = priceRow.price as number
  const discountPercent = DISCOUNT_BY_SESSIONS[totalSesi]
  const priceTotal = Math.floor((pricePerSession * totalSesi * (100 - discountPercent)) / 100)

  // Pakai ulang paket pending yang lock-nya masih hidup (idempoten).
  const { data: existing } = await admin
    .from('package_purchases')
    .select('id')
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

  let packageId: string
  let orderId: string
  let createdNow = false

  if (existing) {
    packageId = existing.id
    orderId = `PKG-${packageId}`
    const { data: pay } = await admin
      .from('payments')
      .select('raw')
      .eq('order_id', orderId)
      .eq('status', 'pending')
      .maybeSingle()
    const cached = pay?.raw as { snap_token?: string; snap_redirect_url?: string } | null
    if (cached?.snap_redirect_url) {
      return json({
        order_id: orderId,
        package_id: packageId,
        snap_token: cached.snap_token,
        redirect_url: cached.snap_redirect_url,
        amount: priceTotal,
        reused: true,
      })
    }
  } else {
    const { data: pkg, error: pErr } = await admin
      .from('package_purchases')
      .insert({
        student_id: uid,
        tutor_id: tutorId,
        subject_id: subjectId,
        jenjang,
        duration_minutes: duration,
        mode,
        total_sesi: totalSesi,
        price_per_session: pricePerSession,
        discount_percent: discountPercent,
        price_total: priceTotal,
        status: 'pending_payment',
        lock_expires_at: new Date(Date.now() + LOCK_MINUTES * 60_000).toISOString(),
      })
      .select('id')
      .single()
    if (pErr || !pkg) return json({ error: pErr?.message ?? 'Gagal membuat paket' }, 400)
    packageId = pkg.id
    orderId = `PKG-${packageId}`
    createdNow = true
  }

  const { data: student } = await admin
    .from('students')
    .select('full_name')
    .eq('id', uid)
    .maybeSingle()

  let snap: { token: string; redirect_url: string }
  try {
    snap = await createSnap(
      orderId,
      priceTotal,
      `Paket ${totalSesi} sesi · ${jenjang} · ${duration} menit`,
      { first_name: student?.full_name ?? 'Siswa', email: userData.user.email ?? undefined },
    )
  } catch (e) {
    if (createdNow) {
      await admin.from('package_purchases').delete().eq('id', packageId)
    }
    return json({ error: (e as Error).message }, 502)
  }

  // Payment dibuat setelah Snap berhasil (agar tidak ada payment yatim bila Snap gagal).
  const { data: existingPay } = await admin
    .from('payments')
    .select('id')
    .eq('order_id', orderId)
    .maybeSingle()
  if (existingPay) {
    await admin
      .from('payments')
      .update({ amount: priceTotal, raw: { snap_token: snap.token, snap_redirect_url: snap.redirect_url } })
      .eq('order_id', orderId)
  } else {
    const { error: payErr } = await admin.from('payments').insert({
      order_id: orderId,
      type: 'package',
      package_purchase_id: packageId,
      amount: priceTotal,
      status: 'pending',
      raw: { snap_token: snap.token, snap_redirect_url: snap.redirect_url },
    })
    if (payErr) return json({ error: payErr.message }, 400)
  }

  return json({
    order_id: orderId,
    package_id: packageId,
    snap_token: snap.token,
    redirect_url: snap.redirect_url,
    amount: priceTotal,
    reused: false,
  })
})
