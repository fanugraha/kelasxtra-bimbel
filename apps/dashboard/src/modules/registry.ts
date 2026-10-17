export type ModuleGroup = 'operasional' | 'bisnis' | 'layanan'

export interface ModuleDef {
  path: string
  label: string
  desc: string
  phase: string
  group: ModuleGroup
}

export const groupLabels: Record<ModuleGroup, string> = {
  operasional: 'Operasional',
  bisnis: 'Bisnis',
  layanan: 'Layanan & konten',
}

// Modul dashboard sesuai brief, dikelompokkan seperti panel admin.
export const modules: ModuleDef[] = [
  { path: 'monitoring', label: 'Pantau Kelas', desc: 'Progres siswa, performa tutor, operasional harian.', phase: 'Fase 8', group: 'operasional' },
  { path: 'tutors', label: 'Tutor & Undangan', desc: 'Buat akun tutor, kirim undangan, suspend/reaktivasi.', phase: 'Fase 1', group: 'operasional' },
  { path: 'group-classes', label: 'Kelas Grup', desc: 'Slot grup, assign tutor, ruangan, pantau keterisian.', phase: 'Fase 4', group: 'operasional' },
  { path: 'rooms', label: 'Ruangan', desc: 'Master ruangan offline, anti double-booking kelas grup.', phase: 'Fase 4', group: 'operasional' },
  { path: 'payroll', label: 'Gaji Tutor', desc: 'Rekap honor tutor per periode, approval four-eyes, bukti transfer.', phase: 'Fase 7', group: 'bisnis' },
  { path: 'finance', label: 'Keuangan', desc: 'Gross, potongan 25%, biaya gateway, payroll.', phase: 'Fase 7-8', group: 'bisnis' },
  { path: 'packages', label: 'Paket Sesi', desc: 'Pembelian paket, sisa kuota, refund proporsional.', phase: 'Fase 3', group: 'bisnis' },
  { path: 'pricing', label: 'Daftar Harga', desc: 'Kelola harga per jenjang × durasi × mode × tipe + riwayat.', phase: 'Fase 2', group: 'bisnis' },
  { path: 'vouchers', label: 'Voucher & Promo', desc: 'CRUD voucher, laporan pemakaian.', phase: 'Fase 8', group: 'bisnis' },
  { path: 'disputes', label: 'Komplain', desc: 'Tiket komplain, mediasi, refund.', phase: 'Fase 6', group: 'layanan' },
  { path: 'question-cms', label: 'Bank Soal', desc: 'Input soal + KaTeX + gambar, review sebelum tayang.', phase: 'Fase 5', group: 'layanan' },
  { path: 'audit-log', label: 'Riwayat Aktivitas', desc: 'Jejak aksi sensitif (refund, koreksi, payroll).', phase: 'Fase 9', group: 'layanan' },
]
