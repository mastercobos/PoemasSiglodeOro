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

  group('plegarParaOrden equivalence', () {
    // The original per-rune implementation, kept as the reference the
    // optimised one must match exactly: it drives sort order and the search
    // index, so any drift silently reorders authors or breaks matches.
    String referencia(String s) {
      final b = StringBuffer();
      for (final r in s.toLowerCase().runes) {
        b.write(switch (String.fromCharCode(r)) {
          'á' || 'à' || 'ä' || 'â' || 'ã' || 'å' => 'a',
          'é' || 'è' || 'ë' || 'ê' => 'e',
          'í' || 'ì' || 'ï' || 'î' => 'i',
          'ó' || 'ò' || 'ö' || 'ô' || 'õ' => 'o',
          'ú' || 'ù' || 'ü' || 'û' => 'u',
          'ç' => 'c',
          'ñ' => 'n~',
          'ÿ' => 'y',
          'œ' => 'oe',
          'æ' => 'ae',
          final otro => otro,
        });
      }
      return b.toString();
    }

    test('matches the reference for every single BMP code unit', () {
      for (var c = 0; c <= 0xFFFF; c++) {
        final s = String.fromCharCode(c);
        expect(plegarParaOrden(s), referencia(s), reason: 'U+${c.toRadixString(16)}');
      }
    });

    test('matches the reference on mixed strings', () {
      const casos = [
        '',
        'sin cambios',
        'ÁÉÍÓÚ Ñandú Ç àèìòù äëïöü âêîôû ãõ å',
        'ñ al principio y al final ñ',
        'a\u{1F600}ñ\u{1F600}b',
        'İstanbul ǅ ẞ',
        'Volverán las oscuras golondrinas — Bécquer',
        'Œuvres, cœur, Ægir, L’Haÿ-les-Roses',
      ];
      for (final s in casos) {
        expect(plegarParaOrden(s), referencia(s), reason: s);
      }
    });
  });

  group('plegarParaOrden', () {
    test('folds diacritics so accented names sort in place', () {
      final nombres = ['Zorrilla', 'Ángel', 'Antonio']
        ..sort((a, b) => plegarParaOrden(a).compareTo(plegarParaOrden(b)));
      // The old toLowerCase().compareTo() put Ángel last, after Zorrilla.
      expect(nombres, ['Ángel', 'Antonio', 'Zorrilla']);
    });

    test('spells out œ and æ so French searches match', () {
      expect(plegarParaOrden('Le Cœur'), 'le coeur');
      expect(plegarParaOrden('Ægir'), 'aegir');
      final palabras = ['cœur', 'cobalt', 'coffre']
        ..sort((a, b) => plegarParaOrden(a).compareTo(plegarParaOrden(b)));
      expect(palabras, ['cobalt', 'cœur', 'coffre']);
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

    test('numeralesNaturales: an inline numeral sorts by value', () {
      final cmp = comparadorDeTitulos(EstrategiaOrden.numeralesNaturales);
      final titulos = ['Sonnet IX', 'Sonnet II', 'Sonnet V', 'Sonnet I']
        ..sort(cmp);
      // Lexically "IX" < "V", which is wrong; by value 1 < 2 < 5 < 9.
      expect(titulos, ['Sonnet I', 'Sonnet II', 'Sonnet V', 'Sonnet IX']);
    });

    test('numeralesNaturales: different prefixes stay grouped and ordered', () {
      final cmp = comparadorDeTitulos(EstrategiaOrden.numeralesNaturales);
      final titulos = ['Canto II', 'Canto I', 'Sonnet II', 'Sonnet I']
        ..sort(cmp);
      expect(titulos, ['Canto I', 'Canto II', 'Sonnet I', 'Sonnet II']);
    });

    test('numeralesNaturales: a second, nested numeral compares in turn', () {
      final cmp = comparadorDeTitulos(EstrategiaOrden.numeralesNaturales);
      final titulos = ['Canto IV IX', 'Canto IV II', 'Canto II I']..sort(cmp);
      expect(titulos, ['Canto II I', 'Canto IV II', 'Canto IV IX']);
    });

    test('numeralesNaturales: a shorter title sorts before a longer one that '
        'starts the same way', () {
      final cmp = comparadorDeTitulos(EstrategiaOrden.numeralesNaturales);
      final titulos = ['Part I, Section I', 'Part I']..sort(cmp);
      expect(titulos, ['Part I', 'Part I, Section I']);
    });

    test('numeralesNaturales: a word that only looks like a numeral stays '
        'text', () {
      final cmp = comparadorDeTitulos(EstrategiaOrden.numeralesNaturales);
      // "Maud" is not "M" + "aud": the letters aren't a whole-word numeral.
      final titulos = ['Maud', 'Dover Beach']..sort(cmp);
      expect(titulos, ['Dover Beach', 'Maud']);
    });

    test('numeralesNaturales: matches romanosPrimero-style titles too', () {
      final cmp = comparadorDeTitulos(EstrategiaOrden.numeralesNaturales);
      expect(cmp('- IX -', '- V -'), greaterThan(0));
    });
  });
}
