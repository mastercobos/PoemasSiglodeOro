import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show ByteData, rootBundle;

import '../domain/orden_titulos.dart';
import 'poema.dart';
import 'textos_poemas.dart';

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

  /// The chunked texts of a split anthology; null for a single-file one.
  final TextosPoemas? textos;

  final _Busqueda _busqueda = _Busqueda();

  Anthology._(this.poemas, this.autores, this.porAutor, this._porId, this.textos);

  /// Resolves a persisted or notification-payload id. Null when the poem no
  /// longer exists, which is normal after an anthology edit — callers should
  /// degrade gracefully rather than assert.
  Poema? porId(String id) => _porId[id];

  int get length => poemas.length;

  /// Lowercased, diacritic-folded `"titulo autor texto"` of every poem, in
  /// [poemas] order. Built off the UI isolate the first time it is asked for
  /// (bootstrap asks right after the first frame): folding the whole corpus
  /// took ~4.5 s of the English app's startup on a Pixel 9a. For a split
  /// anthology, building it loads every text as well.
  Future<List<String>> get indiceBusqueda =>
      _busqueda.futuro ??= _construirIndiceBusqueda(this);

  /// [indiceBusqueda] once it has finished; null until then.
  List<String>? get indiceBusquedaListo => _busqueda.listo;
}

class _Busqueda {
  Future<List<String>>? futuro;
  List<String>? listo;
}

Future<List<String>> _construirIndiceBusqueda(Anthology a) async {
  final titulos = [for (final p in a.poemas) p.titulo];
  final autores = [for (final p in a.poemas) p.autor];
  final List<String> indice;
  final textos = a.textos;
  if (textos == null) {
    final cuerpos = [for (final p in a.poemas) p.texto];
    indice = await compute(_plegarTodo, _Plegado(titulos, autores, cuerpos));
  } else {
    final bytes = <Uint8List>[];
    for (var t = 0; t < textos.numeroDeTrozos; t++) {
      final d = await rootBundle.load(textos.ruta(t));
      bytes.add(d.buffer.asUint8List(d.offsetInBytes, d.lengthInBytes));
    }
    final r = await compute(_leerYPlegar, _Lectura(titulos, autores, bytes));
    textos.recibir(r.trozos);
    indice = r.indice;
  }
  a._busqueda.listo = indice;
  return indice;
}

class _Plegado {
  final List<String> titulos, autores, cuerpos;
  const _Plegado(this.titulos, this.autores, this.cuerpos);
}

List<String> _plegarTodo(_Plegado e) => [
      for (var i = 0; i < e.titulos.length; i++)
        plegarParaOrden('${e.titulos[i]} ${e.autores[i]} ${e.cuerpos[i]}'),
    ];

class _Lectura {
  final List<String> titulos, autores;
  final List<Uint8List> trozos;
  const _Lectura(this.titulos, this.autores, this.trozos);
}

class _Leido {
  final Map<int, List<String>> trozos;
  final List<String> indice;
  const _Leido(this.trozos, this.indice);
}

_Leido _leerYPlegar(_Lectura e) {
  final trozos = <int, List<String>>{};
  final cuerpos = <String>[];
  for (var t = 0; t < e.trozos.length; t++) {
    trozos[t] = TextosPoemas.decodificarTrozo(e.trozos[t]);
    cuerpos.addAll(trozos[t]!);
  }
  return _Leido(trozos, _plegarTodo(_Plegado(e.titulos, e.autores, cuerpos)));
}

/// Loads and indexes the anthology.
///
/// Two layouts, told apart by the asset's shape:
///
/// * **single file**: a JSON array of `{"titulo", "autor", "texto", "id"?}`
///   (the Spanish app);
/// * **split**: an index object with `textos` (a folder next to it),
///   `inicios`, `autores` and `poemas` (rows of title, author number, first
///   line and an optional id), and the texts in chunks in that folder
///   ([TextosPoemas]). Only the index is read at startup. The English app: as a single file it is
///   33 MB and took ~12 s on a Pixel 9a before anything was drawn.
class PoemaRepository {
  final String assetPath;
  final int Function(String, String) compararTitulos;

  const PoemaRepository({
    required this.assetPath,
    required this.compararTitulos,
  });

  Future<Anthology> cargar() async {
    final ByteData datos;
    try {
      datos = await rootBundle.load(assetPath);
    } catch (e) {
      throw AnthologyLoadException('No se pudo leer $assetPath', e);
    }

    // From the raw bytes to the finished indexes, off the UI isolate, in one
    // step: no String of the whole file decoded on one isolate and copied to
    // another, no sorting before the first frame on this one.
    final carpeta = assetPath.contains('/')
        ? assetPath.substring(0, assetPath.lastIndexOf('/'))
        : '';
    try {
      return await compute(
        _construir,
        _Entrada(
          datos.buffer.asUint8List(datos.offsetInBytes, datos.lengthInBytes),
          compararTitulos,
          carpeta,
        ),
      );
    } on AnthologyLoadException {
      rethrow;
    } catch (e) {
      throw AnthologyLoadException('JSON inválido en $assetPath', e);
    }
  }
}

class _Entrada {
  final Uint8List bytes;
  final int Function(String, String) compararTitulos;
  final String carpeta;
  const _Entrada(this.bytes, this.compararTitulos, this.carpeta);
}

/// Top-level so it can run under [compute]. Decodes UTF-8 and JSON in one
/// pass, builds the poems and the indexes.
Anthology _construir(_Entrada entrada) {
  final datos = utf8.decoder.fuse(json.decoder).convert(entrada.bytes);
  final List<Poema> poemas;
  TextosPoemas? textos;
  if (datos is Map<String, dynamic>) {
    final carpeta = entrada.carpeta.isEmpty
        ? datos['textos'] as String
        : '${entrada.carpeta}/${datos['textos']}';
    final t = TextosPoemas(
      carpeta: carpeta,
      inicios: (datos['inicios'] as List).cast<int>(),
    );
    final autores = (datos['autores'] as List).cast<String>();
    final filas = datos['poemas'] as List;
    poemas = [];
    for (var i = 0; i < filas.length; i++) {
      final f = filas[i] as List;
      final trozo = t.trozoDe(i);
      poemas.add(Poema.deIndice(
        [f[0], autores[f[1] as int], f[2], if (f.length > 3) f[3]],
        index: i,
        textos: t,
        trozo: trozo,
        posicion: i - t.inicios[trozo],
      ));
    }
    textos = t;
  } else {
    final lista = datos as List;
    poemas = [
      for (var i = 0; i < lista.length; i++)
        Poema.fromJson(lista[i] as Map<String, dynamic>, index: i),
    ];
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
    lista.sort((a, b) => entrada.compararTitulos(a.etiqueta, b.etiqueta));
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
    textos,
  );
}
