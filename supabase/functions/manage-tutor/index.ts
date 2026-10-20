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
  const admin = createClient(supabaseUrl, secretKey())
  const authHeader = req.headers.get('Authorization') ?? ''

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

  let body: { tutor_id?: string; action?: string; reason?: string }
  try {
    body = await req.json()
  } catch {
    return json({ error: 'Body tidak valid' }, 400)
  }
  const { tutor_id: tutorId, action } = body
  if (!tutorId || !action) return json({ error: 'tutor_id dan action wajib' }, 400)

  const { data: tutor } = await admin
    .from('tutors')
    .select('id, status, full_name, invite_token')
    .eq('id', tutorId)
    .maybeSingle()
  if (!tutor) return json({ error: 'Tutor tidak ditemukan' }, 404)

  const now = new Date().toISOString()
  let patch: Record<string, unknown> = {}

  if (action === 'suspend') {
    if (tutor.status !== 'aktif') return json({ error: 'Tutor tidak aktif' }, 409)
    patch = { status: 'suspend', suspended_at: now, suspend_reason: body.reason ?? null }
    await admin.auth.admin.updateUserById(tutorId, { ban_duration: '876000h' })
  } else if (action === 'reactivate') {
    if (tutor.status !== 'suspend') return json({ error: 'Tutor tidak sedang suspend' }, 409)
    patch = { status: 'aktif', suspended_at: null, suspend_reason: null }
    await admin.auth.admin.updateUserById(tutorId, { ban_duration: 'none' })
  } else if (action === 'resend_invite') {
    if (tutor.status !== 'diundang') return json({ error: 'Tutor sudah aktivasi' }, 409)
    const token = crypto.randomUUID()
    patch = {
      invite_token: token,
      invite_expires_at: new Date(Date.now() + INVITE_TTL_DAYS * 86_400_000).toISOString(),
      invited_at: now,
      invite_otp_hash: null,
      invite_otp_expires_at: null,
      invite_otp_attempts: 0,
      invite_otp_sent_at: null,
    }
  } else {
    return json({ error: 'action tidak dikenal' }, 400)
  }

  const { error: updErr } = await admin.from('tutors').update(patch).eq('id', tutorId)
  if (updErr) return json({ error: updErr.message }, 400)

  await admin.from('audit_logs').insert({
    actor_id: userData.user.id,
    action: `tutor.${action}`,
    entity: 'tutors',
    entity_id: tutorId,
    before_data: { status: tutor.status },
    after_data: { status: patch.status ?? tutor.status, reason: body.reason ?? null },
  })

  const result: Record<string, unknown> = { ok: true }
  if (action === 'resend_invite') {
    const base = Deno.env.get('ACTIVATION_BASE_URL') ?? 'http://localhost:5173/activate'
    result.activation_link = `${base}${base.includes('?') ? '&' : '?'}token=${patch.invite_token}`
  }
  return json(result)
})
