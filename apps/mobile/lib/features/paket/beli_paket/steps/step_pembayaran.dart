import 'package:flutter/material.dart';

import '../../../../core/format.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_error_text.dart';
import '../../../../core/widgets/credit_toggle.dart';
import '../../../../core/widgets/person_photo.dart';
import '../../../katalog/katalog_repository.dart';
import '../../paket_providers.dart';
import '../beli_paket_controller.dart';
import '../widgets/checkout_parts.dart';
import '../widgets/voucher_field.dart';

/// Rincian harga yang sudah dihitung layar (harga paket → voucher → poin).
typedef CheckoutAmounts = ({int? price, int discount, int credits, int? pay});

/// Langkah 2 — Ringkasan pembayaran: info tahan slot, tutor, detail kelas,
/// voucher & poin, lalu rincian biaya. Bayar dari bar bawah.
class StepPembayaran extends StatefulWidget {
  const StepPembayaran({
    super.key,
    required this.controller,
    required this.detail,
    required this.amounts,
    required this.onEdit,
    required this.onApplyVoucher,
    required this.onClearVoucher,
  });

  final BeliPaketController controller;
  final TutorDetail detail;
  final CheckoutAmounts amounts;

  /// Kembali ke langkah 1 untuk mengubah pilihan.
  final VoidCallback onEdit;
  final VoidCallback onApplyVoucher;
  final VoidCallback onClearVoucher;

  @override
  State<StepPembayaran> createState() => _StepPembayaranState();
}

