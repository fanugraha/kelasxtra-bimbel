export interface Metrics {
  bookings: {
    total: number
    completed: number
    cancelled: number
    no_show: number
    disputed: number
    today: number
  }
  revenue: {
    gross: number
    gateway_fee: number
    refunds: number
    platform_share: number
    tutor_earnings: number
    tutor_unpaid: number
    tutor_paid: number
  }
  users: { students: number; subscriptions_active: number; tutors_active: number }
  ops: {
    in_progress: number
    complaints_open: number
    pending_bookings: number
    groups_open: number
  }
  tutors: {
    id: string
    full_name: string
    rating_avg: number
    completed: number
    cancelled: number
    no_show: number
    unpaid: number
  }[]
  students: {
    id: string
    full_name: string
    jenjang: string
    sessions: number
    attempts: number
  }[]
}

export interface BookingRow {
  id: string
  student_id: string
  tutor_id: string
  scheduled_at: string
  status: string
  studentName?: string
  tutorName?: string
}

export type TutorStat = Metrics['tutors'][number]
export type StudentStat = Metrics['students'][number]

export const STATUS_OPTIONS = [
  'confirmed',
  'in_progress',
  'completed',
  'no_show_tutor',
  'no_show_student',
  'cancelled',
  'refunded',
]

export const STATUS_META: Record<string, { label: string; tone: string }> = {
  pending_payment: { label: 'Menunggu bayar', tone: 'warning' },
  confirmed: { label: 'Terkonfirmasi', tone: 'success' },
  in_progress: { label: 'Berlangsung', tone: 'warning' },
  completed: { label: 'Selesai', tone: 'success' },
  cancelled: { label: 'Batal', tone: 'danger' },
  expired: { label: 'Kedaluwarsa', tone: 'neutral' },
  no_show_tutor: { label: 'Tutor tidak hadir', tone: 'danger' },
  no_show_student: { label: 'Siswa tidak hadir', tone: 'warning' },
  disputed: { label: 'Komplain', tone: 'danger' },
  refunded: { label: 'Dikembalikan', tone: 'neutral' },
  rescheduled: { label: 'Dijadwalkan ulang', tone: 'info' },
}

export type MonitoringFilter = 'attention' | 'all'
export type TutorSort = 'pay' | 'sessions' | 'name'
