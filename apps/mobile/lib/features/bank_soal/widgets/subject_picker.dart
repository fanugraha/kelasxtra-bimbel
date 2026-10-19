import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/person_photo.dart';

/// Satu mapel di navigator: nama + jumlah topik.
typedef SubjectEntry = ({String name, int topics});

/// Navigasi utama Bank Soal: pilihan jenjang (bila >1) lalu chip mapel yang
/// bisa digeser. Mapel terpilih terisi brand; ikon mapel membantu anak
/// mengenali mapel tanpa membaca.
class SubjectPicker extends StatelessWidget {
  const SubjectPicker({
    super.key,
    required this.jenjangs,
    required this.jenjang,
    required this.onJenjang,
    required this.subjects,
    required this.selected,
    required this.onSelect,
  });

  final List<String> jenjangs;
  final String jenjang;
  final ValueChanged<String> onJenjang;
  final List<SubjectEntry> subjects;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Pilih mapel',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (jenjangs.length > 1)
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final j in jenjangs)
                      GestureDetector(
                        onTap: () => onJenjang(j),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: j == jenjang
                                ? scheme.surface
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            j,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: j == jenjang
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: j == jenjang
                                  ? palette.brand
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 46,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: subjects.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, i) {
              final s = subjects[i];
              final active = s.name == selected;
              return Material(
                color: active ? palette.brand : scheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                  side: BorderSide(
                    color: active ? palette.brand : scheme.outline,
                  ),
                ),
                child: InkWell(
                  onTap: () => onSelect(s.name),
                  customBorder: const StadiumBorder(),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 14, 6),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: active
                                ? palette.onBrand.withValues(alpha: 0.18)
                                : palette.brandSoft,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            subjectIconFor(s.name),
                            size: 17,
                            color: active ? palette.onBrand : palette.brand,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          s.name,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: active ? palette.onBrand : scheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${s.topics}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: active
                                ? palette.onBrand.withValues(alpha: 0.85)
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
