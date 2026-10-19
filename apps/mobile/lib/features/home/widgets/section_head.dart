import 'package:flutter/material.dart';

import '../../../core/widgets/screen_head.dart';

class SectionHead extends StatelessWidget {
  const SectionHead({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        if (actionLabel != null)
          TextLink(
            label: actionLabel!,
            onTap: onAction,
            icon: Icons.chevron_right_rounded,
          ),
      ],
    );
  }
}
