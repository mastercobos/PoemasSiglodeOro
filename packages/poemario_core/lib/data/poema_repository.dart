import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../domain/orden_titulos.dart';
import 'poema.dart';

/// Thrown when the anthology asset is missing or malformed. `bootstrap`
/// catches this and shows an error screen instead of a black rectangle —
/// the old `main()` awaited the load with no `catch` at all.
class AnthologyLoadException implements Exception {
  final String mensaje;
  final Object? causa;
  const AnthologyLoadException(this.mensaje, [this.causa]);

  @override
  String toString() => 'AnthologyLoadException: $mensaje ($causa)';
}

/// The loaded anthology. Immutable for the life of the process, which is why
/// it can be provided as a plain value rather than a ChangeNotifier.
@immutable
class Anthology {
  final List<Poema> poemas;

  /// Every author, sorted with the app's collation. Built once.
  final List<String> autores;

  /// Poems grouped by author, each group sorted with the app's comparator.
  /// Computing this once at load removes the duplicate `_agrupar` that ran on
  /// every build of both the index and the favourites screen.
  final Map<String, List<Poema>> porAutor;

  final Map<String, Poema> _porId;

  const Anthology._(this.poemas, this.autores, this.porAutor, this._porId);

  /// Resolves a persisted or notification-payload id. Null when the poem no
  /// longer exists, which is normal after an anthology edit — callers should
  /// degrade gracefully rather than assert.
  Poema? porId(String id) => _porId[id];

  int get length => poemas.length;
}

/// Loads and indexes the anthology.
class PoemaRepository {
  final String assetPath;
  final int Function(String, String) compararTitulos;

  const PoemaRepository({
    required this.assetPath,
    required this.compararTitulos,
  });

  Future<Anthology> cargar() async {
    final String raw;
    try {
      raw = await rootBundle.loadString(assetPath);
    } catch (e) {
      throw AnthologyLoadException('No se pudo leer $assetPath', e);
    }

    // Parsing several hundred poems and building the search index takes long
    // enough to drop frames on a low-end device, and it happens before the
    // first frame. Off the UI isolate it goes.
    final List<Poema> poemas;
    try {
      poemas = await compute(_parsear, raw);
    } catch (e) {
      throw AnthologyLoadException('JSON inválido en $assetPath', e);
    }

    if (poemas.isEmpty) {
      throw const AnthologyLoadException('La antología está vacía');
    }

    final porId = <String, Poema>{};
    for (final p in poemas) {
      if (porId.containsKey(p.id)) {
        // Two poems sharing an id means favourites and notifications will
        // collide. Loud in debug, survivable in release.
        assert(
          false,
          'Id duplicado "${p.id}": ${porId[p.id]} y $p. '
          'Añade un campo "id" explícito a poemas.json.',
        );
        debugPrint('⚠️  Id duplicado en la antología: ${p.id}');
        continue;
      }
      porId[p.id] = p;
    }

    final porAutor = <String, List<Poema>>{};
    for (final p in poemas) {
      porAutor.putIfAbsent(p.autor, () => []).add(p);
    }
    for (final lista in porAutor.values) {
      lista.sort((a, b) => compararTitulos(a.etiqueta, b.etiqueta));
    }

    final autores = porAutor.keys.toList()
      ..sort((a, b) => plegarParaOrden(a).compareTo(plegarParaOrden(b)));

    return Anthology._(
      List.unmodifiable(poemas),
      List.unmodifiable(autores),
      Map.unmodifiable({
        for (final a in autores) a: List<Poema>.unmodifiable(porAutor[a]!),
      }),
      Map.unmodifiable(porId),
    );
  }
}

/// Top-level so it can run under [compute].
List<Poema> _parsear(String raw) {
  final lista = jsonDecode(raw) as List;
  return [
    for (var i = 0; i < lista.length; i++)
      Poema.fromJson(lista[i] as Map<String, dynamic>, index: i),
  ];
}
