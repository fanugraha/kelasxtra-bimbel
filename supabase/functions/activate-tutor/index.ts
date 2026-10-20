import { createClient } from 'npm:@supabase/supabase-js@2'
import { secretKey } from '../_shared/keys.ts'

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

const OTP_TTL_MINUTES = 10
const OTP_COOLDOWN_SECONDS = 60
const OTP_MAX_ATTEMPTS = 5

type TutorInvite = {
  id: string
  status: string
  full_name: string
  invite_expires_at: string | null
  invite_otp_hash: string | null
  invite_otp_expires_at: string | null
  invite_otp_attempts: number | null
  invite_otp_sent_at: string | null
}

function maskEmail(email: string) {
  const [local, domain] = email.split('@')
  if (!local || !domain) return email
  return `${local.slice(0, 1)}***@${domain}`
}

async function hashOtp(token: string, otp: string) {
  const input = new TextEncoder().encode(`${token}:${otp}`)
  const digest = await crypto.subtle.digest('SHA-256', input)
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('')
}

function equalHash(a: string, b: string) {
  if (a.length !== b.length) return false
  let diff = 0
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i)
  return diff === 0
}

async function sendOtpEmail(email: string, fullName: string, otp: string) {
  const resendKey = Deno.env.get('RESEND_API_KEY')
  const from = Deno.env.get('EMAIL_FROM')
  if (!resendKey || !from) return { ok: false, error: 'Email belum dikonfigurasi' }

  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${resendKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from,
      to: email,
      subject: 'Kode verifikasi aktivasi tutor Kelasxtra',
      html: `<p>Halo ${fullName},</p>
<p>Kode verifikasi untuk mengaktifkan akun tutor Kelasxtra:</p>
<p style="font-size:28px;font-weight:700;letter-spacing:6px">${otp}</p>
<p>Kode berlaku ${OTP_TTL_MINUTES} menit. Jangan bagikan kode ini kepada siapa pun.</p>`,
    }),
  })
  if (!res.ok) {
    console.error('resend failed', res.status, (await res.text()).slice(0, 300))
    return { ok: false, error: 'Gagal mengirim email' }
  }
  return { ok: true }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })
  if (req.method !== 'POST') return json({ error: 'Metode tidak diizinkan' }, 405)

  const admin = createClient(Deno.env.get('SUPABASE_URL')!, secretKey())

  let body: Record<string, string | undefined>
  try {
    body = await req.json()
  } catch {
    return json({ error: 'Body tidak valid' }, 400)
  }

  const token = body.token?.trim()
  if (!token) return json({ error: 'Token wajib' }, 400)

  const action = body.action ?? 'activate'

  const { data: tutor, error: tutorErr } = await admin
    .from('tutors')
    .select(
      'id, status, full_name, invite_expires_at, invite_otp_hash, invite_otp_expires_at, invite_otp_attempts, invite_otp_sent_at',
    )
    .eq('invite_token', token)
    .maybeSingle<TutorInvite>()

  if (tutorErr) return json({ error: 'Gagal memeriksa undangan' }, 500)
  if (!tutor) return json({ error: 'Undangan tidak ditemukan' }, 404)
  if (tutor.status !== 'diundang') return json({ error: 'Undangan sudah dipakai' }, 409)
  if (tutor.invite_expires_at && new Date(tutor.invite_expires_at) < new Date()) {
    return json({ error: 'Undangan kedaluwarsa' }, 410)
  }

  if (action === 'request_otp') {
    const lastSent = tutor.invite_otp_sent_at
      ? new Date(tutor.invite_otp_sent_at).getTime()
      : 0
    if (lastSent && Date.now() - lastSent < OTP_COOLDOWN_SECONDS * 1000) {
      return json({ error: 'Tunggu sebentar sebelum meminta kode lagi' }, 429)
    }

    const { data: authUser, error: userErr } = await admin.auth.admin.getUserById(tutor.id)
    const email = authUser.user?.email
    if (userErr || !email) return json({ error: 'Email tutor tidak ditemukan' }, 500)

    const otp = String(crypto.getRandomValues(new Uint32Array(1))[0] % 1_000_000).padStart(6, '0')
    const otpHash = await hashOtp(token, otp)
    const now = new Date()
    const { data: updated, error: updErr } = await admin
      .from('tutors')
      .update({
        invite_otp_hash: otpHash,
        invite_otp_expires_at: new Date(
          now.getTime() + OTP_TTL_MINUTES * 60_000,
        ).toISOString(),
        invite_otp_attempts: 0,
        invite_otp_sent_at: now.toISOString(),
      })
      .eq('id', tutor.id)
      .eq('status', 'diundang')
      .select('id')

    if (updErr) return json({ error: 'Gagal membuat kode verifikasi' }, 500)
    if (!updated || updated.length === 0) return json({ error: 'Undangan sudah dipakai' }, 409)

    const sent = await sendOtpEmail(email, tutor.full_name, otp)
    if (!sent.ok) {
      await admin
        .from('tutors')
        .update({
          invite_otp_hash: null,
          invite_otp_expires_at: null,
          invite_otp_sent_at: null,
        })
        .eq('id', tutor.id)
      return json({ error: 'Kode gagal dikirim. Hubungi admin.' }, 502)
    }

    return json({ ok: true, email_hint: maskEmail(email) })
  }

  if (action !== 'activate') return json({ error: 'action tidak dikenal' }, 400)

  const password = body.password ?? ''
  const otp = body.otp?.trim() ?? ''
  if (password.length < 6) return json({ error: 'Kata sandi minimal 6 karakter' }, 400)
  if (!/^\d{6}$/.test(otp)) return json({ error: 'Kode verifikasi wajib 6 digit' }, 400)
  if (!tutor.invite_otp_hash || !tutor.invite_otp_expires_at) {
    return json({ error: 'Minta kode verifikasi terlebih dahulu' }, 400)
  }
  if (new Date(tutor.invite_otp_expires_at) < new Date()) {
    return json({ error: 'Kode verifikasi kedaluwarsa. Minta kode baru.' }, 410)
  }

  const otpHash = await hashOtp(token, otp)
  if (!equalHash(otpHash, tutor.invite_otp_hash)) {
    const attempts = (tutor.invite_otp_attempts ?? 0) + 1
    const patch =
      attempts >= OTP_MAX_ATTEMPTS
        ? {
            invite_otp_hash: null,
            invite_otp_expires_at: null,
            invite_otp_sent_at: null,
            invite_otp_attempts: 0,
          }
        : { invite_otp_attempts: attempts }
    await admin.from('tutors').update(patch).eq('id', tutor.id).eq('status', 'diundang')
    return json({ error: 'Kode verifikasi salah atau kedaluwarsa' }, 400)
  }

  // Kunci undangan lebih dulu supaya dua permintaan bersamaan tidak sama-sama aktif.
  const activatedAt = new Date().toISOString()
  const { data: claimed, error: claimErr } = await admin
    .from('tutors')
    .update({
      status: 'aktif',
      activated_at: activatedAt,
      invite_token: null,
      invite_expires_at: null,
      invite_otp_hash: null,
      invite_otp_expires_at: null,
      invite_otp_attempts: 0,
      invite_otp_sent_at: null,
    })
    .eq('id', tutor.id)
    .eq('status', 'diundang')
    .eq('invite_otp_hash', otpHash)
    .select('id')

  if (claimErr) return json({ error: 'Gagal mengaktifkan akun' }, 500)
  if (!claimed || claimed.length === 0) return json({ error: 'Undangan sudah dipakai' }, 409)

  const { error: pwErr } = await admin.auth.admin.updateUserById(tutor.id, { password })
  if (pwErr) {
    await admin
      .from('tutors')
      .update({
        status: 'diundang',
        activated_at: null,
        invite_token: token,
        invite_expires_at: tutor.invite_expires_at,
      })
      .eq('id', tutor.id)
    return json({ error: pwErr.message }, 400)
  }

  const patch: Record<string, unknown> = {}
  for (const key of [
    'bio',
    'education',
    'photo_url',
    'bank_name',
    'bank_account_number',
    'bank_account_holder',
  ]) {
    if (body[key]) patch[key] = body[key]
  }
  if (Object.keys(patch).length > 0) {
    const { error: updErr } = await admin.from('tutors').update(patch).eq('id', tutor.id)
    if (updErr) console.error('tutor profile update failed', updErr.message)
  }

  const { error: profileErr } = await admin
    .from('profiles')
    .update({
      role: 'tutor',
      full_name: body.full_name ?? undefined,
      phone: body.phone ?? undefined,
    })
    .eq('id', tutor.id)
  if (profileErr) console.error('profile update failed', profileErr.message)

  await admin.from('audit_logs').insert({
    actor_id: tutor.id,
    action: 'tutor.activate',
    entity: 'tutors',
    entity_id: tutor.id,
    before_data: { status: 'diundang' },
    after_data: { status: 'aktif' },
  })

  return json({ ok: true })
})
