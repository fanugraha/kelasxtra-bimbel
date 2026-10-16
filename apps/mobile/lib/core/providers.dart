import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_flavor.dart';

/// Diisi di entry point (main_siswa.dart / main_tutor.dart) lewat override.
final appFlavorProvider = Provider<AppFlavor>(
  (ref) => throw StateError('appFlavorProvider belum di-override'),
);
