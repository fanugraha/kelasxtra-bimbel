import { supabase } from './supabase'

export async function invokeFn<T>(
  name: string,
  body: Record<string, unknown>,
): Promise<{ data: T | null; error: string | null }> {
  const { data, error } = await supabase.functions.invoke(name, { body })
  if (error) {
    const detail = await (error as { context?: Response }).context?.json?.().catch(() => null)
    return { data: null, error: detail?.error ?? error.message }
  }
  return { data: data as T, error: null }
}
