import { useEffect, useState } from 'react'
import type { FormEvent } from 'react'
import { supabase } from '../../lib/supabase'
import { QuestionForm } from './QuestionForm'
import { QuestionTable } from './QuestionTable'
import { emptyForm } from './types'
import type { Option, QuestionFormState, QuestionRow, Topic, VersionRow } from './types'

export function QuestionCms() {
  const [subjects, setSubjects] = useState<Option[]>([])
  const [topics, setTopics] = useState<Topic[]>([])
  const [rows, setRows] = useState<QuestionRow[]>([])
  const [form, setForm] = useState(emptyForm)
  const [busy, setBusy] = useState(false)
  const [notice, setNotice] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)
  const [filterSubject, setFilterSubject] = useState('')
  const [filterStatus, setFilterStatus] = useState('')
  const [versions, setVersions] = useState<Record<string, VersionRow[]>>({})
  const [openVersions, setOpenVersions] = useState<string | null>(null)
  const [signed, setSigned] = useState<Record<string, string>>({})
  const [showForm, setShowForm] = useState(false)

  async function load() {
    const [s, t, q] = await Promise.all([
      supabase.from('subjects').select('id, name').eq('active', true).order('name'),
      supabase.from('topics').select('id, name, subject_id, jenjang').eq('active', true).order('name'),
      supabase.from('questions_admin').select('*').order('updated_at', { ascending: false }).limit(100),
    ])
    setSubjects((s.data as Option[]) ?? [])
    setTopics((t.data as unknown as Topic[]) ?? [])
    setRows((q.data as unknown as QuestionRow[]) ?? [])
    setLoading(false)
  }

  useEffect(() => {
    queueMicrotask(load)
  }, [])

  const topicOptions = topics.filter(
    (t) =>
      (!form.subject || t.subject_id === form.subject) &&
      (!t.jenjang || t.jenjang === form.jenjang),
  )

  const filtered = rows.filter(
    (r) =>
      (!filterSubject || r.subject_id === filterSubject) &&
      (!filterStatus || r.status === filterStatus),
  )

  function patchForm(patch: Partial<QuestionFormState>) {
    setForm((f) => ({ ...f, ...patch }))
  }

  function startEdit(r: QuestionRow) {
    setForm({
      id: r.id,
      subject: r.subject_id,
      topic: r.topic_id ?? '',
      jenjang: r.jenjang,
      type: r.type,
      body: r.body ?? '',
      options: r.options && r.options.length === 4
        ? r.options
        : emptyForm.options,
      answer: r.answer ?? 'A',
      explanation: r.explanation ?? '',
      image: r.image_url ?? '',
    })
    setShowForm(true)
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }

  function resetForm() {
    setForm(emptyForm)
    setNotice(null)
  }

  async function onSave(e: FormEvent) {
    e.preventDefault()
    setBusy(true)
    setNotice(null)
    const { error } = await supabase.rpc('admin_save_question', {
      p_question_id: form.id || null,
      p_subject: form.subject,
      p_topic: form.topic || null,
      p_jenjang: form.jenjang,
      p_type: form.type,
      p_body: form.body,
      p_options: form.type === 'pg' ? form.options : null,
      p_answer: form.answer,
      p_explanation: form.explanation || null,
      p_image_path: form.image || null,
    })
    setBusy(false)
    if (error) {
      setNotice(`Gagal: ${error.message}`)
      return
    }
    setNotice(form.id ? 'Versi baru tersimpan.' : 'Soal baru tersimpan (draf).')
    setForm(emptyForm)
    setVersions({})
    setShowForm(false)
    load()
  }

  async function setStatus(r: QuestionRow, status: string) {
    const { error } = await supabase.rpc('admin_set_question_status', {
      p_question_id: r.id,
      p_status: status,
    })
    if (error) {
      setNotice(`Gagal: ${error.message}`)
      return
    }
    load()
  }

  async function toggleVersions(r: QuestionRow) {
    if (openVersions === r.id) {
      setOpenVersions(null)
      return
    }
    setOpenVersions(r.id)
    const { data } = await supabase
      .from('question_versions')
      .select('version, body, created_at')
      .eq('question_id', r.id)
      .order('version', { ascending: false })
    setVersions((v) => ({ ...v, [r.id]: (data as VersionRow[]) ?? [] }))
  }

  async function onUpload(file: File) {
    setBusy(true)
    setNotice(null)
    const path = `questions/${crypto.randomUUID()}-${file.name}`
    const { error } = await supabase.storage.from('question-assets').upload(path, file)
    setBusy(false)
    if (error) {
      setNotice(`Gagal unggah: ${error.message}`)
      return
    }
    patchForm({ image: path })
  }

  async function previewImage(path: string) {
    if (signed[path]) return
    const { data } = await supabase.storage.from('question-assets').createSignedUrl(path, 3600)
    if (data?.signedUrl) setSigned((s) => ({ ...s, [path]: data.signedUrl }))
  }

  return (
    <section>
      <div className="page-head">
        <div>
          <p className="eyebrow">Konten · Bank soal</p>
          <h1 className="page-title">Bank soal</h1>
          <p className="page-sub">
            Alur: draf → perlu diperiksa → terbit → diarsipkan. Setiap perubahan pada soal terbit membuat versi baru.
          </p>
        </div>
        <div className="head-actions">
          <button className="btn btn-primary" onClick={() => setShowForm((value) => !value)}>
            {showForm ? 'Tutup formulir' : 'Tulis soal'}
          </button>
        </div>
      </div>

      {showForm && (
        <QuestionForm
          form={form}
          subjects={subjects}
          topicOptions={topicOptions}
          onPatch={patchForm}
          onSave={onSave}
          onUpload={onUpload}
          onPreviewImage={previewImage}
          onReset={() => { resetForm(); setShowForm(false) }}
          signed={signed}
          busy={busy}
        />
      )}

      {notice && (
        <div className="note" style={{ marginBottom: 14 }}>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
            <circle cx="12" cy="12" r="9" />
            <path d="M12 11v5M12 8h.01" />
          </svg>
          <span>{notice}</span>
        </div>
      )}

      <QuestionTable
        subjects={subjects}
        filterSubject={filterSubject}
        onFilterSubject={setFilterSubject}
        filterStatus={filterStatus}
        onFilterStatus={setFilterStatus}
        filtered={filtered}
        loading={loading}
        versions={versions}
        openVersions={openVersions}
        onStartEdit={startEdit}
        onSetStatus={setStatus}
        onToggleVersions={toggleVersions}
      />
    </section>
  )
}
