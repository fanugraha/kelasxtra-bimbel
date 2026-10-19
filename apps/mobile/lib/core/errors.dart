/// Membersihkan pesan galat server dari prefiks "Exception: " dan menerjemahkan
/// galat penjaga slot dari database menjadi kalimat yang bisa dimengerti pemakai.
String cleanError(Object? error) {
  final raw = error.toString().replaceFirst('Exception: ', '');
  if (raw.contains('bookings_no_tutor_overlap') ||
      raw.contains('bookings_no_student_overlap')) {
    return 'Slot ini baru saja terisi. Silakan pilih jam lain, ya.';
  }
  if (raw.contains('Tautan harus berupa')) {
    return 'Tautan harus alamat Zoom yang benar, contoh: https://zoom.us/j/123456789';
  }
  if (raw.contains('Tautan Zoom hanya untuk sesi online')) {
    return 'Sesi ini offline (tatap muka), jadi tidak perlu tautan Zoom.';
  }
  return raw;
}
