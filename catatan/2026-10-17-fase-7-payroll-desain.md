# Keputusan Fase 7 — Payroll (penguatan desain)

## Konteks

Rancangan awal: `tutor_earnings` (append-only) + `payouts`, rekap cut-off tgl 25,
four-eyes approval, ekspor transfer, tandai sudah ditransfer. Transfer manual admin.

## Keputusan atau temuan

Sebelum implementasi, desain diperkuat:

1. **Periode dikunci** lewat tabel `payroll_periods` (rentang tanggal + status
   draft/approved/paid). Earning yang telat masuk (sesi tgl 25, completed tgl 26)
   **tidak** mengubah periode lama; otomatis ikut periode berikutnya.
2. **Cegah dobel bayar** dengan `tutor_earnings.payout_id`; hanya earning
   `belum_dibayar` + `payout_id is null` yang boleh masuk rekap.
3. **Honor kelas grup** ikut ledger: satu earning per pertemuan = 75% ×
   (`price_per_session` × kursi aktif). No-show tetap dihitung (kursi aktif).
   Kolom `source` = booking/group, `group_session_id`, `session_at`.
4. **Clawback**: earning yang sudah dibayar tidak diubah. Refund/komplain
   berikutnya dicatat sebagai koreksi di periode mendatang (belum otomatis;
   minimal ledger tidak di-update).
5. **Snapshot rekening** tutor disimpan di baris `payouts` (nama/nomor/pemilik)
   plus `transfer_ref` bukti transfer.
6. **Four-eyes**: approver wajib user admin berbeda dari pembuat periode.
7. Cut-off memakai tanggal **WIB** (`Asia/Jakarta`), ekspor CSV disediakan.
8. Slip tutor hanya baca: daftar payout + status, tanpa tombol tarik dana.

## Alasan

- Uang tidak boleh dihitung dua kali atau diubah setelah dibayar.
- Ledger tetap append-only; koreksi = baris baru, bukan edit.
- Rekap manual-friendly: angka bisa direkonsiliasi dengan mutasi bank.

## Langkah berikutnya

- Implementasi migrasi: `payroll_periods`, `payouts`, kolom earning, RPC
  generate/approve/mark-paid/cancel, cron honor grup.
- Dashboard modul **Payroll** (generate bulan, approve, tandai transfer, CSV).
- Mobile tutor: layar **Penghasilan** (slip).
- Uji simulasi 1 periode: sesi selesai + komplain ditahan + honor grup.

## Tautan terkait

- [[2026-10-17-fase-6-absensi-reschedule-komplain]]
- [[2026-10-15-rencana-pengembangan]]
