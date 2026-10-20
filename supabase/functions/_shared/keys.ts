type KeyMap = Record<string, string>

function parseKeyMap(name: string): KeyMap {
  const raw = Deno.env.get(name)
  if (!raw) return {}
  try {
    const parsed = JSON.parse(raw)
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) return {}
    return parsed as KeyMap
  } catch {
    return {}
  }
}

export function secretKey(name = 'default'): string {
  const key = parseKeyMap('SUPABASE_SECRET_KEYS')[name]
  return key || Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || ''
}

export function publishableKey(name = 'default'): string {
  const key = parseKeyMap('SUPABASE_PUBLISHABLE_KEYS')[name]
  return key || Deno.env.get('SUPABASE_ANON_KEY') || ''
}
