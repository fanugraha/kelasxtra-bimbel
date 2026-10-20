import { createClient } from 'npm:@supabase/supabase-js@2'
import { publishableKey, secretKey } from '../_shared/keys.ts'

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

const INVITE_TTL_DAYS = 7

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })
  if (req.method !== 'POST') return json({ error: 'Metode tidak diizinkan' }, 405)

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!
  const serviceKey = secretKey()
  const authHeader = req.headers.get('Authorization') ?? ''

  const admin = createClient(supabaseUrl, serviceKey)

  // Identifikasi pemanggil dari JWT-nya.
  const caller = createClient(supabaseUrl, publishableKey(), {
    global: { headers: { Authorization: authHeader } },
  })
  const { data: userData, error: userErr } = await caller.auth.getUser()
  if (userErr || !userData.user) return json({ error: 'Tidak terautentikasi' }, 401)

  const { data: profile } = await admin
    .from('profiles')
    .select('role')
    .eq('id', userData.user.id)
    .single()
  if (profile?.role !== 'admin') return json({ error: 'Hanya admin' }, 403)

  let payload: { email?: string; full_name?: string; phone?: string }
  try {
    payload = await req.json()
  } catch {
    return json({ error: 'Body tidak valid' }, 400)
  }
  const email = payload.email?.trim().toLowerCase()
  const fullName = payload.full_name?.trim()
  if (!email || !fullName) return json({ error: 'email dan full_name wajib' }, 400)

  const token = crypto.randomUUID()
  const expiresAt = new Date(Date.now() + INVITE_TTL_DAYS * 86_400_000).toISOString()

  // 1) Buat akun auth tutor (password acak; tutor menetapkannya saat aktivasi).
  const { data: created, error: createErr } = await admin.auth.admin.createUser({
    email,
    password: crypto.randomUUID() + 'Aa1!',
    email_confirm: true,
    user_metadata: { full_name: fullName, phone: payload.phone ?? null },
  })
  if (createErr || !created.user) {
    return json({ error: createErr?.message ?? 'Gagal membuat akun' }, 400)
  }
  const tutorId = created.user.id

  // 2) Trigger signup membuat profil siswa; alur server ini menaikkannya ke tutor.
  const { error: profileErr } = await admin.from('profiles').upsert({
    id: tutorId,
    role: 'tutor',
    admin_role: null,
    full_name: fullName,
    phone: payload.phone ?? null,
  })
  if (profileErr) {
    await admin.auth.admin.deleteUser(tutorId)
    return json({ error: profileErr.message }, 400)
  }

  // 3) Baris tutors (status diundang + token).
  const { error: upsertErr } = await admin.from('tutors').upsert({
    id: tutorId,
    status: 'diundang',
    full_name: fullName,
    invite_token: token,
    invite_expires_at: expiresAt,
    invited_at: new Date().toISOString(),
  })
  if (upsertErr) {
    await admin.auth.admin.deleteUser(tutorId)
    return json({ error: upsertErr.message }, 400)
  }

  // 4) Link aktivasi (bisa deep link app atau halaman web).
  const base = Deno.env.get('ACTIVATION_BASE_URL') ?? 'http://localhost:5173/activate'
  const activationLink = `${base}${base.includes('?') ? '&' : '?'}token=${token}`

  // 5) Kirim email bila Resend dikonfigurasi.
  let emailSent = false
  let emailError: string | null = null
  const resendKey = Deno.env.get('RESEND_API_KEY')
  const from = Deno.env.get('EMAIL_FROM')
  if (!resendKey || !from) {
    emailError = 'RESEND_API_KEY / EMAIL_FROM belum diset'
  } else {
    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${resendKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from,
        to: email,
        subject: 'Undangan menjadi tutor Kelasxtra',
        html: `<p>Halo ${fullName},</p>
<p>Kamu diundang bergabung sebagai tutor Kelasxtra. Buka tautan berikut (berlaku ${INVITE_TTL_DAYS} hari), lalu minta kode verifikasi yang akan dikirim ke email ini:</p>
<p><a href="${activationLink}">Aktifkan akun tutor</a></p>
<p>Atau salin tautan ini: ${activationLink}</p>
<p>Jangan teruskan tautan ini ke orang lain.</p>`,
      }),
    })
    emailSent = res.ok
    if (!res.ok) emailError = (await res.text()).slice(0, 300)
  }

  // 6) Audit log.
  await admin.from('audit_logs').insert({
    actor_id: userData.user.id,
    action: 'tutor.invite',
    entity: 'tutors',
    entity_id: tutorId,
    after_data: { email, status: 'diundang', invite_expires_at: expiresAt },
  })

  return json({ tutor_id: tutorId, activation_link: activationLink, email_sent: emailSent, email_error: emailError })
})
