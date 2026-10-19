import 'package:flutter/widgets.dart';
import '../../../core/dates.dart';
import '../../../core/errors.dart';

import '../../../core/format.dart';
import '../../../core/snap_result.dart';
import '../../katalog/katalog_repository.dart';
import '../paket_repository.dart';

/// Satu pilihan jadwal mingguan siap pakai, mis. "Sabtu · 11.00" mulai tanggal
/// terdekat yang kosong untuk SEMUA pertemuan paket.
class WeeklyOption {
  const WeeklyOption({
    required this.slot,
    required this.date,
    required this.startMinutes,
    this.clash,
  });

  final TutorAvailabilityItem slot;
  final DateTime date;
  final int startMinutes;

  /// Terisi bila bentrok dengan les siswa sendiri (pilihan dinonaktifkan).
  final String? clash;
}

/// Sesi milik siswa sendiri yang tidak boleh ditabrak paket baru.
typedef MySession = ({DateTime start, DateTime end, String label});

/// State + logika beli paket satu halaman (4/8/12 pertemuan, seminggu sekali).
///
/// Menyimpan pilihan siswa, perhitungan jadwal murni, dan panggilan jaringan
/// (pratinjau voucher, buat Snap). Navigasi tetap di layar agar file ini tak
/// bergantung pada `BuildContext`.
class BeliPaketController extends ChangeNotifier {
  BeliPaketController({
    required this.tutorId,
    required PaketRepository repository,
    required void Function() invalidateBusy,
  }) : _repository = repository,
       _invalidateBusy = invalidateBusy;

  final String tutorId;
  final PaketRepository _repository;
  final void Function() _invalidateBusy;

  /// Kolom teks — dimiliki controller supaya pengosongan saat pilihan berubah
  /// (mapel/mode/jumlah) tidak perlu dikoordinasi layar.
  final address = TextEditingController();
  final voucher = TextEditingController();

  TutorSubjectItem? subject;
  String? mode;
  int duration = 60;
  int size = 4;
  TutorAvailabilityItem? slot;
  DateTime? date;
  int? startMinutes;

  // Voucher yang sudah lolos pratinjau (diskon rupiah dari server).
  String? voucherCode;
  int voucherDiscount = 0;
  String? voucherError;
  bool checkingVoucher = false;

  bool submitting = false;
  String? error;

  /// Siswa memilih memakai poin (1 poin = Rp1) untuk memotong tagihan.
  bool useCredits = false;

  void setUseCredits(bool value) {
    useCredits = value;
    notifyListeners();
  }

  @override
  void dispose() {
    address.dispose();
    voucher.dispose();
    super.dispose();
  }

  /// Memberi tahu layar untuk menggambar ulang (mis. saat alamat diketik).
  void refresh() => notifyListeners();

  // --- Pilihan paket ------------------------------------------------------

  void selectSubject(TutorSubjectItem value) {
    subject = value;
    _resetSchedule();
    _resetVoucher();
    notifyListeners();
  }

  void selectMode(String value) {
    mode = value;
    _resetSchedule();
    _resetVoucher();
    notifyListeners();
  }

  void selectDuration(int value) {
    duration = value;
    _resetSchedule();
    _resetVoucher();
    notifyListeners();
  }

  void selectSize(int value) {
    size = value;
    // Jumlah pertemuan mengubah tanggal mana yang masih kosong.
    _resetSchedule();
    _resetVoucher();
    notifyListeners();
  }

  // --- Pilihan jadwal -----------------------------------------------------

  void selectWeekly(WeeklyOption option) {
    slot = option.slot;
    date = option.date;
    startMinutes = option.startMinutes;
    notifyListeners();
  }

  bool isSelected(WeeklyOption o) =>
      slot == o.slot && date == o.date && startMinutes == o.startMinutes;

  // --- Voucher ------------------------------------------------------------

