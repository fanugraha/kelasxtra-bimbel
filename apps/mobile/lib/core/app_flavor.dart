/// Satu codebase, dua flavor: aplikasi siswa dan aplikasi tutor.
enum AppFlavor {
  siswa,
  tutor;

  String get label => this == AppFlavor.siswa ? 'Siswa' : 'Tutor';
}
