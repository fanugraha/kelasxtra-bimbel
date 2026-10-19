import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../chat_repository.dart';

/// Balon pesan chat: bubble kiri/kanan, jam kirim, dan status baca.
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    required this.mine,
    required this.lastMine,
  });

  final ConversationMessage message;
  final bool mine;
  final bool lastMine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.76,
        ),
        decoration: BoxDecoration(
          color: mine ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(15),
            topRight: const Radius.circular(15),
            bottomLeft: Radius.circular(mine ? 15 : 4),
            bottomRight: Radius.circular(mine ? 4 : 15),
          ),
          border: mine ? null : Border.all(color: scheme.outline),
        ),
        child: Column(
          crossAxisAlignment: mine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              message.body,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: mine ? scheme.onPrimary : scheme.onSurface,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (mine && lastMine && message.read) ...[
                  Text(
                    'Dibaca',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  AppFormat.hm(message.createdAt),
                  // onPrimary penuh: putih 75% di brand terang hanya ±3.5:1.
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: mine ? scheme.onPrimary : scheme.onSurfaceVariant,
                  ),
                ),
                if (mine) ...[
                  const SizedBox(width: 3),
                  Icon(
                    message.read ? Icons.done_all_rounded : Icons.done_rounded,
                    size: 13,
                    // Warna: centang dibaca = onPrimary penuh agar kontras
                    // di balon brand pada mode terang & gelap.
                    color: message.read
                        ? scheme.onPrimary
                        : scheme.onPrimary.withValues(alpha: 0.65),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
