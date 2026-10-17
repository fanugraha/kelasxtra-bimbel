import { Fragment, useEffect, useMemo, useState } from 'react'
import type { FormEvent } from 'react'
import { InlineMath } from 'react-katex'
import 'katex/dist/katex.min.css'
import { supabase } from '../lib/supabase'

interface Option { id: string; name: string }
interface Topic extends Option { subject_id: string; jenjang: string | null }

interface QuestionRow {
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

interface VersionRow {
  version: number
  body: string
  created_at: string
}

const STATUS_CLASS: Record<string, string> = {
  draft: 'status-suspend',
  review: 'status-diundang',
  published: 'status-aktif',
  archived: 'status-suspend',
}

const STATUS_LABEL: Record<string, string> = {
  draft: 'Draf',
  review: 'Review',
  published: 'Tayang',
  archived: 'Arsip',
}

const emptyForm = {
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

/** Render teks dengan potongan rumus `$...$` memakai KaTeX. */
function MathText({ text }: { text: string }) {
  const parts = useMemo(() => text.split(/(\$[^$]+\$)/g), [text])
  return (
    <>
      {parts.map((p, i) =>
        p.startsWith('$') && p.endsWith('$') && p.length > 2 ? (
          <InlineMath key={i} math={p.slice(1, -1)} />
        ) : (
          <span key={i}>{p}</span>
        ),
      )}
    </>
  )
}

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

  async function load() {
    setLoading(true)
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
    load()
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
    setForm((f) => ({ ...f, image: path }))
  }

  async function previewImage(path: string) {
    if (signed[path]) return
    const { data } = await supabase.storage.from('question-assets').createSignedUrl(path, 3600)
    if (data?.signedUrl) setSigned((s) => ({ ...s, [path]: data.signedUrl }))
  }

  return (
    <section>
      <h1>CMS Bank Soal</h1>
      <p className="muted">
        Soal + rumus (KaTeX, tulis di antara <code>$...$</code>) + gambar. Mengedit soal membuat
        <strong> versi baru</strong> (riwayat tak hilang). Alur: draf → review → tayang.
      </p>

      <form className="tutor-form" onSubmit={onSave} style={{ flexDirection: 'column', alignItems: 'stretch' }}>
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          <select value={form.subject} onChange={(e) => setForm({ ...form, subject: e.target.value, topic: '' })} required>
            <option value="">Mapel…</option>
            {subjects.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
          </select>
          <select value={form.jenjang} onChange={(e) => setForm({ ...form, jenjang: e.target.value, topic: '' })}>
            {['SD', 'SMP', 'SMA'].map((j) => <option key={j} value={j}>{j}</option>)}
          </select>
          <select value={form.topic} onChange={(e) => setForm({ ...form, topic: e.target.value })}>
            <option value="">Topik (opsional)…</option>
            {topicOptions.map((t) => <option key={t.id} value={t.id}>{t.name}</option>)}
          </select>
          <select value={form.type} onChange={(e) => setForm({ ...form, type: e.target.value as 'pg' | 'isian' })}>
            <option value="pg">Pilihan ganda</option>
            <option value="isian">Isian</option>
          </select>
          {form.id && <span className="muted">mengedit soal ({form.id.slice(0, 8)}…)</span>}
        </div>

        <textarea
          rows={3}
          placeholder="Isi soal. Rumus di antara $...$, contoh: Nilai dari $\sin 30^\circ$ adalah ..."
          value={form.body}
          onChange={(e) => setForm({ ...form, body: e.target.value })}
          required
        />

        {form.body && (
          <div className="card" style={{ padding: 12 }}>
            <div className="muted" style={{ marginBottom: 6 }}>Pratinjau:</div>
            <MathText text={form.body} />
          </div>
        )}

        {form.type === 'pg' && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
            {form.options.map((o, i) => (
              <div key={o.key} style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
                <input
                  type="radio"
                  name="answer"
                  checked={form.answer === o.key}
                  onChange={() => setForm({ ...form, answer: o.key })}
                  title="jadikan kunci jawaban"
                />
                <strong>{o.key}</strong>
                <input
                  style={{ flex: 1 }}
                  placeholder={`Opsi ${o.key} (boleh $rumus$)`}
                  value={o.text}
                  onChange={(e) => {
                    const next = [...form.options]
                    next[i] = { ...o, text: e.target.value }
                    setForm({ ...form, options: next })
                  }}
                />
                {o.text && <span className="muted"><MathText text={o.text} /></span>}
              </div>
            ))}
            <span className="muted">Kunci: {form.answer}</span>
          </div>
        )}

        {form.type === 'isian' && (
          <input
            placeholder="Kunci jawaban (teks)"
            value={form.answer}
            onChange={(e) => setForm({ ...form, answer: e.target.value })}
            required
          />
        )}

        <textarea
          rows={2}
          placeholder="Pembahasan (boleh $rumus$)"
          value={form.explanation}
          onChange={(e) => setForm({ ...form, explanation: e.target.value })}
        />

        <div style={{ display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap' }}>
          <input
            type="file"
            accept="image/*"
            onChange={(e) => {
              const f = e.target.files?.[0]
              if (f) onUpload(f)
            }}
          />
          {form.image && (
            <>
              <span className="muted">gambar: {form.image}</span>
              <button type="button" onClick={() => previewImage(form.image)}>Lihat</button>
              <button type="button" onClick={() => setForm({ ...form, image: '' })}>Hapus</button>
            </>
          )}
        </div>
        {form.image && signed[form.image] && (
          <img src={signed[form.image]} alt="soal" style={{ maxWidth: 320, borderRadius: 8 }} />
        )}

        <div style={{ display: 'flex', gap: 8 }}>
          <button type="submit" disabled={busy}>{busy ? 'Menyimpan…' : form.id ? 'Simpan versi baru' : 'Simpan soal'}</button>
          {(form.id || form.body) && <button type="button" onClick={resetForm}>Bersihkan</button>}
        </div>
      </form>

      {notice && <pre className="notice-line">{notice}</pre>}

      <div className="tutor-form">
        <select value={filterSubject} onChange={(e) => setFilterSubject(e.target.value)}>
          <option value="">Semua mapel</option>
          {subjects.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
        </select>
        <select value={filterStatus} onChange={(e) => setFilterStatus(e.target.value)}>
          <option value="">Semua status</option>
          {Object.entries(STATUS_LABEL).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
        </select>
        <span className="muted">{filtered.length} soal</span>
      </div>

      {loading ? (
        <p className="muted">Memuat…</p>
      ) : filtered.length === 0 ? (
        <p className="muted">Belum ada soal.</p>
      ) : (
        <table className="table">
          <thead>
            <tr>
              <th>Soal</th>
              <th>Mapel · Topik</th>
              <th>Ver</th>
              <th>Status</th>
              <th>Aksi</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((r) => (
              <Fragment key={r.id}>
                <tr>
                  <td>
                    {r.body ? <MathText text={r.body} /> : <span className="muted">(tanpa isi)</span>}
                    {r.image_url && <div className="muted">🖼 {r.image_url}</div>}
                  </td>
                  <td className="muted">
                    {r.subject_name ?? '—'} · {r.topic_name ?? '—'} · {r.jenjang}
                  </td>
                  <td>v{r.current_version}</td>
                  <td>
                    <span className={`status ${STATUS_CLASS[r.status] ?? 'status-diundang'}`}>
                      {STATUS_LABEL[r.status] ?? r.status}
                    </span>
                  </td>
                  <td className="actions">
                    <button onClick={() => startEdit(r)}>Edit</button>
                    {r.status === 'draft' && <button onClick={() => setStatus(r, 'review')}>Ajukan review</button>}
                    {r.status === 'review' && <button onClick={() => setStatus(r, 'published')}>Tayangkan</button>}
                    {r.status === 'published' && <button onClick={() => setStatus(r, 'archived')}>Arsipkan</button>}
                    <button onClick={() => toggleVersions(r)}>{openVersions === r.id ? 'Tutup' : 'Riwayat'}</button>
                  </td>
                </tr>
                {openVersions === r.id && (
                  <tr key={`${r.id}-v`}>
                    <td colSpan={5}>
                      {(versions[r.id] ?? []).map((v) => (
                        <div key={v.version} className="muted" style={{ padding: '4px 0' }}>
                          <strong>v{v.version}</strong> · {new Date(v.created_at).toLocaleString('id-ID')} — <MathText text={v.body} />
                        </div>
                      ))}
                    </td>
                  </tr>
                )}
              </Fragment>
            ))}
          </tbody>
        </table>
      )}
    </section>
  )
}
