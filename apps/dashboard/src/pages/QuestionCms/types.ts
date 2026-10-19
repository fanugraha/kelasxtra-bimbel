export interface Option { id: string; name: string }
export interface Topic extends Option { subject_id: string; jenjang: string | null }

export interface QuestionRow {
  id: string
  subject_id: string
  topic_id: string | null
  jenjang: string
  type: 'pg' | 'isian'
  status: string
  current_version: number
  updated_at: string
  body: string | null
  options: { key: string; text: string }[] | null
  answer: string | null
  explanation: string | null
  image_url: string | null
  subject_name: string | null
  topic_name: string | null
}

export interface VersionRow {
  version: number
  body: string
  created_at: string
}

export const STATUS_LABEL: Record<string, string> = {
  draft: 'Draf',
  review: 'Review',
  published: 'Tayang',
  archived: 'Arsip',
}

export const STATUS_TONE: Record<string, string> = {
  draft: 'neutral',
  review: 'warning',
  published: 'success',
  archived: 'neutral',
}

export const emptyForm = {
  id: '',
  subject: '',
  topic: '',
  jenjang: 'SMA',
  type: 'pg' as 'pg' | 'isian',
  body: '',
  options: [
    { key: 'A', text: '' },
    { key: 'B', text: '' },
    { key: 'C', text: '' },
    { key: 'D', text: '' },
  ],
  answer: 'A',
  explanation: '',
  image: '',
}

export type QuestionFormState = typeof emptyForm
