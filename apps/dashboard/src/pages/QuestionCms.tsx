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

const STATUS_LABEL: Record<string, string> = {
  draft: 'Draf',
  review: 'Review',
  published: 'Tayang',
  archived: 'Arsip',
}

const STATUS_TONE: Record<string, string> = {
  draft: 'neutral',
  review: 'warning',
  published: 'success',
  archived: 'neutral',
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
    setForm((f) => ({ ...f, image: path }))
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
      <div className="card" style={{ marginBottom: 14 }}>
        <div className="card-head">
          <div>
            <h2 className="card-title">{form.id ? 'Edit soal' : 'Soal baru'}</h2>
            <p className="card-sub">
              Rumus ditulis di antara <code>$...$</code>. Mengedit soal terbit membuat versi baru.
            </p>
          </div>
          {form.id && <span className="badge warning">mengedit versi</span>}
        </div>
      <form className="card-body" onSubmit={onSave}>
        <div className="form-grid">
          <label className="field">
            <span>Mapel</span>
            <select className="select" value={form.subject} onChange={(e) => setForm({ ...form, subject: e.target.value, topic: '' })} required>
              <option value="">Pilih mapel…</option>
              {subjects.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
            </select>
          </label>
          <label className="field">
            <span>Jenjang</span>
            <select className="select" value={form.jenjang} onChange={(e) => setForm({ ...form, jenjang: e.target.value, topic: '' })}>
              {['SD', 'SMP', 'SMA'].map((j) => <option key={j} value={j}>{j}</option>)}
            </select>
          </label>
          <label className="field">
            <span>Topik</span>
            <select className="select" value={form.topic} onChange={(e) => setForm({ ...form, topic: e.target.value })}>
              <option value="">Topik (opsional)…</option>
              {topicOptions.map((t) => <option key={t.id} value={t.id}>{t.name}</option>)}
            </select>
          </label>
          <label className="field">
            <span>Jenis</span>
            <select className="select" value={form.type} onChange={(e) => setForm({ ...form, type: e.target.value as 'pg' | 'isian' })}>
              <option value="pg">Pilihan ganda</option>
              <option value="isian">Isian</option>
            </select>
          </label>
        </div>

        <label className="field" style={{ marginTop: 12 }}>
          <span>Isi soal</span>
          <textarea
            className="textarea"
            rows={3}
            placeholder="Isi soal. Rumus di antara $...$, contoh: Nilai dari $\sin 30^\circ$ adalah ..."
            value={form.body}
            onChange={(e) => setForm({ ...form, body: e.target.value })}
            required
          />
        </label>

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

        <div className="head-actions" style={{ marginTop: 14 }}>
          <button className="btn btn-primary" type="submit" disabled={busy}>
            {busy ? 'Menyimpan…' : form.id ? 'Simpan versi baru' : 'Simpan soal'}
          </button>
          {(form.id || form.body) && (
            <button className="btn btn-secondary" type="button" onClick={() => { resetForm(); setShowForm(false) }}>
              Bersihkan
            </button>
          )}
        </div>
      </form>
      </div>
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

      <div className="card">
        <div className="toolbar">
          <select className="select" value={filterSubject} onChange={(e) => setFilterSubject(e.target.value)} aria-label="Filter mapel">
            <option value="">Semua mapel</option>
            {subjects.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
          </select>
          <select className="select" value={filterStatus} onChange={(e) => setFilterStatus(e.target.value)} aria-label="Filter status">
            <option value="">Semua status</option>
            {Object.entries(STATUS_LABEL).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
          </select>
          <div className="spacer" />
          <span className="badge neutral">{filtered.length} soal</span>
        </div>

      {loading ? (
        <div className="empty-state">
          <strong>Memuat soal…</strong>
        </div>
      ) : filtered.length === 0 ? (
        <div className="empty-state">
          <strong>Belum ada soal</strong>
          <span>Tulis soal pertama lewat tombol di kanan atas.</span>
        </div>
      ) : (
        <div className="table-wrap">
        <table className="data-table">
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
                  <td>
                    {r.subject_name ?? '—'} · {r.topic_name ?? '—'} · {r.jenjang}
                  </td>
                  <td className="num">v{r.current_version}</td>
                  <td>
                    <span className={`badge ${STATUS_TONE[r.status] ?? 'neutral'}`}>
                      {STATUS_LABEL[r.status] ?? r.status}
                    </span>
                  </td>
                  <td>
                    <div className="row-actions">
                      <button className="btn btn-secondary btn-sm" onClick={() => startEdit(r)}>Edit</button>
                      {r.status === 'draft' && <button className="btn btn-ghost btn-sm" onClick={() => setStatus(r, 'review')}>Ajukan review</button>}
                      {r.status === 'review' && <button className="btn btn-secondary btn-sm" onClick={() => setStatus(r, 'published')}>Tayangkan</button>}
                      {r.status === 'published' && <button className="btn btn-ghost btn-sm" onClick={() => setStatus(r, 'archived')}>Arsipkan</button>}
                      <button className="btn btn-ghost btn-sm" onClick={() => toggleVersions(r)}>{openVersions === r.id ? 'Tutup' : 'Riwayat'}</button>
                    </div>
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
        </div>
      )}
      </div>
    </section>
  )
}
