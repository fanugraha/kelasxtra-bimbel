import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// Menampilkan teks yang boleh memuat potongan rumus di antara `$...$`
/// atau notasi lama tanpa dolar, mis. `x^2`, `akar3`, `cos 60 derajat`.
class MathText extends StatelessWidget {
  const MathText(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  static final _dollar = RegExp(r'(\$[^$]+\$)');
  static final _token = RegExp(r'(\s+)');
  static final _trailing = RegExp(r'[,.;:!?]+$');

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    if (looksLikeMathExpression(text)) {
      return _math(toTexExpression(text), text, base);
    }
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final part in _splitMath(mathizeText(text)))
          if (part.length > 2 && part.startsWith(r'$') && part.endsWith(r'$'))
            _math(part.substring(1, part.length - 1), part, base)
          else if (!part.contains('^'))
            Text(part, style: base)
          else
            for (final chunk in part.split(_token))
              if (chunk.trim().isEmpty)
                Text(chunk, style: base)
              else
                ..._plainChunk(chunk, base),
      ],
    );
  }

  Iterable<String> _splitMath(String input) sync* {
    var last = 0;
    for (final m in _dollar.allMatches(input)) {
      if (m.start > last) yield input.substring(last, m.start);
      yield m.group(0)!;
      last = m.end;
    }
    if (last < input.length) yield input.substring(last);
  }

  Widget _math(String tex, String label, TextStyle base) => Semantics(
    container: true,
    label: label,
    child: ExcludeSemantics(
      child: Math.tex(tex, textStyle: base, mathStyle: MathStyle.text),
    ),
  );

  List<Widget> _plainChunk(String chunk, TextStyle base) {
    if (!chunk.contains('^')) return [Text(chunk, style: base)];
    final trailing = _trailing.firstMatch(chunk)?.group(0) ?? '';
    final core = trailing.isEmpty
        ? chunk
        : chunk.substring(0, chunk.length - trailing.length);
    return [
      _math(toTexExpression(core), core, base),
      if (trailing.isNotEmpty) Text(trailing, style: base),
    ];
  }
}

/// Ubah pangkat gaya lama (`x^2`, `x^(n-1)`) menjadi sintaks TeX.
String caretToTex(String input) => input.replaceAllMapped(
  RegExp(r'\^\(([^)]*)\)|\^([A-Za-z0-9])'),
  (m) => '^{${m.group(1) ?? m.group(2)}}',
);

const _mathWords = {
  'sin',
  'cos',
  'tan',
  'akar',
  'pi',
  'derajat',
  'celsius',
  'mol',
  'cm',
  'km',
  'mm',
  'kg',
  'gram',
  'liter',
  'l',
  'n',
  'j',
  'w',
  'v',
  's',
  'm',
  'g',
  'c',
};

/// Benar bila seluruh teks tampak seperti satu ekspresi matematika
/// (dipakai untuk opsi jawaban), bukan kalimat.
bool looksLikeMathExpression(String input) {
  final s = input.trim();
  if (s.isEmpty || s.contains(r'$')) return false;
  final tokens = s.split(RegExp(r'\s+'));
  if (tokens.length > 10) return false;
  return tokens.every(_isMathToken);
}

bool _isMathToken(String raw) {
  final t = raw.replaceAll(RegExp(r'^[\(\[\{]+|[\)\]\},.;:]+$'), '');
  if (t.isEmpty) return true;
  if (RegExp(r'^[+\-−×=:/<>]+$').hasMatch(t)) return true;
  if (RegExp(r'[0-9]').hasMatch(t)) return true;
  if (RegExp(r'^[A-Za-z]$').hasMatch(t)) return true;
  return _mathWords.contains(t.toLowerCase());
}

