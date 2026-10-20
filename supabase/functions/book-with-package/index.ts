import { createClient } from 'npm:@supabase/supabase-js@2'
import { cors, json } from '../_shared/midtrans.ts'
import { publishableKey, secretKey } from '../_shared/keys.ts'

/// Membuat booking yang dibayar dengan kuota paket (tanpa pembayaran per sesi).
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })
  if (req.method !== 'POST') return json({ error: 'Metode tidak diizinkan' }, 405)

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!
  const serviceKey = secretKey()
  const admin = createClient(supabaseUrl, serviceKey)

  const caller = createClient(supabaseUrl, publishableKey(), {
    global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } },
  })
  const { data: userData, error: userErr } = await caller.auth.getUser()
  if (userErr || !userData.user) return json({ error: 'Tidak terautentikasi' }, 401)
  const uid = userData.user.id

  const { data: profile } = await admin.from('profiles').select('role').eq('id', uid).single()
  if (profile?.role !== 'student') return json({ error: 'Hanya siswa yang bisa booking' }, 403)

  let body: { package_id?: string; scheduled_at?: string; address?: string }
  try {
    body = await req.json()
  } catch {
    return json({ error: 'Body tidak valid' }, 400)
  }
  if (!body.package_id || !body.scheduled_at) {
    return json({ error: 'package_id dan scheduled_at wajib' }, 400)
  }

  const scheduled = new Date(body.scheduled_at)
  if (isNaN(scheduled.getTime())) return json({ error: 'scheduled_at tidak valid' }, 400)
  if (scheduled.getTime() < Date.now()) return json({ error: 'Jadwal sudah lewat' }, 400)

  const { data: pkg } = await admin
    .from('package_purchases')
    .select('id, student_id, tutor_id, subject_id, jenjang, duration_minutes, mode, price_per_session, status, expires_at')
    .eq('id', body.package_id)
    .maybeSingle()
  if (!pkg) return json({ error: 'Paket tidak ditemukan' }, 404)
  if (pkg.student_id !== uid) return json({ error: 'Paket bukan milikmu' }, 403)
  if (pkg.status !== 'active') return json({ error: 'Paket tidak aktif' }, 400)
  if (pkg.expires_at && scheduled.getTime() > new Date(pkg.expires_at).getTime()) {
    return json({ error: 'Jadwal melewati masa berlaku paket' }, 400)
  }

  const { data: tutor } = await admin.from('tutors').select('status').eq('id', pkg.tutor_id).maybeSingle()
  if (!tutor || tutor.status !== 'aktif') return json({ error: 'Tutor tidak aktif' }, 400)

  // Cegah slot dobel: satu siswa tidak boleh punya dua booking aktif di waktu yang sama.
  const { data: clash } = await admin
    .from('bookings')
    .select('id, status')
    .eq('student_id', uid)
    .eq('scheduled_at', scheduled.toISOString())
    .not('status', 'in', '(cancelled,expired,refunded)')
    .maybeSingle()
  if (clash) return json({ error: 'Kamu sudah punya sesi di waktu ini' }, 400)

  const { data: booking, error: bErr } = await admin
    .from('bookings')
    .insert({
      student_id: uid,
      tutor_id: pkg.tutor_id,
      subject_id: pkg.subject_id,
      jenjang: pkg.jenjang,
      duration_minutes: pkg.duration_minutes,
      mode: pkg.mode,
      type: 'privat',
      scheduled_at: scheduled.toISOString(),
      price: pkg.price_per_session,
      discount: pkg.price_per_session, // dibayar dengan kuota -> amount_due 0
      package_purchase_id: pkg.id,
      status: 'confirmed',
      address: pkg.mode === 'offline' ? (body.address?.trim() || null) : null,
    })
    .select('id')
    .single()
  if (bErr || !booking) return json({ error: bErr?.message ?? 'Gagal membuat booking' }, 400)

  try {
    const { data: sesi, error: cErr } = await admin.rpc('consume_package_session', {
      p_package_id: pkg.id,
      p_student: uid,
      p_tutor: pkg.tutor_id,
      p_subject: pkg.subject_id,
      p_jenjang: pkg.jenjang,
      p_duration: pkg.duration_minutes,
      p_mode: pkg.mode,
      p_booking_id: booking.id,
    })
    if (cErr) throw new Error(cErr.message)
    return json({ ok: true, booking_id: booking.id, sesi_terpakai: sesi })
  } catch (e) {
    await admin.from('bookings').delete().eq('id', booking.id)
    return json({ error: (e as Error).message }, 400)
  }
})
