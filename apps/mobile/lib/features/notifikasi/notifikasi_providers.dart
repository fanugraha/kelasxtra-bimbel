import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notifikasi_repository.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(),
);

final myNotificationsProvider = FutureProvider<List<AppNotification>>(
  (ref) => ref.read(notificationRepositoryProvider).fetchMine(),
);
