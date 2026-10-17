import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// Menampilkan teks yang boleh memuat potongan rumus di antara `$...$`.
class MathText extends StatelessWidget {
  const MathText(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  static final _pattern = RegExp(r'(\$[^$]+\$)');

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    final parts = text.split(_pattern);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final part in parts)
          if (part.length > 2 && part.startsWith(r'$') && part.endsWith(r'$'))
            Math.tex(
              part.substring(1, part.length - 1),
              textStyle: base,
              mathStyle: MathStyle.text,
            )
          else if (part.isNotEmpty)
            Text(part, style: base),
      ],
    );
  }
}
