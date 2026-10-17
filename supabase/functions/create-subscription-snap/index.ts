import { createClient } from 'npm:@supabase/supabase-js@2'
import { cors, createSnap, json } from '../_shared/midtrans.ts'

/// Beli / perpanjang langganan bank soal (bulanan manual via Snap).
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
  if (profile?.role !== 'student') return json({ error: 'Hanya siswa' }, 403)

  let body: { plan_code?: string }
  try {
    body = await req.json()
  } catch {
    body = {}
  }
  const planCode = body.plan_code ?? 'bank_soal'

  const { data: plan } = await admin
    .from('subscription_plans')
    .select('code, name, price, period_days, grace_days, active')
    .eq('code', planCode)
    .maybeSingle()
  if (!plan || !plan.active) return json({ error: 'Paket langganan tidak tersedia' }, 400)

  // Pastikan ada baris langganan untuk siswa ini.
  let { data: sub } = await admin
    .from('subscriptions')
    .select('id, status')
    .eq('student_id', uid)
    .eq('plan_code', planCode)
    .maybeSingle()

  if (!sub) {
    const { data: created, error } = await admin
      .from('subscriptions')
      .insert({ student_id: uid, plan_code: planCode, status: 'pending' })
      .select('id, status')
      .single()
    if (error || !created) return json({ error: error?.message ?? 'Gagal membuat langganan' }, 400)
    sub = created
  }

  // Pakai ulang tagihan pending yang masih segar (idempoten 30 menit).
  const { data: pending } = await admin
    .from('payments')
    .select('order_id, raw')
    .eq('subscription_id', sub.id)
    .eq('status', 'pending')
    .gt('created_at', new Date(Date.now() - 30 * 60_000).toISOString())
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle()

  const cached = pending?.raw as { snap_token?: string; snap_redirect_url?: string } | null
  if (pending && cached?.snap_redirect_url) {
    return json({
      order_id: pending.order_id,
      subscription_id: sub.id,
      snap_token: cached.snap_token,
      redirect_url: cached.snap_redirect_url,
      amount: plan.price,
      reused: true,
    })
  }

  // Midtrans membatasi order_id <= 50 karakter.
  const orderId = `SUB-${sub.id.slice(0, 8)}-${Date.now().toString(36)}`
  const { data: student } = await admin
    .from('students')
    .select('full_name')
    .eq('id', uid)
    .maybeSingle()

  let snap: { token: string; redirect_url: string }
  try {
    snap = await createSnap(orderId, plan.price, `Langganan ${plan.name} (30 hari)`, {
      first_name: student?.full_name ?? 'Siswa',
      email: userData.user.email ?? undefined,
    })
  } catch (e) {
    return json({ error: (e as Error).message }, 502)
  }

  const { error: payErr } = await admin.from('payments').insert({
    order_id: orderId,
    type: 'subscription',
    subscription_id: sub.id,
    amount: plan.price,
    status: 'pending',
    raw: { snap_token: snap.token, snap_redirect_url: snap.redirect_url },
  })
  if (payErr) return json({ error: payErr.message }, 400)

  return json({
    order_id: orderId,
    subscription_id: sub.id,
    snap_token: snap.token,
    redirect_url: snap.redirect_url,
    amount: plan.price,
    reused: false,
  })
})
