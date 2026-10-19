import 'package:flutter/widgets.dart';
import '../../../core/dates.dart';
import '../../../core/errors.dart';

import '../../../core/format.dart';
import '../../../core/snap_result.dart';
import '../../katalog/katalog_repository.dart';
import '../paket_repository.dart';

/// Judul tiap langkah wizard beli paket.
const beliPaketStepTitles = <String>[
  'Paket & durasi',
  'Jadwal mingguan',
  'Ringkasan & bayar',
];

/// State + logika wizard beli paket (4/8/12 pertemuan, seminggu sekali).
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

  /// Kolom teks langkah 3 — dimiliki controller supaya pengosongan saat
  /// pilihan berubah (mapel/mode/jumlah) tidak perlu dikoordinasi layar.
  final address = TextEditingController();
  final voucher = TextEditingController();

  int step = 0;

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

  bool get isLastStep => step == beliPaketStepTitles.length - 1;

  @override
  void dispose() {
    address.dispose();
    voucher.dispose();
    super.dispose();
  }

  /// Memberi tahu layar untuk menggambar ulang (mis. saat alamat diketik).
  void refresh() => notifyListeners();

  // --- Navigasi langkah ---------------------------------------------------

  void goTo(int index) {
    if (index < 0 || index >= beliPaketStepTitles.length) return;
    step = index;
    notifyListeners();
  }

  // --- Pilihan langkah 1 --------------------------------------------------

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
    startMinutes = null;
    _resetVoucher();
    notifyListeners();
  }

  void selectSize(int value) {
    size = value;
    _resetVoucher();
    notifyListeners();
  }

  // --- Pilihan langkah 2 --------------------------------------------------

  void selectSlot(TutorAvailabilityItem value) {
    slot = value;
    date = null;
    startMinutes = null;
    notifyListeners();
  }

  void selectDate(DateTime value) {
    date = value;
    startMinutes = null;
    notifyListeners();
  }

  void selectStartMinutes(int value) {
    startMinutes = value;
    notifyListeners();
  }

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

  /// Jam mulai yang muat durasi di slot, belum lewat bila hari ini, dan tidak
  /// bentrok dengan sesi lain untuk SEMUA pertemuan mingguan paket.
  List<int> startTimes({
    required DateTime date,
    required TutorAvailabilityItem slot,
    required List<BusySlot> busy,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final start = AppFormat.minutesOfTime(slot.startTime);
    final end = AppFormat.minutesOfTime(slot.endTime);
    final isToday = isSameDay(date, clock);
    final nowMinutes = clock.hour * 60 + clock.minute;
    return [
      for (var m = start; m + duration <= end; m += 60)
        if ((!isToday || m > nowMinutes) &&
            meetingsFree(date, m, busy, now: clock))
          m,
    ];
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

  bool dateHasSlot(
    DateTime date,
    TutorAvailabilityItem slot,
    List<BusySlot> busy, {
    DateTime? now,
  }) => startTimes(date: date, slot: slot, busy: busy, now: now).isNotEmpty;

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
