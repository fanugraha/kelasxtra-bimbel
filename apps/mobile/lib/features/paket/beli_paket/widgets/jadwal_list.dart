import 'package:flutter/material.dart';

import '../../../../core/format.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_card.dart';

/// Daftar tanggal pertemuan yang akan dibuat.
class JadwalList extends StatelessWidget {
  const JadwalList({
    super.key,
    required this.dates,
    required this.startMinutes,
  });

  final List<DateTime> dates;
  final int startMinutes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (dates.isEmpty) return const SizedBox.shrink();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${dates.length} pertemuan terjadwal',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < dates.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text('${i + 1}.', style: theme.textTheme.labelSmall),
                  ),
                  Expanded(
                    child: Text(
                      AppFormat.dateLong(dates[i]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    AppFormat.hhmm(startMinutes),
                    style: theme.textTheme.titleSmall,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
