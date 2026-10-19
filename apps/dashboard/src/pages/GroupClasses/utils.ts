import type { GroupClass } from './types'

export const fullDate = (iso?: string) =>
  iso
    ? new Intl.DateTimeFormat('id-ID', {
        dateStyle: 'medium',
        timeStyle: 'short',
        timeZone: 'Asia/Jakarta',
      }).format(new Date(iso))
    : '—'

export function relative(iso: string) {
  const days = Math.ceil((new Date(iso).getTime() - Date.now()) / 86_400_000)
  if (days < 0) return 'terlewat'
  if (days === 0) return 'hari ini'
  if (days === 1) return 'besok'
  return `${days} hari lagi`
}

export function sessionRange(row: GroupClass) {
  const sorted = [...(row.group_sessions ?? [])].sort((a, b) => a.seq - b.seq)
  return { first: sorted[0]?.scheduled_at, last: sorted[sorted.length - 1]?.scheduled_at }
}