  /// Pratinjau diskon dari server; [price] null berarti harga belum diketahui.
  Future<void> applyVoucher(String code, int? price) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) {
      _failVoucher('Isi kode voucher dulu.');
      return;
    }
    if (price == null) {
      _failVoucher('Harga paket belum diketahui.');
      return;
    }
    checkingVoucher = true;
    voucherError = null;
    notifyListeners();
    try {
      final diskon = await _repository.checkVoucher(
        code: trimmed,
        price: price,
      );
      voucherCode = trimmed.toUpperCase();
      voucherDiscount = diskon;
    } catch (e) {
      voucherCode = null;
      voucherDiscount = 0;
      voucherError = cleanError(e);
    } finally {
      checkingVoucher = false;
      notifyListeners();
    }
  }

  void clearVoucher() {
    _resetVoucher();
    notifyListeners();
  }

  void _failVoucher(String message) {
    voucherCode = null;
    voucherDiscount = 0;
    voucherError = message;
    notifyListeners();
  }

  // --- Kirim --------------------------------------------------------------

  /// Buat tagihan Snap. Mengembalikan null bila gagal (pesan di [error]).
  Future<SnapResult?> submit() async {
    submitting = true;
    error = null;
    notifyListeners();
    try {
      return await _repository.createPackageSnap(
        tutorId: tutorId,
        subjectId: subject!.subjectId,
        jenjang: subject!.jenjang,
        durationMinutes: duration,
        mode: mode!,
        totalSesi: size,
        scheduleStartDate: date!,
        scheduleStartTime: AppFormat.hhmm(startMinutes!),
        address: mode == 'offline' ? address.text.trim() : null,
        voucherCode: voucherCode,
        useCredits: useCredits,
      );
    } catch (e) {
      // Muat ulang slot sibuk: kemungkinan slot baru terisi orang lain.
      _invalidateBusy();
      error = cleanError(e);
      return null;
    } finally {
      submitting = false;
      notifyListeners();
    }
  }

  // --- Pilihan dari data tutor -------------------------------------------

  List<String> availableModes(List<TutorAvailabilityItem> availability) {
    final modes = <String>{for (final a in availability) a.mode};
    return ['online', 'offline'].where(modes.contains).toList();
  }

  List<TutorAvailabilityItem> slotOptions(
    List<TutorAvailabilityItem> availability,
  ) => mode == null
      ? const []
      : availability.where((x) => x.mode == mode).toList();

  // --- Logika jadwal ------------------------------------------------------

  /// Semua jam mulai di semua slot tutor untuk mode terpilih. Tiap jam memakai
  /// tanggal terdekat yang kosong di jadwal tutor untuk seluruh pertemuan; jam
  /// yang penuh disembunyikan, yang bentrok dengan les siswa sendiri ditandai.
  List<WeeklyOption> weeklyOptions({
    required List<TutorAvailabilityItem> availability,
    required List<BusySlot> tutorBusy,
    required List<MySession> mine,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final mineBusy = [
      for (final m in mine) BusySlot(start: m.start, end: m.end),
    ];
    final options = <WeeklyOption>[];
    for (final s in slotOptions(availability)) {
      final start = AppFormat.minutesOfTime(s.startTime);
      final end = AppFormat.minutesOfTime(s.endTime);
      for (var m = start; m + duration <= end; m += 60) {
        DateTime? first;
        for (final d in nextDates(s.dayOfWeek, now: clock)) {
          final past =
              isSameDay(d, clock) && m <= clock.hour * 60 + clock.minute;
          if (!past && meetingsFree(d, m, tutorBusy)) {
            first = d;
            break;
          }
        }
        if (first == null) continue;
        options.add(
          WeeklyOption(
            slot: s,
            date: first,
            startMinutes: m,
            clash: meetingsFree(first, m, mineBusy)
                ? null
                : _clashLabel(first, m, mine),
          ),
        );
      }
    }
    options.sort((a, b) {
      final byDay = a.date.weekday.compareTo(b.date.weekday);
      return byDay != 0 ? byDay : a.startMinutes.compareTo(b.startMinutes);
    });
    return options;
  }

  String _clashLabel(DateTime date, int startMinutes, List<MySession> mine) {
    for (var i = 0; i < size; i++) {
      final start = DateTime(
        date.year,
        date.month,
        date.day,
      ).add(Duration(days: i * 7, minutes: startMinutes));
      final end = start.add(Duration(minutes: duration));
      for (final s in mine) {
        if (start.isBefore(s.end) && end.isAfter(s.start)) {
          return 'Bentrok dengan les ${s.label}';
        }
      }
    }
    return 'Bentrok dengan jadwalmu';
  }

  /// Tanggal seluruh pertemuan: pertemuan pertama + 7 hari berikutnya.
  List<DateTime> meetingDates() {
    if (date == null) return const [];
    return [for (var i = 0; i < size; i++) date!.add(Duration(days: i * 7))];
  }

  String scheduleLabel() {
    if (slot == null || date == null || startMinutes == null) return '—';
    return '${slot!.dayName} ${AppFormat.hhmm(startMinutes!)} · '
        'mulai ${AppFormat.dateShort(date!)}';
  }

  /// Empat tanggal terdekat untuk hari tertentu (0 = Minggu … 6 = Sabtu).
  List<DateTime> nextDates(int dayOfWeek, {DateTime? now}) {
    final base = now ?? DateTime.now();
    final today = DateTime(base.year, base.month, base.day);
    final dartWeekday = dayOfWeek == 0 ? 7 : dayOfWeek;
    final first = today.add(
      Duration(days: (dartWeekday - today.weekday + 7) % 7),
    );
    return [for (var i = 0; i < 4; i++) first.add(Duration(days: i * 7))];
  }

  /// Semua pertemuan (tiap 7 hari) bebas dari rentang sibuk.
  bool meetingsFree(
    DateTime date,
    int startMinutes,
    List<BusySlot> busy, {
    DateTime? now,
  }) {
    for (var i = 0; i < size; i++) {
      final day = DateTime(
        date.year,
        date.month,
        date.day,
      ).add(Duration(days: i * 7));
      final start = day.add(Duration(minutes: startMinutes));
      final end = start.add(Duration(minutes: duration));
      for (final b in busy) {
        if (start.isBefore(b.end) && end.isAfter(b.start)) return false;
      }
    }
    return true;
  }

  void _resetSchedule() {
    slot = null;
    date = null;
    startMinutes = null;
  }

  void _resetVoucher() {
    voucherCode = null;
    voucherDiscount = 0;
    voucherError = null;
    voucher.clear();
  }
}
