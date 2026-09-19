import 'package:flutter_test/flutter_test.dart';
import 'package:poemario_core/domain/orden_titulos.dart';

void main() {
  group('romanoAEntero', () {
    test('parses well-formed numerals', () {
      expect(romanoAEntero('I'), 1);
      expect(romanoAEntero('XIV'), 14);
      expect(romanoAEntero('MCMXCIV'), 1994);
      expect(romanoAEntero(' xiv '), 14);
    });

    test('rejects malformed input', () {
      expect(romanoAEntero(''), isNull);
      expect(romanoAEntero('IIII'), isNull);
      expect(romanoAEntero('Amor'), isNull);
      expect(romanoAEntero('XIVX'), isNull);
    });
  });

  group('numeroDeTitulo', () {
    test('reads the "- N -" prefix', () {
      expect(numeroDeTitulo('- C -'), 100);
      expect(numeroDeTitulo('- XIV - El amor'), 14);
    });

    test('accepts en and em dashes, which appear in the source data', () {
      expect(numeroDeTitulo('– IX –'), 9);
      expect(numeroDeTitulo('— IX —'), 9);
    });

    test('ignores titles without the pattern', () {
      expect(numeroDeTitulo('Amor eterno'), isNull);
      expect(numeroDeTitulo('XIV sin guiones'), isNull);
    });
  });

  group('plegarParaOrden', () {
    test('folds diacritics so accented names sort in place', () {
      final nombres = ['Zorrilla', 'Ángel', 'Antonio']
        ..sort((a, b) => plegarParaOrden(a).compareTo(plegarParaOrden(b)));
      // The old toLowerCase().compareTo() put Ángel last, after Zorrilla.
      expect(nombres, ['Ángel', 'Antonio', 'Zorrilla']);
    });

    test('sorts ñ immediately after n', () {
      final palabras = ['nuez', 'ñandú', 'nada', 'ola']
        ..sort((a, b) => plegarParaOrden(a).compareTo(plegarParaOrden(b)));
      expect(palabras, ['nada', 'nuez', 'ñandú', 'ola']);
    });
  });

  group('comparadorDeTitulos', () {
    test('romanosPrimero: numerals in numeric order, ahead of prose', () {
      final cmp = comparadorDeTitulos(EstrategiaOrden.romanosPrimero);
      final titulos = ['Amor eterno', '- X -', '- II -', 'Balada']..sort(cmp);
      expect(titulos, ['- II -', '- X -', 'Amor eterno', 'Balada']);
    });

    test('romanosPrimero: equal numerals fall through to the text', () {
      final cmp = comparadorDeTitulos(EstrategiaOrden.romanosPrimero);
      // The old version returned 0 here, so the order drifted between runs.
      expect(cmp('- II - beta', '- II - alfa'), greaterThan(0));
      expect(cmp('- II - alfa', '- II - beta'), lessThan(0));
    });

    test('alfabetico ignores the numeral convention entirely', () {
      final cmp = comparadorDeTitulos(EstrategiaOrden.alfabetico);
      final titulos = ['Ozymandias', '- X -', 'Adonais']..sort(cmp);
      expect(titulos.first, '- X -'); // sorts as punctuation, not as 10
      expect(titulos.sublist(1), ['Adonais', 'Ozymandias']);
    });
  });
}
