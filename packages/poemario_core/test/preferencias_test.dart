import 'package:flutter_test/flutter_test.dart';
import 'package:poemario_core/providers/ajustes_provider.dart';
import 'package:poemario_core/providers/favoritos_provider.dart';

import 'support/harness.dart';

/// The v1 → v2 migration. This is the one piece of this refactor that can lose
/// user data if it is wrong, and it only ever runs once per install.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('translates integer favourites into stable ids', () async {
    final anthology = await anthologyDePrueba(autores: 3, porAutor: 2);
    // v1 stored positions in poemas.json: 0 and 3.
    final prefs = await preferenciasDePrueba({
      'favoritos': ['0', '3'],
    });

    await prefs.migrar(anthology);

    final favoritos =
        FavoritosProvider(anthology: anthology, prefs: prefs).favoritos;
    expect(favoritos.map((p) => p.id), ['a0-p0', 'a1-p1']);
    // The old key is gone, so the migration can't run twice.
    expect(prefs.leerLista('favoritos'), isEmpty);
  });

  test('drops indices that no longer exist instead of throwing', () async {
    final anthology = await anthologyDePrueba(autores: 2, porAutor: 2);
    final prefs = await preferenciasDePrueba({
      'favoritos': ['0', '99', 'basura'],
    });

    await prefs.migrar(anthology);

    expect(prefs.leerLista('favoritos_v2'), ['a0-p0']);
  });

  test('inverts the author filter so new authors default to active', () async {
    final anthology = await anthologyDePrueba(autores: 4, porAutor: 1);
    // v1: the user had deselected "Autor 3".
    final prefs = await preferenciasDePrueba({
      'autores_seleccionados': ['Autor 0', 'Autor 1', 'Autor 2'],
    });

    await prefs.migrar(anthology);

    final ajustes = AjustesProvider(
        todosLosAutores: anthology.autores, prefs: prefs);
    expect(ajustes.estaActivo('Autor 3'), isFalse);
    expect(ajustes.totalActivos, 3);
  });

  test('an author added in a later release is active for existing users',
      () async {
    // The bug this migration exists for: under v1, "Autor 4" would have been
    // missing from every existing user's rotation with nothing to explain it.
    final viejo = await anthologyDePrueba(autores: 4, porAutor: 1);
    final prefs = await preferenciasDePrueba({
      'autores_seleccionados': viejo.autores,
    });
    await prefs.migrar(viejo);

    final nuevo = await anthologyDePrueba(autores: 5, porAutor: 1);
    final ajustes =
        AjustesProvider(todosLosAutores: nuevo.autores, prefs: prefs);

    expect(ajustes.estaActivo('Autor 4'), isTrue);
    expect(ajustes.totalActivos, 5);
  });

  test('runs once: a second call leaves v2 data alone', () async {
    final anthology = await anthologyDePrueba(autores: 2, porAutor: 2);
    final prefs = await preferenciasDePrueba({
      'favoritos': ['0'],
    });
    await prefs.migrar(anthology);
    await prefs.guardarLista('favoritos_v2', ['a1-p1']);

    await prefs.migrar(anthology);

    expect(prefs.leerLista('favoritos_v2'), ['a1-p1']);
  });

  test('reads survive corrupt values', () async {
    final prefs = await preferenciasDePrueba({'tema': 'no-es-un-modo'});
    expect(prefs.leerTexto('tema'), 'no-es-un-modo');
    expect(prefs.leerLista('no-existe'), isEmpty);
    expect(prefs.leerBool('no-existe'), isFalse);
    expect(prefs.leerEntero('no-existe'), isNull);
  });

  test('v2 history is rewound to before the last day seen', () async {
    final anthology = await anthologyDePrueba(autores: 4, porAutor: 1);
    final prefs = await preferenciasDePrueba({
      'esquema_prefs': 2,
      'historial_autores': ['Autor 3', 'Autor 2', 'Autor 1', 'Autor 0'],
      'historial_fecha': '2026-09-22T00:00:00.000',
    });

    await prefs.migrar(anthology);

    expect(prefs.leerLista('historial_base'), ['Autor 1', 'Autor 0']);
    expect(prefs.leerTexto('historial_base_fecha'), '2026-09-22T00:00:00.000');
    expect(prefs.leerLista('historial_autores'), isEmpty);
    expect(prefs.leerTexto('historial_fecha'), isNull);
  });
}
