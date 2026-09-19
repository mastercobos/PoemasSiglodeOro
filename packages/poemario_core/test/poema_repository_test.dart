import 'package:flutter_test/flutter_test.dart';
import 'package:poemario_core/data/poema_repository.dart';
import 'package:poemario_core/domain/orden_titulos.dart';

import 'support/asset_falso.dart';
import 'support/harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
