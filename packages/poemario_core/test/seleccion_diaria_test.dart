import 'package:flutter_test/flutter_test.dart';
import 'package:poemario_core/data/poema.dart';
import 'package:poemario_core/domain/seleccion_diaria.dart';

List<Poema> pool({required int autores, int porAutor = 3}) => [
      for (var a = 0; a < autores; a++)
        for (var p = 0; p < porAutor; p++)
          Poema.fromJson(
            {
              'id': 'a$a-p$p',
              'autor': 'Autor $a',
              'titulo': 'Poema $p',
              'texto': 'verso',
            },
            index: a * porAutor + p,
          ),
    ];

void main() {
  final hoy = DateTime(2026, 9, 19);

  group('determinism', () {
    test('the same date and pool always give the same poems', () {
      final p = pool(autores: 8);
      final a = SeleccionDiariaService.paraFecha(pool: p, fecha: hoy);
      final b = SeleccionDiariaService.paraFecha(pool: p, fecha: hoy);
      expect(a.poemas.map((x) => x.id), b.poemas.map((x) => x.id));
    });

    test('the time of day does not matter', () {
      final p = pool(autores: 8);
      final manana = SeleccionDiariaService.paraFecha(
          pool: p, fecha: DateTime(2026, 9, 19, 7, 30));
      final noche = SeleccionDiariaService.paraFecha(
          pool: p, fecha: DateTime(2026, 9, 19, 23, 59));
      expect(manana.poemas, noche.poemas);
    });

    test('the order the pool was built in does not matter', () {
      // A filtered pool can arrive in a different order; the day's poem must
      // not change because of it.
      final p = pool(autores: 8);
      final revuelto = p.reversed.toList();
      expect(
        SeleccionDiariaService.paraFecha(pool: p, fecha: hoy).poemas,
        SeleccionDiariaService.paraFecha(pool: revuelto, fecha: hoy).poemas,
      );
    });

    test('different days give different selections', () {
      final p = pool(autores: 12);
      final dias = {
        for (var d = 0; d < 7; d++)
          SeleccionDiariaService.paraFecha(
                  pool: p, fecha: hoy.add(Duration(days: d)))
              .poemas
              .first
              .id
      };
      expect(dias.length, greaterThan(4));
    });
  });

  group('author variety', () {
    test('the two poems of a day are by different authors', () {
      final p = pool(autores: 6);
      for (var d = 0; d < 30; d++) {
        final s = SeleccionDiariaService.paraFecha(
            pool: p, fecha: hoy.add(Duration(days: d)));
        expect(s.autores.toSet().length, s.autores.length,
            reason: 'día $d repitió autor');
      }
    });

    test('recent authors are avoided when the pool allows it', () {
      final p = pool(autores: 6);
      final s = SeleccionDiariaService.paraFecha(
        pool: p,
        fecha: hoy,
        autoresRecientes: const ['Autor 0', 'Autor 1'],
      );
      expect(s.autores, isNot(contains('Autor 0')));
      expect(s.autores, isNot(contains('Autor 1')));
    });

    test('serie carries history forward across consecutive days', () {
      final dias = SeleccionDiariaService.serie(
          pool: pool(autores: 10), desde: hoy, dias: 14);
      expect(dias.length, 14);
      for (var i = 1; i < dias.length; i++) {
        expect(
          dias[i].autores.toSet().intersection(dias[i - 1].autores.toSet()),
          isEmpty,
          reason: 'el día $i repite un autor del día anterior',
        );
      }
    });

    test('serie matches paraFecha for the first day', () {
      final p = pool(autores: 10);
      final serie = SeleccionDiariaService.serie(pool: p, desde: hoy, dias: 3);
      final suelto = SeleccionDiariaService.paraFecha(pool: p, fecha: hoy);
      // This is what makes a notification scheduled two weeks ahead name the
      // poem the app will actually show that morning.
      expect(serie.first.poemas, suelto.poemas);
    });
  });

  group('historialPara', () {
    test('picks up where a schedule made days earlier expects', () {
      final p = pool(autores: 10);
      final inicial = ['Autor 3', 'Autor 7'];
      final plan = SeleccionDiariaService.serie(
          pool: p, desde: hoy, dias: 14, autoresRecientes: inicial);
      for (var d = 0; d < 14; d++) {
        final fecha = DateTime(hoy.year, hoy.month, hoy.day + d);
        final historial = SeleccionDiariaService.historialPara(
            pool: p, desde: hoy, historialDesde: inicial, fecha: fecha);
        expect(
          SeleccionDiariaService.paraFecha(
                  pool: p, fecha: fecha, autoresRecientes: historial)
              .poemas,
          plan[d].poemas,
          reason: 'día $d',
        );
      }
    });

    test('a gap longer than the limit keeps the stored history', () {
      final historial = SeleccionDiariaService.historialPara(
        pool: pool(autores: 10),
        desde: hoy,
        historialDesde: const ['Autor 3'],
        fecha: DateTime(2027, 9, 19),
      );
      expect(historial, ['Autor 3']);
    });
  });

  group('calendar', () {
    test('serie steps one calendar day at a time across a clock change', () {
      // 25 October 2026 is 25 hours long in most of Europe. Adding
      // Duration(days: 1) to its midnight stayed on the 25th.
      final dias = SeleccionDiariaService.serie(
          pool: pool(autores: 10), desde: DateTime(2026, 10, 20), dias: 14);
      for (var i = 0; i < dias.length; i++) {
        expect(dias[i].fecha, DateTime(2026, 10, 20 + i));
      }
    });
  });

  group('degenerate pools', () {
    test('an empty pool yields nothing instead of throwing', () {
      final s = SeleccionDiariaService.paraFecha(pool: const [], fecha: hoy);
      expect(s.poemas, isEmpty);
    });

    test('a single poem is returned once, not twice', () {
      final s = SeleccionDiariaService.paraFecha(
          pool: pool(autores: 1, porAutor: 1), fecha: hoy);
      expect(s.poemas.length, 1);
    });

    test('a single author with several poems still fills the day', () {
      final s = SeleccionDiariaService.paraFecha(
          pool: pool(autores: 1, porAutor: 5), fecha: hoy);
      expect(s.poemas.length, 2);
      expect(s.poemas.first, isNot(s.poemas.last));
    });

    test('history covering the whole pool does not empty the day', () {
      final s = SeleccionDiariaService.paraFecha(
        pool: pool(autores: 2),
        fecha: hoy,
        autoresRecientes: const ['Autor 0', 'Autor 1'],
      );
      expect(s.poemas, isNotEmpty);
    });
  });
}
