import { createClient } from 'npm:@supabase/supabase-js@2'

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

const LOCK_MINUTES = 30

function snapBase() {
  return Deno.env.get('MIDTRANS_IS_SANDBOX') === 'true'
    ? 'https://app.sandbox.midtrans.com'
    : 'https://app.midtrans.com'
}

async function createSnap(
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
    .select('id')
    .eq('student_id', uid)
    .eq('tutor_id', tutorId)
    .eq('scheduled_at', scheduledIso)
    .eq('status', 'pending_payment')
    .gt('lock_expires_at', nowIso)
    .maybeSingle()

  let bookingId: string
  let orderId: string
  let amount: number

  if (existing) {
    bookingId = existing.id
    const { data: pay } = await admin
      .from('payments')
      .select('order_id, amount, raw')
      .eq('booking_id', bookingId)
      .eq('status', 'pending')
      .maybeSingle()
    orderId = pay?.order_id ?? `BK-${bookingId}`
    amount = pay?.amount ?? priceRow.price
    const cached = pay?.raw as { snap_token?: string; snap_redirect_url?: string } | null
    if (cached?.snap_redirect_url) {
      return json({
        order_id: orderId,
        booking_id: bookingId,
        snap_token: cached.snap_token,
        redirect_url: cached.snap_redirect_url,
        amount,
        reused: true,
      })
    }
    if (!pay) {
      const { error } = await admin.from('payments').insert({
        order_id: orderId,
        type: 'booking',
        booking_id: bookingId,
        amount,
        status: 'pending',
      })
      if (error) return json({ error: error.message }, 400)
    }
  } else {
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
        discount: 0,
        status: 'pending_payment',
        address: mode === 'offline' ? (body.address?.trim() || null) : null,
        lock_expires_at: new Date(Date.now() + LOCK_MINUTES * 60_000).toISOString(),
      })
      .select('id')
      .single()
    if (bErr || !booking) return json({ error: bErr?.message ?? 'Gagal membuat booking' }, 400)
    bookingId = booking.id
    orderId = `BK-${bookingId}`
    amount = priceRow.price
    const { error: pErr } = await admin.from('payments').insert({
      order_id: orderId,
      type: 'booking',
      booking_id: bookingId,
      amount,
      status: 'pending',
    })
    if (pErr) return json({ error: pErr.message }, 400)
  }

  const { data: student } = await admin
    .from('students')
    .select('full_name')
    .eq('id', uid)
    .maybeSingle()

  let snap: { token: string; redirect_url: string }
  try {
    snap = await createSnap(orderId, amount, `${jenjang} · ${duration} menit · ${mode}`, {
      first_name: student?.full_name ?? 'Siswa',
      email: userData.user.email ?? undefined,
    })
  } catch (e) {
    return json({ error: (e as Error).message }, 502)
  }

  await admin
    .from('payments')
    .update({ raw: { snap_token: snap.token, snap_redirect_url: snap.redirect_url } })
    .eq('order_id', orderId)

  return json({
    order_id: orderId,
    booking_id: bookingId,
    snap_token: snap.token,
    redirect_url: snap.redirect_url,
    amount,
    reused: false,
  })
})
