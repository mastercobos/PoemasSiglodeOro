import 'package:flutter_test/flutter_test.dart';
import 'package:poemario_core/data/poema.dart';
import 'package:publicador_diario/publicador_diario.dart';

Poema _poema(int i, String autor, {String titulo = ''}) => Poema.fromJson({
      'id': 'p$i',
      'autor': autor,
      'titulo': titulo,
      'texto': 'Verso primero del poema $i,\nverso segundo',
    }, index: i);

void main() {
  final pool = [
    for (var i = 0; i < 60; i++) _poema(i, 'Autor ${i % 9}'),
  ];

  test('the same day always gives the same two poems', () {
    final dia = DateTime(2027, 3, 14);
    final a = seleccionPara(pool, dia).poemas.map((p) => p.id);
    final b = seleccionPara([...pool.reversed], dia).poemas.map((p) => p.id);
    expect(a, hasLength(2));
    expect(a, b);
  });

  test('no author repeats from one day to the next', () {
    for (var d = 0; d < 40; d++) {
      final hoy = seleccionPara(pool, DateTime(2026, 10, 1 + d)).autores;
      final manana = seleccionPara(pool, DateTime(2026, 10, 2 + d)).autores;
      expect(hoy.toSet().intersection(manana.toSet()), isEmpty,
          reason: 'día $d');
      expect(hoy.toSet(), hasLength(2));
    }
  });

  test('a day before the series starts still gets poems', () {
    expect(seleccionPara(pool, DateTime(2026, 9, 1)).poemas, hasLength(2));
  });

  test('tags: title, author, app, then the extras, without commas or repeats',
      () {
    final poema =
        _poema(1, 'Quevedo', titulo: '«Cerrar podrá mis ojos, la postrera…»');
    expect(
      etiquetasPara(poema, 'Poemario - Siglo de Oro',
          ['poesía', 'quevedo', 'Siglo de Oro']),
      [
        'Cerrar podrá mis ojos la postrera',
        'Quevedo',
        'Poemario - Siglo de Oro',
        'poesía',
        'Siglo de Oro',
      ],
    );
  });

  test("the edition's numbering is left off the title and its tag", () {
    final poema = _poema(2, 'Villamediana',
        titulo: '- CXLVIII - Josefa Vaca, comedianta');
    expect(tituloPara(poema), 'Josefa Vaca, comedianta');
    expect(
        etiquetasPara(poema, 'App', const []).first, 'Josefa Vaca comedianta');
    expect(
        tituloPara(_poema(4, 'Lope',
            titulo: '- 1329 - Jornada II, INFANTE De Mirad a quién alabáis')),
        'Jornada II, INFANTE De Mirad a quién alabáis');
  });

  test('a title that is only numbering gives way to the first verse', () {
    final poema = _poema(5, 'Sor Juana', titulo: '- 96 -');
    expect(tituloPara(poema), 'Verso primero del poema 5,');
    expect(etiquetasPara(poema, 'App', const []).first,
        'Verso primero del poema 5');
  });

  test('a blank number is numbering too', () {
    expect(tituloPara(_poema(7, 'Quevedo', titulo: '-  - A una dama tuerta')),
        'A una dama tuerta');
    expect(tituloPara(_poema(8, 'Quevedo', titulo: '-  -')),
        'Verso primero del poema 8,');
  });

  test('a dash inside a title is kept', () {
    expect(tituloPara(_poema(6, 'Góngora', titulo: 'Soneto - A Córdoba')),
        'Soneto - A Córdoba');
  });

  test('an untitled poem is tagged with its first verse', () {
    expect(etiquetasPara(_poema(3, 'Garcilaso'), 'App', const []).first,
        'Verso primero del poema 3');
  });
}
