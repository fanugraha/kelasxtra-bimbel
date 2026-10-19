import type { FormEvent } from 'react'
import { MathText } from '../../components/MathText'
import type { Option, QuestionFormState, Topic } from './types'

export function QuestionForm({
  form,
  subjects,
  topicOptions,
  onPatch,
  onSave,
  onUpload,
  onPreviewImage,
  onReset,
  signed,
  busy,
}: {
  form: QuestionFormState
  subjects: Option[]
  topicOptions: Topic[]
  onPatch: (patch: Partial<QuestionFormState>) => void
  onSave: (e: FormEvent) => void
  onUpload: (file: File) => void
  onPreviewImage: (path: string) => void
  onReset: () => void
  signed: Record<string, string>
  busy: boolean
}) {
  return (
    <div className="card" style={{ marginBottom: 14 }}>
      <div className="card-head">
        <div>
          <h2 className="card-title">{form.id ? 'Edit soal' : 'Soal baru'}</h2>
          <p className="card-sub">
            Tulis rumus seperti biasa — mis. <code>akar3</code>, <code>x^2</code>,
            <code>cos 60 derajat</code>, <code>6,02 x 10^23</code> — pratinjau otomatis.
            <code>$...$</code> juga didukung. Mengedit soal terbit membuat versi baru.
          </p>
        </div>
        {form.id && <span className="badge warning">mengedit versi</span>}
      </div>
      <form className="card-body" onSubmit={onSave}>
        <div className="form-grid">
          <label className="field">
            <span>Mapel</span>
            <select className="select" value={form.subject} onChange={(e) => onPatch({ subject: e.target.value, topic: '' })} required>
              <option value="">Pilih mapel…</option>
              {subjects.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
            </select>
          </label>
          <label className="field">
            <span>Jenjang</span>
            <select className="select" value={form.jenjang} onChange={(e) => onPatch({ jenjang: e.target.value, topic: '' })}>
              {['SD', 'SMP', 'SMA'].map((j) => <option key={j} value={j}>{j}</option>)}
            </select>
          </label>
          <label className="field">
            <span>Topik</span>
            <select className="select" value={form.topic} onChange={(e) => onPatch({ topic: e.target.value })}>
              <option value="">Topik (opsional)…</option>
              {topicOptions.map((t) => <option key={t.id} value={t.id}>{t.name}</option>)}
            </select>
          </label>
          <label className="field">
            <span>Jenis</span>
            <select className="select" value={form.type} onChange={(e) => onPatch({ type: e.target.value as 'pg' | 'isian' })}>
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
            placeholder="Contoh: Nilai dari cos 60 derajat adalah ... (pratinjau otomatis)"
            value={form.body}
            onChange={(e) => onPatch({ body: e.target.value })}
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
                  onChange={() => onPatch({ answer: o.key })}
                  title="jadikan kunci jawaban"
                />
                <strong>{o.key}</strong>
                <input
                  style={{ flex: 1 }}
                  placeholder={`Opsi ${o.key} (mis. akar3/2, 12 N)`}
                  value={o.text}
                  onChange={(e) => {
                    const next = [...form.options]
                    next[i] = { ...o, text: e.target.value }
                    onPatch({ options: next })
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
            onChange={(e) => onPatch({ answer: e.target.value })}
            required
          />
        )}

        <textarea
          rows={2}
          placeholder="Pembahasan (mis. cos 60 = 1/2)"
          value={form.explanation}
          onChange={(e) => onPatch({ explanation: e.target.value })}
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
              <button type="button" onClick={() => onPreviewImage(form.image)}>Lihat</button>
              <button type="button" onClick={() => onPatch({ image: '' })}>Hapus</button>
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
            <button className="btn btn-secondary" type="button" onClick={onReset}>
              Bersihkan
            </button>
          )}
        </div>
      </form>
    </div>
  )
}
