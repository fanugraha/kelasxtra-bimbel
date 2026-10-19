# Rombak struktur folder mobile

## Konteks

`apps/mobile` mulai berat dirawat: satu folder `lib/widgets/` global dipakai
campur untuk komponen lintas fitur dan komponen milik satu fitur, dan beberapa
layar sudah >400–1100 baris dalam satu berkas. Pemilik memilih merapikan
sekaligus (bersih-bersih struktur + pecah `home_screen` + pecah 5 layar besar).

## Keputusan atau temuan

- **Dua tingkat widget**, bukan satu folder global:
  - dipakai ≥2 fitur → `lib/core/widgets/`;
  - hanya 1 fitur → `features/<fitur>/widgets/`;
  - hanya 1 layar → boleh di `features/<fitur>/<layar>/widgets/`.
- `lib/widgets/` dihapus; isinya pindah ke `lib/core/widgets/`. `app_shell.dart`
  juga pindah ke `lib/core/`.
- Widget khas satu fitur dikembalikan ke fiturnya: `section_head.dart` (home),
  `tutor_showcase_card.dart` (katalog), `math_text.dart` (bank_soal) — tes
  `math_text` ikut diperbarui ke `package:bimbel_mobile/features/...`.
- Kode mati dibuang: `core/widgets/tutor_card.dart` (0 pemakai).
- `features/home/home_screen.dart` (1165 baris) jadi shell tipis (108 baris)
  yang memilih flavor; isinya dipecah ke `home/siswa/`, `home/tutor/`,
  `home/widgets/` (HomeHead, ClockChip), plus `home_utils.dart`.
- Lima layar besar dipecah ke `<fitur>/widgets/` dengan nama kelas dipublikkan
  (mis. `_Summary` → `BookingSummary`): booking_detail, payment_status,
  tutor_detail, chat_room, bank_soal.
- `paket_screen.dart` (289 baris) juga dipecah: `PackageCard` (state bayar ulang)
  + baris info ke `features/paket/widgets/package_card.dart`; layarnya tinggal
  70 baris. Folder `paket/beli_paket/` sudah sesuai pola (screen + controller +
  steps/ + widgets/), jadi tidak diubah.
- Audit kebersihan: tidak ada berkas mati; semua kelas yang hanya dipakai di
  dalam satu berkas dibuat privat lagi. Dua duplikasi nyata disatukan:
  `cleanError()` (`core/errors.dart`, menggantikan 13 salinan) dan
  `isSameDay()` (`core/dates.dart`, menggantikan 2 salinan).
- **Router tidak berubah** karena berkas layar tetap di path-nya; yang diekstrak
  hanya widget ke `widgets/`.

## Alasan

- Aturan "semua widget ke satu folder global" membuat folder itu jadi tempat
  sampah lintas fitur dan menyulitkan pencarian pemilik fitur.
- Memecah layar besar memudahkan menavigasi kode, tapi menaruh widget di folder
  layar terpisah (seperti pola `beli_paket/`) terlalu banyak churn bila hanya
  perlu ekstraksi. Karena itu layar tetap di tempatnya, widget ke `widgets/`.

## Langkah berikutnya

- Perubahan **belum di-commit** — working tree masih punya banyak perubahan
  lain (paket/voucher, chat). Commit menyusul bila diminta pemilik.
- Aturan ini sudah ditulis di `docs/arsitektur.md`; ikuti untuk layar baru.
