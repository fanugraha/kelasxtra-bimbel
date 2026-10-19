import { isoDate } from '../../lib/format'

export interface Period {
  id: string
  period_start: string
  period_end: string
  status: string
  created_at: string
  approved_at: string | null
  paid_at: string | null
}

export interface Payout {
  id: string
  period_id: string
  amount: number
  status: string
  bank_name: string | null
  bank_account_number: string | null
  bank_account_holder: string | null
  transfer_ref: string | null
  tutors: { full_name: string } | null
  payroll_periods: { period_start: string; period_end: string; status: string } | null
}

export interface PeriodStat {
  count: number
  total: number
}

export const STATUS_META: Record<string, { label: string; tone: string }> = {
  draft: { label: 'Menunggu persetujuan', tone: 'warning' },
  approved: { label: 'Menunggu transfer', tone: 'info' },
  paid: { label: 'Selesai', tone: 'success' },
}

export function defaultPeriod() {
  const now = new Date()
  const start = new Date(now.getFullYear(), now.getMonth() - 1, 26)
  const end = new Date(now.getFullYear(), now.getMonth(), 25)
  return { start: isoDate(start), end: isoDate(end) }
}
