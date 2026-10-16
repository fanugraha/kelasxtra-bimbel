# UI Mobile — Fondasi Desain & Pilihan Library

Bagian dari [[2026-10-15-konteks-proyek-kelasxtra-bimbel]].

## Konteks

16 Okt 2026. Sebelum bangun layar-layar berikutnya, pemilik minta riset library UI
dengan fokus **UX remaja SMP/SMA** (mudah dimengerti & dinavigasi).

## Keputusan atau temuan

- **Pilihan: Material 3 + lapisan desain sendiri**, bukan UI kit pihak ketiga.
  - Alasan utama: Flutter lokal **3.38.10** (Dart 3.10.9) ketinggalan. Forui terbaru
    butuh Flutter 3.47+; shadcn_ui terbaru butuh Dart 3.11. Versi yang cocok tinggal
    Forui 0.17 (9 bln lalu) / shadcn_ui 0.53.6 (6 bln lalu) — jalan buntu.
  - shadcn/forui juga nuansa netral "korporat" — kurang cocok remaja; toh harus dioverride.
- **Fondasi dibuat**: `lib/core/theme/` → `app_colors.dart` (palet + gradien),
  `app_typography.dart` (Nunito via google_fonts, body ≥15sp), `app_theme.dart`
  (AppSpacing, AppRadius, ThemeData light+dark, tema komponen: nav bar, tombol, input, dll).
- **Widget pakai-ulang**: `lib/widgets/` → `app_card.dart`, `app_button.dart` (ada state
  loading), `empty_state.dart` (selalu beri aksi), `tutor_card.dart`, `app_shell.dart`
  (bottom navigation).
- **Bottom nav** via `StatefulShellRoute.indexedStack`; tab per flavor di
  `lib/core/nav_destinations.dart` (siswa: Beranda/Cari/Jadwal/Profil; tutor: Beranda/Profil).
- Paket ditambah: `google_fonts`, `flutter_animate`, `skeletonizer` (loading shimmer).
- **Platform web diaktifkan** (`flutter create . --platforms=web`) untuk pratinjau cepat
  tanpa HP. Layar auth & dasbor aman.
- Verifikasi: `flutter analyze` bersih; `flutter test` 4 tes lolos; pratinjau web
  (login & daftar) render tanpa error konsol.

## Prinsip UX remaja yang dipakai

Bottom nav maks 5 tab · tap target ≥48dp · teks body ≥15–16sp · 1 aksi utama per layar ·
feedback instan (shimmer/toast) · alur booking ≤4 langkah · ikon+label · dukung dark mode.

## Langkah berikutnya

- Buat data uji (siswa + tutor aktif + `tutor_subjects`) untuk pratinjau penuh & uji E2E.
- Terapkan fondasi ke layar: booking (panggil `create-snap`), jadwal, profil.

## Tautan terkait

- [[2026-10-15-keputusan-teknis-kelasxtra]]
- [[2026-10-15-fase-2-katalog-booking]]
