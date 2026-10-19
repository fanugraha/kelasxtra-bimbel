import 'dart:convert';
import 'dart:io';

import 'package:bimbel_mobile/features/bank_soal/widgets/math_text.dart';
import 'package:flutter_math_fork/tex.dart';
import 'package:flutter_test/flutter_test.dart';

/// Gagal bila TeX tidak bisa di-parse (artinya simbol tidak akan tampil).
void expectParses(String tex, {String? from}) {
  expect(
    () => TexParser(tex, const TexParserSettings()).parse(),
    returnsNormally,
    reason: 'TeX tidak valid: "$tex"${from == null ? '' : ' (dari "$from")'}',
  );
}

void main() {
  test('caretToTex mengubah pangkat tanpa dolar', () {
    expect(caretToTex('x^2'), r'x^{2}');
    expect(caretToTex('m/s^2'), r'm/s^{2}');
    expect(caretToTex('x^(n-1)'), r'x^{n-1}');
    expect(caretToTex('tanpa pangkat'), 'tanpa pangkat');
  });

  test('looksLikeMathExpression hanya untuk ekspresi, bukan kalimat', () {
    expect(looksLikeMathExpression('0,5 mol'), isTrue);
    expect(looksLikeMathExpression('F = m a'), isTrue);
    expect(looksLikeMathExpression('6,02 x 10^23'), isTrue);
    expect(looksLikeMathExpression('x^2/2 + C'), isTrue);
    expect(looksLikeMathExpression('akar3/2'), isTrue);
    expect(looksLikeMathExpression('go'), isFalse);
    expect(looksLikeMathExpression('tidak ada'), isFalse);
    expect(looksLikeMathExpression('homozigot resesif'), isFalse);
    expect(
      looksLikeMathExpression('Air mendidih pada suhu 100 derajat Celsius.'),
      isFalse,
    );
  });

  test('toTexExpression: simbol dasar, pecahan bersusun, satuan tegak', () {
    expect(toTexExpression('akar3/2'), r'\frac{\sqrt{3}}{2}');
    expect(toTexExpression('-akar3/2'), r'-\frac{\sqrt{3}}{2}');
    expect(toTexExpression('1/2'), r'\frac{1}{2}');
    expect(toTexExpression('cos 60 derajat'), r'\cos 60^\circ');
    expect(toTexExpression('100 derajat Celsius'), r'100^\circ C');
    expect(toTexExpression('6,02 x 10^23'), r'6{,}02 \times 10^{23}');
    expect(toTexExpression('2 x 3 = 6'), r'2 \times 3 = 6');
    expect(toTexExpression('x^2 + 5x'), r'x^{2} + 5x');
    expect(toTexExpression('x^2/2 + C'), r'x^{2}/2 + C');
    expect(toTexExpression('F = m / a'), 'F = m / a');
    expect(toTexExpression('0,5 mol'), r'0{,}5\,\mathrm{mol}');
    expect(toTexExpression('5 m/s^2'), r'5\,\mathrm{m/s}^{2}');
    expect(toTexExpression('36 cm^2'), r'36\,\mathrm{cm}^{2}');
    expect(toTexExpression('H2O'), r'\mathrm{H_{2}O}');
  });

  test('rumus kimia: indeks bawah, unsur 2 huruf, kurung', () {
    expect(chemToTex('H2SO4'), r'\mathrm{H_{2}SO_{4}}');
    expect(chemToTex('Ca(OH)2'), r'\mathrm{Ca(OH)_{2}}');
    expect(chemToTex('C6H12O6'), r'\mathrm{C_{6}H_{12}O_{6}}');
    expect(chemToTex('NaCl'), isNull); // tanpa indeks → biarkan teks
    expect(
      mathizeText('gas CO2 (Mr = 44)'),
      r'gas $\mathrm{CO_{2}}$ (Mr = 44)',
    );
    expect(
      mathizeText('Reaksi H2 + O2 -> H2O'),
      r'Reaksi $\mathrm{H_{2}}$ + $\mathrm{O_{2}}$ → $\mathrm{H_{2}O}$',
    );
    expect(mathizeText('Genotipe XY dan AA'), 'Genotipe XY dan AA');
  });

  test('mathizeText mengubah simbol di dalam kalimat campuran', () {
    expect(mathizeText('akar2/2'), r'$\frac{\sqrt{2}}{2}$');
    expect(mathizeText('nilai cos 60 derajat'), r'nilai $\cos 60^\circ$');
    expect(mathizeText('sudut 180 derajat'), r'sudut $180^\circ$');
    expect(mathizeText('suhu 100 derajat Celsius'), r'suhu $100^\circ$C');
    expect(mathizeText('turunan sin x'), r'turunan $\sin x$');
    expect(mathizeText('pi = 22/7'), r'$\pi$ = $\frac{22}{7}$');
    expect(mathizeText('2 x 3 = 6'), r'$2 \times 3$ = 6');
    expect(
      mathizeText('6,02 x 10^23 partikel'),
      r'$6,02 \times 10^{23}$ partikel',
    );
    expect(mathizeText('s = v0 t'), r's = $v_0$ t');
    expect(mathizeText('Persilangan Aa x Aa'), 'Persilangan Aa × Aa');
    expect(mathizeText('teks biasa'), 'teks biasa');
    expect(mathizeText('x >= 2 dan y <= 3'), 'x ≥ 2 dan y ≤ 3');
    expect(
      mathizeText('jika g = 10 m/s^2 maka'),
      r'jika g = $10\,\mathrm{m/s}^{2}$ maka',
    );
  });

  test('pecahan berkurung jadi bersusun, kurung pangkat tidak', () {
    expect(
      mathizeText('limit dari (x^2 - 4)/(x - 2) adalah'),
      r'limit dari $\frac{x^{2} - 4}{x - 2}$ adalah',
    );
    expect(mathizeText('x^(n+1)/(n+1)'), 'x^(n+1)/(n+1)');
  });

  test('mathParts menggabungkan teks & memisahkan rumus', () {
    final parts = mathParts('Nilai dari sin 30 derajat adalah ...');
    expect(parts.map((p) => p.tex), [false, true, false]);
    expect(parts[1].text, r'\sin 30^\circ');
    expect(mathParts('akar3/2').single.tex, isTrue);
  });

  test('SEMUA teks soal asli (soal, opsi, pembahasan) ter-parse', () {
    final texts =
        (jsonDecode(
                  File('test/fixtures/question_texts.json').readAsStringSync(),
                )
                as List)
            .cast<String>();
    expect(texts, isNotEmpty);
    var texCount = 0;
    for (final t in texts) {
      for (final p in mathParts(t)) {
        if (!p.tex) continue;
        texCount++;
        expectParses(p.text, from: t);
      }
      // Tidak boleh ada sisa sintaks mentah di bagian teks.
      for (final p in mathParts(t).where((p) => !p.tex)) {
        expect(p.text.contains(r'$'), isFalse, reason: 'dolar tersisa: "$t"');
        expect(p.text.contains('akar'), isFalse, reason: 'akar mentah: "$t"');
      }
    }
    expect(texCount, greaterThan(100));
  });
}
