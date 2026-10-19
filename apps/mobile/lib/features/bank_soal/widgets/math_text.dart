import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// Satu potongan teks soal: teks biasa atau rumus TeX (tanpa dolar).
typedef MathPart = ({String text, bool tex});

/// Menampilkan teks yang boleh memuat potongan rumus di antara `$...$`
/// atau notasi sehari-hari tanpa dolar, mis. `x^2`, `akar3/2`,
/// `cos 60 derajat`, `H2SO4`, `5 m/s^2`, `(x^2 - 4)/(x - 2)`.
///
/// Teks dan rumus mengalir dalam SATU paragraf (`Text.rich` + `WidgetSpan`)
/// supaya kalimat panjang tetap terbaca wajar. Bila sebuah rumus gagal
/// di-parse, yang tampil adalah teks aslinya (bukan pesan error).
class MathText extends StatelessWidget {
  const MathText(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    final parts = mathParts(text);
    // Satu ekspresi utuh (mis. opsi jawaban "akar3/2"): gaya display agar
    // pecahan bersusun tampil penuh, tidak mengecil.
    if (parts.length == 1 && parts.single.tex) {
      return _math(parts.single.text, text, base, MathStyle.display);
    }
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          for (final p in parts)
            if (p.tex)
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: _math(p.text, p.text, base, MathStyle.text),
              )
            else
              TextSpan(text: p.text),
        ],
      ),
    );
  }

  Widget _math(String tex, String label, TextStyle base, MathStyle mathStyle) =>
      Semantics(
        container: true,
        label: label,
        child: ExcludeSemantics(
          child: Math.tex(
            tex,
            textStyle: base,
            mathStyle: mathStyle,
            onErrorFallback: (_) => Text(label, style: base),
          ),
        ),
      );
}

final _dollar = RegExp(r'(\$[^$]+\$)');
final _token = RegExp(r'(\s+)');
final _trailing = RegExp(r'[,.;:!?]+$');

/// Pecah teks menjadi potongan teks biasa & rumus TeX. Fungsi murni supaya
/// bisa diuji (tes mem-parse setiap potongan TeX dari semua soal).
List<MathPart> mathParts(String text) {
  if (looksLikeMathExpression(text)) {
    return [(text: toTexExpression(text), tex: true)];
  }
  final out = <MathPart>[];
  void addText(String t) {
    if (t.isEmpty) return;
    if (out.isNotEmpty && !out.last.tex) {
      out[out.length - 1] = (text: out.last.text + t, tex: false);
    } else {
      out.add((text: t, tex: false));
    }
  }

  for (final part in _splitDollar(mathizeText(text))) {
    if (part.length > 2 && part.startsWith(r'$') && part.endsWith(r'$')) {
      out.add((text: part.substring(1, part.length - 1), tex: true));
    } else if (!part.contains('^')) {
      addText(part);
    } else {
      // Sisa pangkat gaya lama di tengah kalimat: ubah per kata.
      for (final chunk in _splitKeep(part, _token)) {
        if (chunk.trim().isEmpty || !chunk.contains('^')) {
          addText(chunk);
          continue;
        }
        final trailing = _trailing.firstMatch(chunk)?.group(0) ?? '';
        final core = trailing.isEmpty
            ? chunk
            : chunk.substring(0, chunk.length - trailing.length);
        out.add((text: toTexExpression(core), tex: true));
        addText(trailing);
      }
    }
  }
  return out;
}

Iterable<String> _splitDollar(String input) sync* {
  var last = 0;
  for (final m in _dollar.allMatches(input)) {
    if (m.start > last) yield input.substring(last, m.start);
    yield m.group(0)!;
    last = m.end;
  }
  if (last < input.length) yield input.substring(last);
}

/// Seperti `split`, tetapi pemisahnya ikut dikembalikan (spasi tidak hilang).
Iterable<String> _splitKeep(String input, RegExp sep) sync* {
  var last = 0;
  for (final m in sep.allMatches(input)) {
    if (m.start > last) yield input.substring(last, m.start);
    yield m.group(0)!;
    last = m.end;
  }
  if (last < input.length) yield input.substring(last);
}

/// Terapkan [fn] hanya pada bagian di LUAR potongan `$...$` yang sudah ada.
String _outsideMath(String s, String Function(String) fn) => [
  for (final part in _splitDollar(s))
    part.length > 2 && part.startsWith(r'$') && part.endsWith(r'$')
        ? part
        : fn(part),
].join();

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

/// Satuan yang ditulis tegak (bukan miring seperti variabel) bila didahului
/// angka. Urut dari yang terpanjang agar `m/s` tidak terbaca `m`.
const _units = [
  'liter',
  'gram',
  'mol',
  'm/s',
  'km',
  'cm',
  'mm',
  'kg',
  'L',
  'N',
  'J',
  'W',
  'V',
  'g',
  'm',
  's',
];

