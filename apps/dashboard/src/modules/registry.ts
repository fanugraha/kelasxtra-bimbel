export interface ModuleDef {
  path: string
  label: string
  desc: string
  phase: string
}

// Modul dashboard sesuai brief, dikelompokkan per fase implementasi.
export const modules: ModuleDef[] = [
  { path: 'tutors', label: 'Tutor & Undangan', desc: 'Buat akun tutor, kirim undangan, suspend/reaktivasi.', phase: 'Fase 1' },
  { path: 'pricing', label: 'Price Matrix', desc: 'Kelola harga per jenjang × durasi × mode × tipe + riwayat.', phase: 'Fase 2' },
  { path: 'packages', label: 'Paket Sesi', desc: 'Pembelian paket, sisa kuota, refund proporsional.', phase: 'Fase 3' },
  { path: 'group-classes', label: 'Kelas Grup', desc: 'Slot grup, assign tutor, ruangan, pantau keterisian.', phase: 'Fase 4' },
  { path: 'question-cms', label: 'CMS Bank Soal', desc: 'Input soal + KaTeX + gambar, review sebelum tayang.', phase: 'Fase 5' },
  { path: 'monitoring', label: 'Monitoring', desc: 'Progres siswa, performa tutor, operasional harian.', phase: 'Fase 8' },
  { path: 'finance', label: 'Keuangan', desc: 'Gross, potongan 25%, biaya gateway, payroll.', phase: 'Fase 7-8' },
  { path: 'vouchers', label: 'Voucher & Promo', desc: 'CRUD voucher, laporan pemakaian.', phase: 'Fase 8' },
  { path: 'disputes', label: 'Komplain', desc: 'Tiket komplain, mediasi, refund.', phase: 'Fase 6' },
  { path: 'rooms', label: 'Ruangan', desc: 'Master ruangan offline, anti double-booking.', phase: 'Fase 8' },
]
