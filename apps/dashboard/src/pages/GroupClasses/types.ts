export interface Option {
  id: string
  name: string
}

export interface GroupSession {
  seq: number
  scheduled_at: string
}

export interface GroupClass {
  id: string
  jenjang: string
  mode: string
  duration_minutes: number
  total_sesi: number
  discount_percent: number
  price_per_session: number
  price_total: number
  min_seats: number
  max_seats: number
  seats_taken: number
  status: string
  min_confirm_deadline: string
  tutors: { full_name: string } | null
  subjects: { name: string } | null
  rooms: { name: string } | null
  group_sessions: GroupSession[]
}

export interface Seat {
  id: string
  status: string
  price_paid: number
  refund_amount: number | null
  students: { full_name: string } | null
}

export const DAYS: { iso: number; label: string }[] = [
  { iso: 1, label: 'Sen' },
  { iso: 2, label: 'Sel' },
  { iso: 3, label: 'Rab' },
  { iso: 4, label: 'Kam' },
  { iso: 5, label: 'Jum' },
  { iso: 6, label: 'Sab' },
  { iso: 7, label: 'Min' },
]

export const STATUS_META: Record<string, { label: string; tone: string }> = {
  open: { label: 'Dibuka', tone: 'info' },
  confirmed: { label: 'Terkonfirmasi', tone: 'success' },
  cancelled: { label: 'Batal', tone: 'danger' },
  completed: { label: 'Selesai', tone: 'neutral' },
}

export const SEAT_META: Record<string, { label: string; tone: string }> = {
  pending_payment: { label: 'Menunggu bayar', tone: 'warning' },
  active: { label: 'Aktif', tone: 'success' },
  refund_pending: { label: 'Perlu poin', tone: 'danger' },
  refunded: { label: 'Dibatalkan (poin)', tone: 'neutral' },
  cancelled: { label: 'Batal', tone: 'neutral' },
}

export const emptyForm = {
  tutor: '',
  subject: '',
  jenjang: 'SMA',
  mode: 'offline',
  room: '',
  duration: 90,
  totalSesi: 8,
  days: [2, 4] as number[],
  startDate: '',
  time: '16:00',
}

export type GroupFormState = typeof emptyForm
export type GroupFilter = 'all' | 'attention'
export type GroupSort = 'fill' | 'due' | 'name'