/// Rumus kimia: deretan simbol unsur (huruf besar + kecil opsional) dengan
/// angka indeks, boleh berkurung, mis. `H2O`, `H2SO4`, `Ca(OH)2`, `CO2`.
final _chem = RegExp(
  r'(?<![A-Za-z0-9_\\{])((?:[A-Z][a-z]?\d*|\((?:[A-Z][a-z]?\d*)+\)\d*)+)(?![A-Za-z0-9])',
);

/// `H2SO4` → `\mathrm{H_{2}SO_{4}}`; null bila bukan rumus kimia (tanpa
/// angka indeks, mis. `NaCl`, `XY`).
String? chemToTex(String token) {
  if (!RegExp(r'[A-Z\)]\d').hasMatch(token)) return null;
  final body = token.replaceAllMapped(
    RegExp(r'([A-Za-z\)])(\d+)'),
    (m) => '${m[1]}_{${m[2]}}',
  );
  return '\\mathrm{$body}';
}

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

  // Rumus kimia utuh/di dalam ekspresi (sebelum aturan lain menyentuh angka).
  s = s.replaceAllMapped(_chem, (m) => chemToTex(m[1]!) ?? m[1]!);

  s = s.replaceAllMapped(
    RegExp(r'akar\s*(\d+)\s*/\s*(\d+)'),
    (m) => '\\frac{\\sqrt{${m[1]}}}{${m[2]}}',
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

  // Angka + satuan → satuan tegak, mis. "0,5 mol", "5 m/s^2", "36 cm^2".
  final unitAlt = _units.map(RegExp.escape).join('|');
  s = s.replaceAllMapped(
    RegExp('(\\d)\\s+($unitAlt)(?:\\^\\(?(\\d+)\\)?)?(?![A-Za-z])'),
    (m) => '${m[1]}\\,\\mathrm{${m[2]}}${m[3] == null ? '' : '^{${m[3]}}'}',
  );

  // Pecahan angka sederhana → bersusun: "1/2", "3/5".
  s = s.replaceAllMapped(
    RegExp(r'(?<![\w}^.,])(\d+)\s*/\s*(\d+)(?![\w,])'),
    (m) => '\\frac{${m[1]}}{${m[2]}}',
  );
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

  // Simbol ketik → simbol asli.
  s = s
      .replaceAll('->', '→')
      .replaceAll('<=', '≤')
      .replaceAll('>=', '≥')
      .replaceAll('!=', '≠');

  // Pecahan berkurung: "(x^2 - 4)/(x - 2)" → pecahan bersusun. Tidak berlaku
  // untuk kurung pangkat ("x^(n+1)/(n+1)") atau yang menempel kata/kurung lain.
  s = s.replaceAllMapped(
    RegExp(r'(?<![\^\w\)])\(([^()$]+)\)\s*/\s*\(([^()$]+)\)'),
    (m) => '\$\\frac{${toTexExpression(m[1]!)}}{${toTexExpression(m[2]!)}}\$',
  );

  // Notasi ilmiah harus diproses sebelum perkalian biasa.
  s = s.replaceAllMapped(
    RegExp(r'(\d+(?:,\d+)?)\s*x\s*10\^(\d+)'),
    (m) =>
        r'$'
        '${m[1]} \\times 10^{${m[2]}}'
        r'$',
  );
  s = _outsideMath(
    s,
    (t) => t.replaceAllMapped(_chem, (m) {
      final tex = chemToTex(m[1]!);
      return tex == null ? m[1]! : '\$$tex\$';
    }),
  );
  s = s.replaceAll(RegExp(r'\bv0\b'), r'$v_0$');
  s = s.replaceAllMapped(
    RegExp(r'(-?)akar\s*(\d+)\s*/\s*(\d+)'),
    (m) => '\$${m[1]}\\frac{\\sqrt{${m[2]}}}{${m[3]}}\$',
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

  // Angka + satuan berpangkat/majemuk: "10 m/s^2", "36 cm^2" → satuan tegak.
  s = s.replaceAllMapped(
    RegExp(r'(\d+(?:,\d+)?)\s*(m/s|cm|km|mm|m)\^(\d+)'),
    (m) => '\$${m[1]}\\,\\mathrm{${m[2]}}^{${m[3]}}\$',
  );

  s = s.replaceAllMapped(
    RegExp(r'([A-Za-z])\s+x\s+([A-Za-z])'),
    (m) => '${m[1]} × ${m[2]}',
  );
  s = s.replaceAllMapped(
    RegExp(r'(\d+(?:,\d+)?)\s*x\s*(\d+(?:,\d+)?)'),
    (m) => '\$${m[1]} \\times ${m[2]}\$',
  );

  // Pecahan angka sederhana di kalimat: "22/7", "1/2 a t^2" → bersusun.
  s = _outsideMath(
    s,
    (t) => t.replaceAllMapped(
      RegExp(r'(?<![\w/.,^])(\d+)/(\d+)(?![\w/,])'),
      (m) => '\$\\frac{${m[1]}}{${m[2]}}\$',
    ),
  );
  s = _outsideMath(
    s,
    (t) => t.replaceAllMapped(
      RegExp(r'\b(\d+)([A-Za-z])\b'),
      (m) => '\$${m[1]}${m[2]}\$',
    ),
  );

  return s;
}
