/// Kapan tombol "Gabung Zoom" boleh dipakai.
///
/// Dipakai bersama oleh Detail sesi dan kartu agenda Jadwal, jadi aturannya
/// ditaruh di `core` supaya tidak ada dua versi yang bisa berbeda.
library;

enum MeetingPhase {
  /// Sesi bukan daring (offline) atau sudah tidak berlaku — tidak ada tombol.
  tidakBerlaku,

  /// Sesi online tetapi tentor belum menempel tautannya.
  belumAdaLink,

  /// Tautan ada, tetapi jendela waktunya belum dibuka.
  belumWaktunya,

  /// Sedang dalam jendela waktu — tombol aktif.
  bisaGabung,

  /// Jendela waktu sudah lewat.
  sudahLewat,
}

class MeetingStatus {
  const MeetingStatus({required this.phase, this.opensAt, this.closesAt});

  final MeetingPhase phase;

  /// Kapan tombol mulai aktif (15 menit sebelum jadwal).
  final DateTime? opensAt;

  /// Kapan tombol berhenti aktif (15 menit setelah sesi berakhir).
  final DateTime? closesAt;

  bool get canJoin => phase == MeetingPhase.bisaGabung;

  bool get isRelevant => phase != MeetingPhase.tidakBerlaku;
}

/// Tautan dibuka 15 menit sebelum jadwal dan ditutup 15 menit setelah
/// sesi berakhir, supaya tautan tidak disebar jauh sebelum waktunya.
const meetingOpenBefore = Duration(minutes: 15);
const meetingCloseAfter = Duration(minutes: 15);

/// Status tombol gabung untuk satu sesi.
MeetingStatus meetingStatus({
  required String mode,
  required String status,
  required DateTime scheduledAt,
  required int durationMinutes,
  String? url,
  DateTime? now,
}) {
  const berlaku = {'confirmed', 'in_progress', 'completed'};
  if (mode != 'online' || !berlaku.contains(status)) {
    return const MeetingStatus(phase: MeetingPhase.tidakBerlaku);
  }
  if (url == null || url.trim().isEmpty) {
    return const MeetingStatus(phase: MeetingPhase.belumAdaLink);
  }

  final opensAt = scheduledAt.subtract(meetingOpenBefore);
  final closesAt = scheduledAt
      .add(Duration(minutes: durationMinutes))
      .add(meetingCloseAfter);
  final at = now ?? DateTime.now();

  if (at.isBefore(opensAt)) {
    return MeetingStatus(
      phase: MeetingPhase.belumWaktunya,
      opensAt: opensAt,
      closesAt: closesAt,
    );
  }
  if (at.isAfter(closesAt)) {
    return MeetingStatus(
      phase: MeetingPhase.sudahLewat,
      opensAt: opensAt,
      closesAt: closesAt,
    );
  }
  return MeetingStatus(
    phase: MeetingPhase.bisaGabung,
    opensAt: opensAt,
    closesAt: closesAt,
  );
}
