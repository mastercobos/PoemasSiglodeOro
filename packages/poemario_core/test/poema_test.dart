import 'package:flutter_test/flutter_test.dart';
import 'package:poemario_core/data/poema.dart';

Poema construir(Map<String, dynamic> json, {int index = 0}) =>
    Poema.fromJson(json, index: index);

void main() {
  group('fromJson', () {
    test('tolerates missing and null fields', () {
      final p = construir({});
      expect(p.titulo, '');
      expect(p.autor, 'Anónimo');
      expect(p.texto, '');
      expect(p.estrofas, isEmpty);
      expect(p.id, isNotEmpty);
    });

    test('prefers an explicit id from the data', () {
      final p = construir({'id': 'becquer-rima-liii', 'autor': 'Bécquer'});
      expect(p.id, 'becquer-rima-liii');
    });
  });

  group('stable ids', () {
    test('do not depend on position in the file', () {
      final json = {'autor': 'Bécquer', 'titulo': '- LIII -', 'texto': 'a\nb'};
      expect(construir(json, index: 0).id, construir(json, index: 400).id);
    });

    test('distinguish poems by the same author', () {
      final a = construir({'autor': 'Lorca', 'titulo': 'Uno', 'texto': 'x'});
      final b = construir({'autor': 'Lorca', 'titulo': 'Dos', 'texto': 'y'});
      expect(a.id, isNot(b.id));
    });

    test('survive an edit to the body of the poem', () {
      // A typo fix deep in the text must not orphan a saved favourite.
      final antes = construir(
          {'autor': 'Lorca', 'titulo': 'Uno', 'texto': 'primer verso\nsegunda'});
      final despues = construir(
          {'autor': 'Lorca', 'titulo': 'Uno', 'texto': 'primer verso\nsegundo'});
      expect(antes.id, despues.id);
    });
  });

  group('estrofas', () {
    test('splits on blank lines and keeps the author\'s structure', () {
      final p = construir({'texto': 'a\nb\nc\nd\n\ne\nf\n\ng'});
      expect(p.estrofas.map((e) => e.length), [4, 2, 1]);
    });

    test('a poem with no blank line is one stanza', () {
      final p = construir({'texto': 'a\nb\nc'});
      expect(p.estrofas, [
        ['a', 'b', 'c']
      ]);
    });

    test('tolerates whitespace-only separator lines', () {
      final p = construir({'texto': 'a\n   \nb'});
      expect(p.estrofas.length, 2);
    });
  });

  group('derived labels', () {
    test('etiqueta falls back to the first verse when untitled', () {
      final p = construir({'texto': '\n\nVolverán las oscuras golondrinas\nx'});
      expect(p.etiqueta, 'Volverán las oscuras golondrinas');
    });

    test('mostrarPrimerVerso is false when it would duplicate the title', () {
      final igual = construir({'titulo': 'Uno', 'texto': 'Uno\ndos'});
      final distinto = construir({'titulo': 'Uno', 'texto': 'otro\ndos'});
      final sinTitulo = construir({'texto': 'otro\ndos'});
      expect(igual.mostrarPrimerVerso, isFalse);
      expect(distinto.mostrarPrimerVerso, isTrue);
      expect(sinTitulo.mostrarPrimerVerso, isFalse);
    });

    test('mostrarPrimerVerso ignores quotes, punctuation and case', () {
      final entreComillas = construir({
        'titulo': '« J’ai beau comme un imbécile »',
        'texto': 'J’ai beau comme un imbécile\nRegarder dans ma maison,',
      });
      final conComa = construir({'titulo': 'Uno', 'texto': 'uno,\ndos'});
      expect(entreComillas.mostrarPrimerVerso, isFalse);
      expect(conComa.mostrarPrimerVerso, isFalse);
    });

    test('primerVersoSinComillas drops the verse\'s own quotation marks', () {
      final cita = construir({
        'titulo': 'Le Gui de chêne',
        'texto': '«\u00a0Minerve combattra !… Sur son casque divin\ndos',
      });
      final cerrada = construir({'texto': '“Hope” is the thing with feathers”\ndos'});
      final normal = construir({'texto': 'Il pleure dans mon cœur\ndos'});
      expect(cita.primerVersoSinComillas, 'Minerve combattra !… Sur son casque divin');
      expect(cita.primerVerso, startsWith('«')); // the id still hashes it
      expect(cerrada.primerVersoSinComillas, 'Hope” is the thing with feathers');
      expect(normal.primerVersoSinComillas, 'Il pleure dans mon cœur');
    });
  });
}
