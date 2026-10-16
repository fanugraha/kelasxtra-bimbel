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

// Publik (dipanggil dari link undangan). Tanpa JWT.
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })
  if (req.method !== 'POST') return json({ error: 'Metode tidak diizinkan' }, 405)

  const admin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )

  let body: Record<string, string | undefined>
  try {
    body = await req.json()
  } catch {
    return json({ error: 'Body tidak valid' }, 400)
  }

  const token = body.token?.trim()
  const password = body.password ?? ''
  if (!token) return json({ error: 'Token wajib' }, 400)
  if (password.length < 6) return json({ error: 'Kata sandi minimal 6 karakter' }, 400)

  const { data: tutor } = await admin
    .from('tutors')
    .select('id, status, invite_expires_at, full_name')
    .eq('invite_token', token)
    .maybeSingle()

  if (!tutor) return json({ error: 'Undangan tidak ditemukan' }, 404)
  if (tutor.status !== 'diundang') return json({ error: 'Undangan sudah dipakai' }, 409)
  if (tutor.invite_expires_at && new Date(tutor.invite_expires_at) < new Date()) {
    return json({ error: 'Undangan kedaluwarsa' }, 410)
  }

  // 1) Tetapkan kata sandi akun.
  const { error: pwErr } = await admin.auth.admin.updateUserById(tutor.id, { password })
  if (pwErr) return json({ error: pwErr.message }, 400)

  // 2) Lengkapi profil tutor + aktifkan.
  const patch: Record<string, unknown> = {
    status: 'aktif',
    activated_at: new Date().toISOString(),
    invite_token: null,
    invite_expires_at: null,
  }
  for (const key of ['bio', 'education', 'photo_url', 'bank_name', 'bank_account_number', 'bank_account_holder']) {
    if (body[key]) patch[key] = body[key]
  }

  const { error: updErr } = await admin.from('tutors').update(patch).eq('id', tutor.id)
  if (updErr) return json({ error: updErr.message }, 400)

  if (body.full_name || body.phone) {
    await admin
      .from('profiles')
      .update({ full_name: body.full_name ?? undefined, phone: body.phone ?? undefined })
      .eq('id', tutor.id)
  }

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
