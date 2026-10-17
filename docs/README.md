# Dokumentasi Kelasxtra Bimbel

Indeks dokumen. Saling terhubung dengan catatan kerja di [`../catatan/`](../catatan/).

| Dokumen | Isi |
|---|---|
| [brief-implementasi-v2.0.md](brief-implementasi-v2.0.md) | **Acuan kerja utama** — ringkasan siap-kerja (ringkasan proyek, aturan kritis, fase 0–9). |
| [prd-v1.0.md](prd-v1.0.md) | PRD versi 1.0 (latar belakang, persona, user story, KPI, risiko). Lebih lama dari brief v2.0. |
| [PRD-UI.md](PRD-UI.md) | **Acuan desain UI** — peta layar, spesifikasi tiap layar, state, alur, token desain, handoff. |
| [RENCANA-DEV.md](RENCANA-DEV.md) | **Rencana pengembangan** — prasyarat, keputusan, roadmap fase 0–9, DoD, risiko. |
| [arsitektur.md](arsitektur.md) | Tech stack, arsitektur, state machine booking, alur pembayaran & payroll. |
| [erd.md](erd.md) | Daftar tabel data inti + relasi kunci. |
| [PROGRES.md](PROGRES.md) | Catatan progres per fase (diperbarui tiap sesi). |

> **Catatan:** brief v2.0 menyebut dokumen referensi penuh `bimbel-rancangan-produk.md`
> (PRD v2.0 + arsitektur + ERD 29 tabel). Dokumen itu belum ada di repo. `prd-v1.0.md`
> adalah versi lebih lama; **bila berbeda dengan brief v2.0, brief v2.0 yang menang.**
> Bila dokumen referensi penuh ditemukan, simpan sebagai `bimbel-rancangan-produk.md`
> dan perbarui indeks ini.

## Catatan penting (brief v2.0 menang atas PRD v1.0)

- Tutor **diundang admin**, tanpa pendaftaran mandiri, **tanpa upload KTP**.
- Pembayaran tutor **payroll bulanan** oleh platform (bukan dompet + tombol tarik).
- Ada **voucher/promo** dan **kelas grup** pada MVP.
- Komplain H+3, auto-complete H+1, reschedule atomik, ledger append-only.
