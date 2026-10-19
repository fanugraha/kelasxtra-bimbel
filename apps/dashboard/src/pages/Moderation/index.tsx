import { useEffect, useMemo, useRef, useState } from 'react'
import { invokeFn } from '../../lib/functions'
import { supabase } from '../../lib/supabase'
import { FlagDetailDialog } from './FlagDetailDialog'
import { FlagsTable } from './FlagsTable'
import type { FlagRow, TranscriptMessage } from './types'

export function Moderation() {
  const [rows, setRows] = useState<FlagRow[]>([])
  const [filter, setFilter] = useState('open')
  const [loading, setLoading] = useState(true)
  const [notice, setNotice] = useState<string | null>(null)
  const [busy, setBusy] = useState<string | null>(null)

  const [detail, setDetail] = useState<FlagRow | null>(null)
  const [messages, setMessages] = useState<TranscriptMessage[]>([])
  const [names, setNames] = useState<Record<string, string>>({})
  const [loadingDetail, setLoadingDetail] = useState(false)
  const dialogRef = useRef<HTMLDialogElement>(null)

  async function load() {
    setLoading(true)
    const { data, error } = await supabase
      .from('moderation_flags')
      .select(
        'id, actor_id, context, matched, excerpt, created_at, reviewed_at, note, ref_table, ref_id, ' +
          'actor:profiles!moderation_flags_actor_id_fkey(id, full_name, role), ' +
          'reviewer:profiles!moderation_flags_reviewed_by_fkey(full_name)',
      )
      .order('created_at', { ascending: false })
      .limit(200)
    if (error) {
      setNotice(`Gagal memuat: ${error.message}`)
      setLoading(false)
      return
    }
    setRows((data ?? []) as unknown as FlagRow[])
    setLoading(false)
  }

  useEffect(() => {
    queueMicrotask(load)
  }, [])

  const shown = useMemo(
    () => (filter === 'open' ? rows.filter((r) => !r.reviewed_at) : rows),
    [rows, filter],
  )
  const openCount = useMemo(() => rows.filter((r) => !r.reviewed_at).length, [rows])

  async function openDetail(row: FlagRow) {
    setDetail(row)
    setMessages([])
    setNames({})
    dialogRef.current?.showModal()
    if (row.ref_table !== 'conversations' || !row.ref_id) return

    setLoadingDetail(true)
    const [{ data: conv }, { data: msgs }] = await Promise.all([
      supabase
        .from('conversations')
        .select('id, student_id, tutor_id')
        .eq('id', row.ref_id)
        .maybeSingle(),
      supabase
        .from('conversation_messages')
        .select('id, sender_id, body, created_at, flagged')
        .eq('conversation_id', row.ref_id)
        .order('created_at', { ascending: true })
        .limit(300),
    ])
    const ids = [conv?.student_id, conv?.tutor_id].filter(Boolean) as string[]
    if (ids.length > 0) {
      const { data: profiles } = await supabase
        .from('profiles')
        .select('id, full_name')
        .in('id', ids)
      setNames(Object.fromEntries((profiles ?? []).map((p) => [p.id, p.full_name ?? 'Pengguna'])))
    }
    setMessages((msgs ?? []) as TranscriptMessage[])
    setLoadingDetail(false)
  }

  function closeDetail() {
    dialogRef.current?.close()
  }

  async function onReview(row: FlagRow) {
    const note = prompt('Catatan tindakan (opsional, untuk arsip internal):') ?? undefined
    setBusy(row.id)
    setNotice(null)
    const { error } = await supabase.rpc('admin_review_flag', {
      p_flag: row.id,
      p_note: note ?? null,
    })
    setBusy(null)
    if (error) {
      setNotice(`Gagal: ${error.message}`)
      return
    }
    setNotice('Catatan ditandai sudah ditinjau.')
    if (detail?.id === row.id) closeDetail()
    load()
  }

  async function onWarn(row: FlagRow) {
    if (!row.actor_id) return
    const reason = prompt(
      'Isi pesan peringatan (dikirim ke notifikasi pengguna):',
      'Mohon jangan mengirim nomor HP, email, tautan, atau ajakan transaksi di luar aplikasi. Untuk keamanan bersama, transaksi hanya lewat aplikasi.',
    )
    if (!reason) return
    setBusy(row.id)
    setNotice(null)
    const { error } = await supabase.rpc('admin_warn_user', {
      p_user: row.actor_id,
      p_reason: reason,
    })
    setBusy(null)
    if (error) {
      setNotice(`Gagal: ${error.message}`)
      return
    }
    setNotice(`Peringatan terkirim ke ${row.actor?.full_name ?? 'pengguna'}.`)
  }

  async function onSuspend(row: FlagRow) {
    if (!row.actor_id) return
    if (
      !confirm(
        `Tangguhkan akun tutor ${row.actor?.full_name ?? ''}? Tutor tidak bisa masuk sampai diaktifkan lagi.`,
      )
    )
      return
    const reason = prompt('Alasan penangguhan:', 'Pelanggaran aturan komunikasi (berbagi kontak/pembayaran di luar aplikasi).')
    if (!reason) return
    setBusy(row.id)
    setNotice(null)
    const { error } = await invokeFn('manage-tutor', {
      tutor_id: row.actor_id,
      action: 'suspend',
      reason,
    })
    setBusy(null)
    if (error) {
      setNotice(`Gagal: ${error}`)
      return
    }
    setNotice('Akun tutor ditangguhkan.')
    load()
  }

  return (
    <section>
      <div className="page-head">
        <div>
          <p className="eyebrow">Layanan · Moderasi</p>
          <h1 className="page-title">Moderasi chat</h1>
          <p className="page-sub">
            Pesan berisi nomor HP, email, tautan, atau ajakan transaksi di luar aplikasi otomatis ditolak dan dicatat
            di sini. Tinjau, beri peringatan, atau tangguhkan tutor.
          </p>
        </div>
        <div className="head-actions">
          {openCount > 0 && <span className="badge danger">{openCount} belum ditinjau</span>}
        </div>
      </div>

      {notice && (
        <div className="note" style={{ marginBottom: 14 }}>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
            <circle cx="12" cy="12" r="9" />
            <path d="M12 11v5M12 8h.01" />
          </svg>
          <span>{notice}</span>
        </div>
      )}

      <FlagsTable
        shown={shown}
        loading={loading}
        filter={filter}
        onFilter={setFilter}
        busy={busy}
        onOpenDetail={openDetail}
        onReview={onReview}
        onWarn={onWarn}
        onSuspend={onSuspend}
      />

      <FlagDetailDialog
        dialogRef={dialogRef}
        detail={detail}
        messages={messages}
        names={names}
        loadingDetail={loadingDetail}
        onClose={() => setDetail(null)}
        onWarn={onWarn}
        onSuspend={onSuspend}
        onReview={onReview}
      />
    </section>
  )
}
