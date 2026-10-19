/** Inisial 1–2 huruf dari nama atau email (mis. "Budi Santoso" → "BS"). */
export function initials(value: string) {
  const parts = value.replace(/@.*/, '').split(/[.\s_-]+/).filter(Boolean)
  const first = parts[0]?.[0] ?? 'A'
  const second = parts[1]?.[0] ?? ''
  return (first + second).toUpperCase()
}
