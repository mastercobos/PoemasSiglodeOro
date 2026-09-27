import 'package:flutter_test/flutter_test.dart';
import 'package:poemario_core/data/poema_repository.dart';
import 'package:poemario_core/domain/orden_titulos.dart';

import 'support/asset_falso.dart';
import 'support/harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('split anthology', _pruebasDivididas);
  final comparador = comparadorDeTitulos(EstrategiaOrden.romanosPrimero);

  test('groups by author and sorts each group with the app comparator',
      () async {
    final a = await cargarDesdeAssetFalso([
      {'id': '1', 'autor': 'Bécquer', 'titulo': '- X -', 'texto': 'v'},
      {'id': '2', 'autor': 'Bécquer', 'titulo': 'Amor', 'texto': 'v'},
      {'id': '3', 'autor': 'Bécquer', 'titulo': '- II -', 'texto': 'v'},
      {'id': '4', 'autor': 'Ángela', 'titulo': 'Uno', 'texto': 'v'},
    ], comparador);

    expect(a.porAutor['Bécquer']!.map((p) => p.titulo),
        ['- II -', '- X -', 'Amor']);
    // Diacritic-folded author order: Ángela before Bécquer.
    expect(a.autores, ['Ángela', 'Bécquer']);
  });

  test('resolves poems by their stable id', () async {
    final a = await anthologyDePrueba();
    expect(a.porId('a1-p2')?.autor, 'Autor 1');
    expect(a.porId('no-existe'), isNull);
  });

  test('a missing asset raises AnthologyLoadException, not a crash', () async {
    registrarAsset('assets/otro.json', '[]');
    expect(
      () => const PoemaRepository(
              assetPath: 'assets/poemas.json',
              compararTitulos: _alfabetico)
          .cargar(),
      throwsA(isA<AnthologyLoadException>()),
    );
  });

  test('malformed JSON raises AnthologyLoadException', () async {
    registrarAsset('assets/poemas.json', '{ not json');
    expect(
      () => const PoemaRepository(
              assetPath: 'assets/poemas.json',
              compararTitulos: _alfabetico)
          .cargar(),
      throwsA(isA<AnthologyLoadException>()),
    );
  });

  test('an empty anthology raises rather than rendering an empty app',
      () async {
    registrarAsset('assets/poemas.json', '[]');
    expect(
      () => const PoemaRepository(
              assetPath: 'assets/poemas.json',
              compararTitulos: _alfabetico)
          .cargar(),
      throwsA(isA<AnthologyLoadException>()),
    );
  });
}

int _alfabetico(String a, String b) => a.compareTo(b);

/// The same poems as a split anthology (index + text chunks), laid out the
/// way `seleccionar.py` writes the English one.
Map<String, String> _dividida(List<Map<String, dynamic>> poemas,
    {int porTrozo = 2, String carpeta = 'assets/poemas'}) {
  final autores = <String>[];
  final filas = <List<Object>>[];
  final inicios = <int>[];
  final trozos = <List<String>>[];
  for (var i = 0; i < poemas.length; i++) {
    final p = poemas[i];
    final autor = p['autor'] as String;
    if (!autores.contains(autor)) autores.add(autor);
    final texto = p['texto'] as String;
    final primera = texto
        .split('\n')
        .firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
    filas.add([p['titulo'] as String, autores.indexOf(autor), primera]);
    if (i % porTrozo == 0) {
      inicios.add(i);
      trozos.add([]);
    }
    trozos.last.add(texto);
  }
  return {
    '$carpeta/indice.json': comoJson({
      'textos': 'textos',
      'inicios': inicios,
      'autores': autores,
      'poemas': filas,
    }),
    for (var t = 0; t < trozos.length; t++)
      '$carpeta/textos/$t.json': comoJson(trozos[t]),
  };
}

final _poemasDivididos = <Map<String, dynamic>>[
  {'autor': 'Burns', 'titulo': 'To a Mouse', 'texto': '  Wee, sleekit, cow’rin\nO, what a panic\n\nI’m truly sorry'},
  {'autor': 'Burns', 'titulo': '', 'texto': '\n   \nMy luve is like\na red, red rose'},
  {'autor': 'Dickinson', 'titulo': 'Hope', 'texto': 'Hope is the thing with feathers  \nThat perches'},
  {'autor': 'Dickinson', 'titulo': 'Sonnet IX', 'texto': 'Nueve\nlíneas'},
  {'autor': 'Dickinson', 'titulo': 'Sonnet II', 'texto': 'Dos'},
];

void _pruebasDivididas() {
  final comparador = comparadorDeTitulos(EstrategiaOrden.numeralesNaturales);

  Future<Anthology> cargarDividida() async {
    registrarAssets(_dividida(_poemasDivididos));
    final repo = PoemaRepository(
        assetPath: 'assets/poemas/indice.json', compararTitulos: comparador);
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    return (await binding.runAsync(repo.cargar))!;
  }

  Future<Anthology> cargarEntera() async {
    registrarAsset('assets/poemas.json', comoJson(_poemasDivididos));
    final repo = PoemaRepository(
        assetPath: 'assets/poemas.json', compararTitulos: comparador);
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    return (await binding.runAsync(repo.cargar))!;
  }

  test('a split anthology gives every poem the id the single file gives it',
      () async {
    final entera = await cargarEntera();
    final dividida = await cargarDividida();
    // Rule 1: favourites and notification payloads persist these ids.
    expect(dividida.poemas.map((p) => p.id), entera.poemas.map((p) => p.id));
    expect(dividida.poemas.map((p) => p.primerVerso),
        entera.poemas.map((p) => p.primerVerso));
    expect(dividida.poemas.map((p) => p.etiqueta),
        entera.poemas.map((p) => p.etiqueta));
    expect(dividida.poemas.map((p) => p.indiceOriginal), [0, 1, 2, 3, 4]);
    expect(dividida.porAutor['Dickinson']!.map((p) => p.titulo),
        ['Hope', 'Sonnet II', 'Sonnet IX']);
  });

  test('a split anthology loads a text only when asked', () async {
    final a = await cargarDividida();
    final p = a.poemas[2];
    expect(p.textoCargado, isFalse);
    expect(p.texto, '');
    expect(p.estrofas, isEmpty);
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    await binding.runAsync(p.cargarTexto);
    expect(p.textoCargado, isTrue);
    expect(p.texto, _poemasDivididos[2]['texto']);
    // same chunk (two poems per chunk), loaded with it
    expect(a.poemas[3].textoCargado, isTrue);
    expect(a.poemas[4].textoCargado, isFalse);
  });

  test('the search index of a split anthology matches the single file one',
      () async {
    final entera = await cargarEntera();
    final dividida = await cargarDividida();
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    final a = await binding.runAsync(() => entera.indiceBusqueda);
    final b = await binding.runAsync(() => dividida.indiceBusqueda);
    expect(b, a);
    // and building it loaded every text
    expect(dividida.poemas.every((p) => p.textoCargado), isTrue);
  });
}
