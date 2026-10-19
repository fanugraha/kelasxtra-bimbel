import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Pesan galat inline yang seragam. Tak menampilkan apa pun bila [message] null.
class AppErrorText extends StatelessWidget {
  const AppErrorText(this.message, {super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null || message!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Text(
        message!,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.error,
        ),
      ),
    );
  }
}
