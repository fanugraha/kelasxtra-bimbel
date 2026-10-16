import 'package:flutter/material.dart';

import '../../widgets/empty_state.dart';

/// Layar sementara untuk fitur yang belum dibangun (mis. Jadwal).
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.icon,
    this.message,
  });

  final String title;
  final IconData icon;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: EmptyState(
        icon: icon,
        title: 'Segera hadir',
        message: message ?? 'Fitur $title sedang disiapkan.',
      ),
    );
  }
}
