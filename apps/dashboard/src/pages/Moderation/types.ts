export interface FlagRow {
  id: string
  actor_id: string | null
  context: string
  matched: string | null
  excerpt: string | null
  created_at: string
  reviewed_at: string | null
  note: string | null
  ref_table: string | null
  ref_id: string | null
  actor: { id: string; full_name: string | null; role: string | null } | null
  reviewer: { full_name: string | null } | null
}

export interface TranscriptMessage {
  id: string
  sender_id: string
  body: string
  created_at: string
  flagged: boolean
}

export const ROLE_LABEL: Record<string, string> = {
  student: 'Siswa',
  tutor: 'Tutor',
  admin: 'Admin',
}

export const CONTEXT_LABEL: Record<string, string> = {
  'conversation_messages.body': 'Chat',
  'thread_messages.body': 'Chat per sesi (lama)',
  'reviews.comment': 'Ulasan',
  'complaints.body': 'Komplain',
  'session_notes.material': 'Catatan sesi',
  'session_notes.progress': 'Catatan sesi',
  'tutors.bio': 'Profil tutor',
}

export const FILTERS: { value: string; label: string }[] = [
  { value: 'open', label: 'Belum ditinjau' },
  { value: 'all', label: 'Semua' },
]
