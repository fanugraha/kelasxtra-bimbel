# Fase 4 — Kelas Grup (O1 & Desain)

Bagian dari [[2026-10-15-konteks-proyek-kelasxtra-bimbel]].

## Konteks

16 Okt 2026. Fase 4 butuh keputusan **O1** (minimal peserta / subsidi). Pemilik menolak
subsidi karena platform tidak mau nombok → persyaratan dialihkan ke pengguna.

## Keputusan (O1 selesai)

- **Minimal 3 siswa** (maks 5). **Tanpa subsidi** — kelas baru jalan bila ≥3 kursi terbayar.
- **Bayar sekali per kursi** saat ambil kursi (Snap). Karena selalu ≥3, honor tutor =
  75% × harga × kursi nyata → platform tak pernah nombok.
- **Tenggat keputusan H-1 pukul 20:00 WIB** (dari pertemuan pertama). Lewat itu:
  ≥3 → program jalan; <3 → program **batal**.
- Kalau batal: siswa **ditawarkan pindah kelas / jadi kredit dulu**, refund penuh bila menolak.
- **Cap 2 slot/tutor/minggu dibuang** (motif gaming subsidi hilang).

## Bentuk jadwal

- **Program** (bukan per pertemuan). Admin menentukan **2 hari berbeda + 1 jam** (mis.
  Selasa & Kamis 16:00) dan **ukuran paket 4/8/12 sesi** (diskon 0/5/10%, sama seperti privat).
- Sistem otomatis menyusun daftar pertemuan: 2×/minggu → 4 sesi = 2 minggu, 8 = 4 minggu,
  12 = 6 minggu.
- Siswa beli 1 kursi → dapat **seluruh pertemuan** program (bayar sekali).
- Kursi ditutup setelah program jalan (materi berurutan).

## Benchmark (riset 16 Okt)

- **Lingoda** (lingoda.com/en/faq): kelas grup 3–5 siswa; batal hanya bila tak ada guru →
  kredit kembali. Tidak ada minimum siswa → platform menanggung kelas sepi.
- **Outschool** (support.outschool.com): bayar per kelas; refund penuh bila guru batal;
  refund prorata bila guru tak mengajar sesuai jumlah pertemuan; batal dalam 24 jam → refund.
- Kesimpulan: Kelasxtra ambil **Pola B** (syarat minimum ke pengguna, platform tak nombok),
  beda dari Lingoda yang menanggung risiko.
- Catatan: aturan "minimum siswa → auto-cancel" di Outschool tak eksplisit di artikel yang
  dibaca (perlu verifikasi); pemain Indonesia belum diverifikasi.

## Rencana bangun

```
A. DB: rooms, group_classes, group_sessions, group_seats + RPC + view + cron
B. Edge: create-group-seat-snap + webhook cabang group_seat
C. Dashboard: buat program kelas grup + pantau keterisian
D. Mobile siswa: daftar kelas grup, ambil kursi, bayar
```

## Tautan terkait

- [[2026-10-16-fase-3-paket-sesi]]
- [[2026-10-15-rencana-pengembangan]]
