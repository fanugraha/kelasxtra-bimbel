import { createClient } from 'npm:@supabase/supabase-js@2'
import { cors, createSnap, json } from '../_shared/midtrans.ts'

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

  let body: { group_class_id?: string }
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
  let amount: number
  let createdNow = false

  if (existingSeat) {
    seatId = existingSeat.id as string
    amount = existingSeat.price_paid as number
    const orderId = `GS-${seatId}`
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
        seat_id: seatId,
        snap_token: cached.snap_token,
        redirect_url: cached.snap_redirect_url,
        amount,
        reused: true,
      })
    }
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
    amount = seatRow?.price_paid as number
  }

  const orderId = `GS-${seatId}`

  const { data: student } = await admin
    .from('students')
    .select('full_name')
    .eq('id', uid)
    .maybeSingle()

  let snap: { token: string; redirect_url: string }
  try {
    snap = await createSnap(
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
        raw: { snap_token: snap.token, snap_redirect_url: snap.redirect_url },
      })
      .eq('order_id', orderId)
  } else {
    const { error: pErr } = await admin.from('payments').insert({
      order_id: orderId,
      type: 'group_seat',
      group_seat_id: seatId,
      amount,
      status: 'pending',
      raw: { snap_token: snap.token, snap_redirect_url: snap.redirect_url },
    })
    if (pErr) return json({ error: pErr.message }, 400)
  }

  return json({
    order_id: orderId,
    seat_id: seatId,
    snap_token: snap.token,
    redirect_url: snap.redirect_url,
    amount,
    reused: false,
  })
})
