import 'package:flutter/material.dart';

/// Peran warna Kelasxtra beserta alasannya. Pakai PERAN, bukan warna mentah:
/// widget bertanya "ini elemen apa?" lalu mengambil peran yang cocok.
///
/// Hierarki (aturan 60-30-10):
/// - ±60% netral — latar, kartu, teks. Informasi biasa tetap netral.
/// - ±30% tonal — container pucat untuk pengelompokan & status ringan.
/// - ±10% warna penuh — hanya untuk hal yang harus dilihat lebih dulu.
///
/// | Peran        | Warna        | Alasan psikologis & kapan dipakai                    |
/// |--------------|--------------|-----------------------------------------------------|
/// | brand        | teal-biru    | Tenang, fokus, tepercaya — orang tua menitipkan uang |
/// |              |              | & anaknya. Satu aksi utama per layar, navigasi aktif,|
/// |              |              | pilihan terpilih.                                    |
/// | reward       | emas/amber   | Medali & bintang: rasa "aku berhasil". Poin, rating, |
/// |              |              | pencapaian, progres belajar.                         |
/// | challenge    | ungu         | Ambisi & rasa ingin tahu. Tryout, bank soal, latihan |
/// |              |              | — ajakan menantang diri, beda dari aksi transaksi.   |
/// | promo        | coral        | Hangat & mendesak tanpa semarah merah bahaya. Diskon,|
/// |              |              | voucher, harga hemat, promo terbatas.                |
/// | success      | hijau        | "Aman, sudah beres": lunas, terkonfirmasi, hadir.    |
/// | warning      | oranye       | "Perlu perhatianmu": menunggu bayar, waktu hampir    |
/// |              |              | habis.                                               |
/// | danger       | merah        | Gagal, batal, hapus — hanya untuk risiko nyata.      |
/// | info         | biru         | Tips & informasi netral yang tidak menuntut aksi.    |
///
/// Harga, tanggal, dan angka biasa sengaja NETRAL (teks tebal): itu informasi,
/// bukan ajakan — supaya tidak bersaing dengan tombol aksi utama.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.brand,
    required this.onBrand,
    required this.brandSoft,
    required this.reward,
    required this.onReward,
    required this.rewardSoft,
    required this.challenge,
    required this.onChallenge,
    required this.challengeSoft,
    required this.promo,
    required this.onPromo,
    required this.promoSoft,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
    required this.info,
    required this.infoSoft,
  });

  final Color brand;
  final Color onBrand;

  /// Container pucat brand: chip/grup tonal, banner ringan.
  final Color brandSoft;

  final Color reward;
  final Color onReward;
  final Color rewardSoft;

  final Color challenge;
  final Color onChallenge;
  final Color challengeSoft;

  final Color promo;
  final Color onPromo;
  final Color promoSoft;

  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color dangerSoft;
  final Color info;
  final Color infoSoft;

  /// Terang: tiap warna lolos WCAG AA (≥4.5:1) untuk teks putih di atasnya,
  /// sebagai teks di atas versi Soft-nya, dan sebagai teks di latar halaman.
  static const light = AppPalette(
    brand: Color(0xFF007596),
    onBrand: Colors.white,
    brandSoft: Color(0xFFE3F3F8),
    reward: Color(0xFF98641A),
    onReward: Colors.white,
    rewardSoft: Color(0xFFFFF4DC),
    challenge: Color(0xFF6D4FD8),
    onChallenge: Colors.white,
    challengeSoft: Color(0xFFEFEAFD),
    promo: Color(0xFFC9321B),
    onPromo: Colors.white,
    promoSoft: Color(0xFFFFEDE8),
    success: Color(0xFF117962),
    successSoft: Color(0xFFE2F5EF),
    warning: Color(0xFFA55A05),
    warningSoft: Color(0xFFFFF1DF),
    danger: Color(0xFFC23636),
    dangerSoft: Color(0xFFFDE8E8),
    info: Color(0xFF2A6BBC),
    infoSoft: Color(0xFFE6F0FB),
  );

  /// Gelap: warna lebih terang & kurang jenuh (tidak "bergetar" di latar gelap),
  /// container berupa versi transparan di atas permukaan gelap.
  static const dark = AppPalette(
    brand: Color(0xFF8B8BF0),
    onBrand: Color(0xFF0B0B10),
    brandSoft: Color(0xFF23213B),
    reward: Color(0xFFF0932B),
    onReward: Color(0xFF1A1104),
    rewardSoft: Color(0xFF33240F),
    challenge: Color(0xFFA78BFA),
    onChallenge: Color(0xFF160F2E),
    challengeSoft: Color(0xFF241C40),
    promo: Color(0xFFF87171),
    onPromo: Color(0xFF2A0E0E),
    promoSoft: Color(0xFF3A1E1E),
    success: Color(0xFF22C55E),
    successSoft: Color(0xFF12301C),
    warning: Color(0xFFF5A524),
    warningSoft: Color(0xFF362711),
    danger: Color(0xFFEF4444),
    dangerSoft: Color(0xFF3A1F1F),
    info: Color(0xFF60A5FA),
    infoSoft: Color(0xFF17253F),
  );

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      brand: l(brand, other.brand),
      onBrand: l(onBrand, other.onBrand),
      brandSoft: l(brandSoft, other.brandSoft),
      reward: l(reward, other.reward),
      onReward: l(onReward, other.onReward),
      rewardSoft: l(rewardSoft, other.rewardSoft),
      challenge: l(challenge, other.challenge),
      onChallenge: l(onChallenge, other.onChallenge),
      challengeSoft: l(challengeSoft, other.challengeSoft),
      promo: l(promo, other.promo),
      onPromo: l(onPromo, other.onPromo),
      promoSoft: l(promoSoft, other.promoSoft),
      success: l(success, other.success),
      successSoft: l(successSoft, other.successSoft),
      warning: l(warning, other.warning),
      warningSoft: l(warningSoft, other.warningSoft),
      danger: l(danger, other.danger),
      dangerSoft: l(dangerSoft, other.dangerSoft),
      info: l(info, other.info),
      infoSoft: l(infoSoft, other.infoSoft),
    );
  }
}

/// `context.palette.reward` dsb.
extension AppPaletteContext on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}
