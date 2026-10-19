# Memecah layar Beli Paket (maintainability)

## Konteks

`paket/beli_paket_screen.dart` sudah 985 baris: satu file mencampur state wizard,
logika perhitungan jadwal, tiga langkah UI, dan lima komponen kecil. Pemilik
meminta dipecah karena maintenance-nya rumit.

## Keputusan atau temuan

- Struktur folder baru `lib/features/paket/beli_paket/`:
  - `beli_paket_screen.dart` — kerangka: Scaffold, head, progress, bar bawah,
    navigasi + panggilan `submit`/voucher. Hanya tahu controller, bukan detail.
  - `beli_paket_controller.dart` — `ChangeNotifier` berisi seluruh state wizard
    (langkah, mapel, mode, durasi, jumlah, slot, tanggal, jam, voucher, error)
    plus logika jadwal murni (`meetingDates`, `nextDates`, `startTimes`,
    `meetingsFree`, `dateHasSlot`) dan panggilan jaringan (voucher, Snap).
    Kolom teks alamat & voucher dimiliki controller agar pengosongan otomatis
    saat pilihan berubah tetap terpusat.
  - `steps/` — `step_paket.dart`, `step_jadwal.dart`, `step_ringkasan.dart`
    (tiap langkah satu widget, menerima controller + data tutor).
  - `widgets/` — `step_progress`, `jadwal_list`, `bar_total`, `price_card`,
    `voucher_field` (dipindahkan apa adanya).
- Controller menyuntik ketergantungan lewat konstruktor
  (`repository`, `invalidateBusy`) sehingga tak perlu `BuildContext`.

## Alasan

- Navigasi & `ref` tetap di layar; controller jadi murni dan bisa diuji tanpa UI.
- Logika jadwal (sumber bug "slot bentrok" sebelumnya) kini bisa diuji langsung:
  4 tes baru (`meetingDates`, `nextDates`, `meetingsFree`, `startTimes`).
- Perilaku tidak diubah (refactor murni); `flutter analyze` bersih, 27 tes lulus.

## Langkah berikutnya

- Uji ulang di HP setelah kabel tersambung (kirim Snap → tutup → layar berhasil).
- Bila nanti langkah bertambah, pola ini (controller + steps/) bisa dipakai di
  wizard lain yang mulai panjang (mis. kelas grup).
