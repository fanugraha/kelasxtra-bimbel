import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'empty_state.dart';

/// Menangani tiga keadaan `AsyncValue` (memuat / gagal / data) dengan tampilan
/// seragam, termasuk tombol "Coba lagi". Menggantikan pola `.when(...)` yang
/// berulang di tiap layar.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.builder,
    this.onRetry,
    this.errorTitle = 'Gagal memuat data',
    this.loading,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;
  final String errorTitle;
  final Widget? loading;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () =>
          loading ?? const Center(child: CircularProgressIndicator()),
      error: (error, _) => EmptyState(
        icon: Icons.cloud_off_rounded,
        title: errorTitle,
        message: '$error',
        action: onRetry == null
            ? null
            : FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba lagi'),
              ),
      ),
      data: builder,
    );
  }
}