/// Ubah satu ekspresi matematika utuh menjadi TeX (tanpa dolar).
String toTexExpression(String input) {
  var s = input.trim().replaceAll(RegExp(r'[.]$'), '');

  s = s.replaceAllMapped(
    RegExp(r'akar\s*(\d+)\s*/\s*(\d+)'),
    (m) => '\\sqrt{${m[1]}}/${m[2]}',
  );
  s = s.replaceAllMapped(RegExp(r'akar\s*(\d+)'), (m) => '\\sqrt{${m[1]}}');

  const fnTex = {'sin': r'\sin', 'cos': r'\cos', 'tan': r'\tan'};
  s = s.replaceAllMapped(
    RegExp(r'\b(sin|cos|tan)\s*(\d+)\s*derajat'),
    (m) => '${fnTex[m[1]]} ${m[2]}^\\circ',
  );
  s = s.replaceAllMapped(
    RegExp(r'(\d+)\s*derajat\s*Celsius'),
    (m) => '${m[1]}^\\circ C',
  );
  s = s.replaceAllMapped(RegExp(r'(\d+)\s*derajat'), (m) => '${m[1]}^\\circ');
  for (final e in fnTex.entries) {
    s = s.replaceAll(RegExp('(?<!\\\\)\\b${e.key}\\b'), e.value);
  }
  s = s.replaceAll(RegExp(r'\bpi\b'), r'\pi');

  s = s.replaceAllMapped(
    RegExp(r'(\d+(?:,\d+)?)\s*[x×]\s*10\^\(?(\d+)\)?'),
    (m) => '${m[1]} \\times 10^{${m[2]}}',
  );
  s = s.replaceAll(RegExp(r'\s+[x×]\s+'), r' \times ');
  s = s.replaceAllMapped(
    RegExp(r'\^\(([^)]*)\)|\^([A-Za-z0-9]+)'),
    (m) => '^{${m.group(1) ?? m.group(2)}}',
  );
  s = s.replaceAllMapped(RegExp(r'(\d),(\d)'), (m) => '${m[1]}{,}${m[2]}');
  return s;
}

/// Ubah notasi matematika sehari-hari menjadi potongan TeX `$...$`
/// di dalam kalimat campuran.
String mathizeText(String input) {
  var s = input;

  // Notasi ilmiah harus diproses sebelum perkalian biasa.
  s = s.replaceAllMapped(
    RegExp(r'(\d+(?:,\d+)?)\s*x\s*10\^(\d+)'),
    (m) =>
        r'$'
        '${m[1]} \\times 10^{${m[2]}}'
        r'$',
  );
  s = s.replaceAllMapped(
    RegExp(r'\b(CO|NO|SO)(\d+)\b'),
    (m) => '\$\\mathrm{${m[1]}_${m[2]}}\$',
  );
  s = s.replaceAll(RegExp(r'\bv0\b'), r'$v_0$');
  s = s.replaceAllMapped(
    RegExp(r'akar\s*(\d+)\s*/\s*(\d+)'),
    (m) => '\$\\sqrt{${m[1]}}/${m[2]}\$',
  );
  s = s.replaceAllMapped(RegExp(r'akar\s*(\d+)'), (m) => '\$\\sqrt{${m[1]}}\$');

  const fnTex = {'sin': r'\sin', 'cos': r'\cos', 'tan': r'\tan'};
  s = s.replaceAllMapped(RegExp(r'\b(sin|cos|tan)\s*(\d+)(\s*derajat)?\b'), (
    m,
  ) {
    final deg = m[3] == null ? '' : r'^\circ';
    return '\$${fnTex[m[1]]} ${m[2]}$deg\$';
  });
  s = s.replaceAllMapped(
    RegExp(r'\b(sin|cos|tan)\s*x\b'),
    (m) => '\$${fnTex[m[1]]} x\$',
  );

  s = s.replaceAllMapped(
    RegExp(r'(\d+)\s*derajat\s*Celsius'),
    (m) => '\$${m[1]}^\\circ\$C',
  );
  s = s.replaceAllMapped(
    RegExp(r'(\d+)\s*derajat'),
    (m) => '\$${m[1]}^\\circ\$',
  );
  s = s.replaceAll(RegExp(r'\bpi\b'), r'$\pi$');
  s = s.replaceAllMapped(
    RegExp(r'([A-Za-z])\s+x\s+([A-Za-z])'),
    (m) => '${m[1]} × ${m[2]}',
  );
  s = s.replaceAllMapped(
    RegExp(r'(\d+(?:,\d+)?)\s*x\s*(\d+(?:,\d+)?)'),
    (m) => '\$${m[1]} \\times ${m[2]}\$',
  );
  s = s.replaceAllMapped(
    RegExp(r'\b(\d+)([A-Za-z])\b'),
    (m) => '\$${m[1]}${m[2]}\$',
  );

  return s;
}