class _StepPembayaranState extends State<StepPembayaran> {
  var _showDates = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    const gap = SizedBox(height: AppSpacing.md);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _HoldBanner(),
        gap,
        _TutorCard(detail: widget.detail, subject: c.subject),
        gap,
        _classDetail(context),
        gap,
        CheckoutSection(
          icon: Icons.confirmation_number_outlined,
          title: 'Pakai voucher & makin hemat',
          hint: 'Opsional. Satu voucher per transaksi.',
          child: VoucherField(
            controller: c,
            onApply: widget.onApplyVoucher,
            onClear: widget.onClearVoucher,
          ),
        ),
        CreditToggle(
          value: c.useCredits,
          onChanged: c.setUseCredits,
          total: widget.amounts.price == null
              ? null
              : widget.amounts.price! - widget.amounts.discount,
        ),
        gap,
        _costs(context),
        AppErrorText(c.error),
      ],
    );
  }

  Widget _classDetail(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final c = widget.controller;
    final dates = c.meetingDates();
    final online = c.mode == 'online';

    return CheckoutSection(
      icon: Icons.class_rounded,
      title: 'Detail kelas',
      trailing: TextButton(
        onPressed: widget.onEdit,
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        child: const Text('Ubah'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InfoRow(
            icon: Icons.menu_book_rounded,
            label: 'Mapel',
            value:
                '${c.subject?.subjectName ?? '-'} · ${c.subject?.jenjang ?? ''}',
          ),
          InfoRow(
            icon: online ? Icons.videocam_outlined : Icons.home_outlined,
            label: 'Metode',
            value: online ? 'Online (Zoom)' : 'Tatap muka',
          ),
          InfoRow(
            icon: Icons.timer_outlined,
            label: 'Durasi',
            value: '${c.duration} menit / pertemuan',
          ),
          InfoRow(
            icon: Icons.event_repeat_rounded,
            label: 'Jadwal',
            value: c.slot == null || c.startMinutes == null
                ? '-'
                : 'Tiap ${c.slot!.dayName}, ${AppFormat.hhmm(c.startMinutes!)}',
          ),
          InfoRow(
            icon: Icons.layers_outlined,
            label: 'Paket',
            value: '${c.size} pertemuan · ${paketMasaBerlaku(c.size)}',
          ),
          if (!online && c.address.text.trim().isNotEmpty)
            InfoRow(
              icon: Icons.place_outlined,
              label: 'Alamat',
              value: c.address.text.trim(),
            ),
          if (dates.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Material(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: () => setState(() => _showDates = !_showDates),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Lihat ${dates.length} tanggal pertemuan',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Icon(
                            _showDates
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded,
                            color: scheme.primary,
                          ),
                        ],
                      ),
                      if (_showDates) ...[
                        const SizedBox(height: AppSpacing.sm),
                        for (var i = 0; i < dates.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 26,
                                  child: Text(
                                    '${i + 1}.',
                                    style: theme.textTheme.labelSmall,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    AppFormat.dateLong(dates[i]),
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                                Text(
                                  AppFormat.hhmm(c.startMinutes!),
                                  style: theme.textTheme.titleSmall,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _costs(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.palette;
    final c = widget.controller;
    final a = widget.amounts;

    Widget line(String label, String value, {Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: color ?? scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    return CheckoutSection(
      icon: Icons.receipt_long_rounded,
      title: 'Rincian biaya',
      child: a.price == null
          ? Text(
              'Harga paket belum diset admin untuk kombinasi ini.',
              style: theme.textTheme.bodySmall,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                line(
                  'Paket ${c.size} × ${c.duration} menit',
                  AppFormat.rupiah(a.price!),
                ),
                if (a.discount > 0)
                  line(
                    c.voucherCode == null
                        ? 'Voucher'
                        : 'Voucher ${c.voucherCode}',
                    '−${AppFormat.rupiah(a.discount)}',
                    color: palette.promo,
                  ),
                if (a.credits > 0)
                  line(
                    'Poin',
                    '−${AppFormat.rupiah(a.credits)}',
                    color: palette.reward,
                  ),
                const SizedBox(height: 6),
                const _DashedLine(),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Total pembayaran',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      AppFormat.rupiah(a.pay ?? 0),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Setara ${AppFormat.rupiah((a.price! - a.discount) ~/ c.size)} '
                  'per pertemuan · sudah termasuk biaya layanan.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
    );
  }
}

/// Banner info: slot ditahan saat lanjut bayar (seperti pengingat waktu di
/// referensi, tanpa hitung mundur karena penahanan baru mulai saat bayar).
class _HoldBanner extends StatelessWidget {
  const _HoldBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.infoSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(Icons.info_rounded, size: 20, color: palette.info),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Cek lagi pilihanmu. Setelah menekan Bayar, jadwal semua '
              'pertemuan ditahan 30 menit sampai pembayaran QRIS selesai.',
              style: theme.textTheme.bodySmall?.copyWith(color: palette.info),
            ),
          ),
        ],
      ),
    );
  }
}

class _TutorCard extends StatelessWidget {
  const _TutorCard({required this.detail, required this.subject});

  final TutorDetail detail;
  final TutorSubjectItem? subject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final t = detail.tutor;
    final subjects = {for (final s in detail.subjects) s.subjectId}.length;

    Widget stat(String value, String label) => Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(label, style: theme.textTheme.labelSmall),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: scheme.outline),
      ),
      child: Row(
        children: [
          PersonPhoto(
            name: t.fullName,
            photoUrl: t.photoUrl,
            subjectLine: subject?.subjectName,
            size: 84,
            radius: AppRadius.md,
            showVerified: true,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  t.education?.isNotEmpty == true
                      ? t.education!
                      : 'Tutor Kelasxtra',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Row(
                    children: [
                      stat(
                        '★ ${t.ratingAvg.toStringAsFixed(1).replaceAll('.', ',')}',
                        'Rating',
                      ),
                      Container(width: 1, height: 26, color: scheme.outline),
                      stat('$subjects', 'Mapel'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outline;
    return LayoutBuilder(
      builder: (context, box) {
        final n = (box.maxWidth / 8).floor();
        return Row(
          children: [
            for (var i = 0; i < n; i++)
              Container(
                width: 4,
                height: 1.2,
                margin: const EdgeInsets.only(right: 4),
                color: color,
              ),
          ],
        );
      },
    );
  }
}
