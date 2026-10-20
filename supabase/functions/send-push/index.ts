// Kirim antrean `notifications` ke FCM HTTP v1.
// Butuh env:
//   FIREBASE_SERVICE_ACCOUNT = isi JSON service account (satu baris)
//   PUSH_CRON_SECRET         = string rahasia; panggil dengan header x-cron-secret
//
// Panggil berkala (pg_cron + pg_net atau scheduler eksternal):
//   curl -X POST .../functions/v1/send-push -H "x-cron-secret: ..."
import { createClient } from 'npm:@supabase/supabase-js@2'
import { secretKey } from '../_shared/keys.ts'

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })

type ServiceAccount = {
  project_id: string
  client_email: string
  private_key: string
}

const b64url = (bytes: Uint8Array | string) => {
  const raw = typeof bytes === 'string' ? new TextEncoder().encode(bytes) : bytes
  let bin = ''
  for (const b of raw) bin += String.fromCharCode(b)
  return btoa(bin).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '')
}

async function accessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  const header = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))
  const claims = b64url(
    JSON.stringify({
      iss: sa.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    }),
  )
  const unsigned = `${header}.${claims}`

  const pem = sa.private_key.replaceAll('\\n', '\n')
  const der = Uint8Array.from(
    atob(pem.replace(/-----[^-]+-----/g, '').replaceAll(/\s/g, '')),
    (c) => c.charCodeAt(0),
  )
  const key = await crypto.subtle.importKey(
    'pkcs8',
    der,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  const sig = new Uint8Array(
    await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(unsigned)),
  )
  const assertion = `${unsigned}.${b64url(sig)}`

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  })
  const data = await res.json()
  if (!res.ok) throw new Error(data.error_description ?? 'Gagal ambil token FCM')
  return data.access_token as string
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json({ error: 'Metode tidak diizinkan' }, 405)

  const secret = Deno.env.get('PUSH_CRON_SECRET')
  const rawSa = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')
  if (!secret || !rawSa) {
    return json({ error: 'PUSH_CRON_SECRET / FIREBASE_SERVICE_ACCOUNT belum diset' }, 503)
  }
  if (req.headers.get('x-cron-secret') !== secret) {
    return json({ error: 'Tidak sah' }, 401)
  }

  let sa: ServiceAccount
  try {
    sa = JSON.parse(rawSa)
  } catch {
    return json({ error: 'FIREBASE_SERVICE_ACCOUNT bukan JSON valid' }, 500)
  }

  const admin = createClient(Deno.env.get('SUPABASE_URL')!, secretKey())

  const { data: pending, error } = await admin
    .from('notifications')
    .select('id, user_id, title, body, data')
    .eq('status', 'pending')
    .order('created_at')
    .limit(50)
  if (error) return json({ error: error.message }, 500)
  if (!pending || pending.length === 0) return json({ ok: true, sent: 0 })

  let token: string
  try {
    token = await accessToken(sa)
  } catch (e) {
    return json({ error: String(e) }, 500)
  }

  let sent = 0
  let failed = 0

  for (const n of pending) {
    const { data: devices } = await admin
      .from('device_tokens')
      .select('token')
      .eq('user_id', n.user_id)

    if (!devices || devices.length === 0) {
      await admin
        .from('notifications')
        .update({ status: 'failed', error: 'Tidak ada device token' })
        .eq('id', n.id)
      failed++
      continue
    }

    let ok = true
    let lastError: string | null = null
    for (const d of devices) {
      const res = await fetch(
        `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`,
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${token}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            message: {
              token: d.token,
              notification: { title: n.title, body: n.body },
              data: Object.fromEntries(
                Object.entries(n.data ?? {}).map(([k, v]) => [k, String(v)]),
              ),
            },
          }),
        },
      )
      if (!res.ok) {
        ok = false
        lastError = await res.text()
      }
    }

    if (ok) {
      await admin
        .from('notifications')
        .update({ status: 'sent', sent_at: new Date().toISOString() })
        .eq('id', n.id)
      sent++
    } else {
      await admin
        .from('notifications')
        .update({ status: 'failed', error: lastError?.slice(0, 500) ?? 'Gagal kirim' })
        .eq('id', n.id)
      failed++
    }
  }

  return json({ ok: true, sent, failed })
})
