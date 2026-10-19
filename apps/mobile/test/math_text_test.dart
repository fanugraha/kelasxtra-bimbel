import 'package:bimbel_mobile/features/bank_soal/widgets/math_text.dart';
import 'package:flutter_test/flutter_test.dart';

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

  test('toTexExpression mengubah simbol dasar', () {
    expect(toTexExpression('akar3/2'), r'\sqrt{3}/2');
    expect(toTexExpression('cos 60 derajat'), r'\cos 60^\circ');
    expect(toTexExpression('100 derajat Celsius'), r'100^\circ C');
    expect(toTexExpression('6,02 x 10^23'), r'6{,}02 \times 10^{23}');
    expect(toTexExpression('2 x 3 = 6'), r'2 \times 3 = 6');
    expect(toTexExpression('x^2 + 5x'), r'x^{2} + 5x');
    expect(toTexExpression('F = m / a'), 'F = m / a');
  });

  test('mathizeText mengubah simbol di dalam kalimat campuran', () {
    expect(mathizeText('akar2/2'), r'$\sqrt{2}/2$');
    expect(mathizeText('nilai cos 60 derajat'), r'nilai $\cos 60^\circ$');
    expect(mathizeText('sudut 180 derajat'), r'sudut $180^\circ$');
    expect(mathizeText('suhu 100 derajat Celsius'), r'suhu $100^\circ$C');
    expect(mathizeText('turunan sin x'), r'turunan $\sin x$');
    expect(mathizeText('pi = 22/7'), r'$\pi$ = 22/7');
    expect(mathizeText('2 x 3 = 6'), r'$2 \times 3$ = 6');
    expect(
      mathizeText('6,02 x 10^23 partikel'),
      r'$6,02 \times 10^{23}$ partikel',
    );
    expect(mathizeText('gas CO2 (Mr = 44)'), r'gas $\mathrm{CO_2}$ (Mr = 44)');
    expect(mathizeText('s = v0 t'), r's = $v_0$ t');
    expect(mathizeText('Persilangan Aa x Aa'), 'Persilangan Aa × Aa');
    expect(mathizeText('teks biasa'), 'teks biasa');
  });
}
