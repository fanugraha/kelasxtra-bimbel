# Mobile Siswa — Katalog Tutor + Profil

Bagian dari [[2026-10-15-konteks-proyek-kelasxtra-bimbel]].

## Konteks

Fase 2, 16 Okt 2026. Bagian mobile dari katalog tutor (brief: filter mapel, jenjang,
rentang harga, rating; profil tutor + jadwal). Booking/pembayaran belum — nunggu Midtrans.

## Keputusan atau temuan

- Fitur baru `apps/mobile/lib/features/katalog/`:
  - `katalog_repository.dart` — query `tutor_catalog`, `subjects`, `tutor_subjects`,
    `tutor_availability`; model `TutorCatalogItem`, `TutorSubjectItem`,
    `TutorAvailabilityItem`, `TutorDetail`.
  - `katalog_providers.dart` — `subjectsProvider`, `katalogFilterProvider` (Notifier),
    `tutorListProvider` (FutureProvider), `tutorDetailProvider` (family).
  - `katalog_screen.dart` — daftar tutor (kartu: avatar, nama, pendidikan, rating),
    filter dropdown **Jenjang** + **Mapel**, tarik-untuk-muat-ulang.
  - `tutor_detail_screen.dart` — profil (foto, bio, pendidikan, rating), chip mapel·jenjang,
    daftar jadwal ketersediaan.
- Rute baru: `/katalog`, `/tutor/:id` (di belakang login). Tombol **Cari Tutor** di home
  (hanya flavor siswa).
- **Filter mapel/jenjang lewat `tutor_subjects`** (2 langkah: ambil `tutor_id`, lalu
  `tutor_catalog.id in (...)`). PostgREST tak andal menyematkan view ↔ tabel tanpa FK.
- **Dropdown "Semua" pakai sentinel `''`**, bukan `null` — Flutter menganggap `value == null`
  sebagai "belum dipilih" sehingga item ber-nilai null tak tampil terpilih.
- Detail pakai `context.push` (bukan `go`) agar tombol kembali balik ke katalog.
- Verifikasi: `flutter analyze` bersih; `flutter test` 4 tes lolos (parsing model + format
  hari/jam).
- **Ditunda**: filter mode/harga/rating-min, pilih slot, booking, Snap.

## Alasan

- Katalog baca VIEW `tutor_catalog` (lihat [[2026-10-16-katalog-publik-view]]) → kolom bank
  tak mungkin bocor ke client.
- Satu codebase Flutter dua flavor: katalog hanya muncul di flavor siswa.

## Langkah berikutnya

- Filter harga/mode + "pilih slot" saat jadwal dipakai untuk booking.
- Fase 2 backend: Edge Function `create-snap` + `midtrans-webhook` (butuh Midtrans Sandbox).
- Uji di HP Android pemilik (aturan: jangan `flutter run`/emulator dari sisi agent).

## Tautan terkait

- [[2026-10-16-katalog-publik-view]]
- [[2026-10-15-fase-2-katalog-booking]]
- [[2026-10-15-keputusan-teknis-kelasxtra]]
