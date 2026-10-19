import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/errors.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../booking/payment_status_screen.dart';
import '../../booking/qris_screen.dart';
import '../paket_providers.dart';
import '../paket_repository.dart';

/// Kartu satu paket di daftar "Paket Saya" + aksi bayar/jadwal.
class PackageCard extends ConsumerStatefulWidget {
  const PackageCard({super.key, required this.item});

  final PackageItem item;

  @override
  ConsumerState<PackageCard> createState() => _PackageCardState();
}

class _PackageCardState extends ConsumerState<PackageCard> {
  var _paying = false;

  /// Paket yang belum lunas bisa dibayar dari sini; Edge Function memakai ulang
  /// tautan Snap yang sama selama tagihan belum kedaluwarsa.
  Future<void> _pay() async {
    final item = widget.item;
    setState(() => _paying = true);
    try {
      final result = await ref
          .read(paketRepositoryProvider)
          .resumePackageSnap(item.id);
      if (!mounted) return;
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => QrisScreen(result: result)));
      if (!mounted) return;
      ref.invalidate(myPackagesProvider);
      context.push(
        '/pembayaran',
        extra: {
          'orderId': result.orderId,
          'amount': result.amount,
          'packageId': result.packageId ?? item.id,
          'retry': PaymentRetry(packageId: item.id),
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(cleanError(e))));
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;
    final pending = item.status == 'pending_payment';
    final tone = item.aktif
        ? StatusTone.success
        : pending
        ? StatusTone.warning
        : StatusTone.neutral;

    return AppCard(
      onTap: () => context.push('/tutor/${item.tutorId}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusBadge(label: item.statusLabel, tone: tone),
              const Spacer(),
              Text(
                '#${item.id.substring(0, 6).toUpperCase()}',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: context.palette.brandSoft,
                child: Text(
                  (item.tutorName ?? 'T').isEmpty
                      ? 'T'
                      : item.tutorName![0].toUpperCase(),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: context.palette.brand,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.tutorName ?? 'Tutor',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.subjectName ?? '-'} · ${item.jenjang} · '
                      '${item.durationMinutes} menit · '
                      '${item.mode == 'online' ? 'Online' : 'Offline'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _PackageInfoRow(label: 'Jadwal', value: item.jadwalLabel),
          _PackageInfoRow(
            label: 'Jumlah',
            value: '${item.totalSesi} pertemuan',
          ),
          if (pending) ...[
            _PackageInfoRow(label: 'Mulai', value: item.mulaiLabel),
            _PackageInfoRow(
              label: 'Harga paket',
              value: AppFormat.rupiah(item.priceTotal),
              emphasize: true,
            ),
          ] else ...[
            _PackageInfoRow(label: 'Mulai', value: item.mulaiLabel),
            _PackageInfoRow(
              label: 'Berlaku sampai',
              value: item.masaBerlakuLabel,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: item.aktif
                      ? () => context.go('/jadwal')
                      : pending
                      ? (_paying ? null : _pay)
                      : null,
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
                  child: _paying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : Text(
                          pending
                              ? 'Lanjutkan bayar'
                              : item.aktif
                              ? 'Lihat jadwal'
                              : 'Riwayat',
                        ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton(
                  onPressed: pending
                      ? () => context.push('/paket/beli/${item.tutorId}')
                      : () => context.push('/tutor/${item.tutorId}'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 42),
                  ),
                  child: Text(pending ? 'Ubah jadwal' : 'Lihat tutor'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PackageInfoRow extends StatelessWidget {
  const _PackageInfoRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              // Warna: nilai netral; harga ditonjolkan dengan semibold netral,
              // bukan brand.
              style: emphasize
                  ? theme.textTheme.titleSmall
                  : theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
