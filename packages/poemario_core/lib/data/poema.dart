import 'package:flutter/foundation.dart';

import '../domain/orden_titulos.dart';

/// One poem.
///
/// Three things changed from the original model, all of them load-bearing:
///
/// **The id is a stable string, not the array index.** Favourites persist ids.
/// With an index, inserting a poem into the middle of `poemas.json` silently
/// repointed every saved favourite at a different poem on the next update.
/// A notification payload has the same problem, one release later.
///
/// **Stanzas come from the data.** The old screen threw away every blank line
/// and then re-inserted breaks after lines 4, 8 and 11 — correct for a sonnet,
/// wrong for a romance, and wrong for most of an English anthology. The source
/// already carries the structure; we keep it.
///
/// **Search text is precomputed.** The search screen used to lowercase the
/// entire corpus on every keystroke.
@immutable
class Poema {
  /// Stable across releases. Taken from the JSON `id` field when present,
  /// otherwise derived from the content (see [_idDerivado]).
  final String id;

  /// Position in the source file. Kept only so the one-time favourites
  /// migration can map old integer ids onto [id]. Do not persist it.
  final int indiceOriginal;

  final String titulo;
  final String autor;
  final String texto;

  /// Verses grouped by stanza, blank lines removed within each group.
  final List<List<String>> estrofas;

  /// Lowercased, diacritic-folded `"titulo autor texto"`, built once at load.
  final String indiceBusqueda;

  const Poema({
    required this.id,
    required this.indiceOriginal,
    required this.titulo,
    required this.autor,
    required this.texto,
    required this.estrofas,
    required this.indiceBusqueda,
  });

  factory Poema.fromJson(Map<String, dynamic> json, {required int index}) {
    final titulo = (json['titulo'] as String?)?.trim() ?? '';
    final autor = (json['autor'] as String?)?.trim().isNotEmpty == true
        ? (json['autor'] as String).trim()
        : 'Anónimo';
    final texto = (json['texto'] as String?) ?? '';
    final estrofas = _dividirEnEstrofas(texto);

    return Poema(
      id: (json['id'] as String?)?.trim().isNotEmpty == true
          ? (json['id'] as String).trim()
          : _idDerivado(autor, titulo, texto),
      indiceOriginal: index,
      titulo: titulo,
      autor: autor,
      texto: texto,
      estrofas: estrofas,
      indiceBusqueda: plegarParaOrden('$titulo $autor $texto'),
    );
  }

  /// Splits on blank lines. A poem with no blank line is a single stanza.
  static List<List<String>> _dividirEnEstrofas(String texto) {
    return texto
        .split(RegExp(r'\n[ \t]*\n'))
        .map((bloque) => bloque
            .split('\n')
            .map((l) => l.trimRight())
            .where((l) => l.trim().isNotEmpty)
            .toList())
        .where((estrofa) => estrofa.isNotEmpty)
        .toList(growable: false);
  }

  /// Content-derived fallback id.
  ///
  /// Uses FNV-1a rather than `String.hashCode`, which Dart does not guarantee
  /// to be stable across SDK versions or platforms — a persisted key built
  /// from it could change under the user after a Flutter upgrade.
  ///
  /// Prefer putting an explicit `"id"` in the JSON. This exists so an existing
  /// anthology keeps working without re-editing the data, and so that an
  /// edited *typo* in a poem doesn't orphan a favourite: the hash covers the
  /// author and the opening verse, not the whole text.
  static String _idDerivado(String autor, String titulo, String texto) {
    final primeraLinea = texto
        .split('\n')
        .map((l) => l.trim())
        .firstWhere((l) => l.isNotEmpty, orElse: () => '');
    final semilla = '${autor.toLowerCase()}|'
        '${titulo.toLowerCase()}|'
        '${primeraLinea.toLowerCase()}';
    return _fnv1a(semilla).toRadixString(36);
  }

  static int _fnv1a(String s) {
    var hash = 0x811c9dc5;
    for (final unidad in s.codeUnits) {
      hash ^= unidad;
      // 32-bit FNV prime multiply, masked to stay in the safe integer range
      // on both the VM and the web.
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }

  /// First non-empty verse.
  String get primerVerso =>
      estrofas.isEmpty || estrofas.first.isEmpty ? '' : estrofas.first.first;

  /// What lists show: the title, or the first verse for untitled poems.
  String get etiqueta => titulo.isNotEmpty ? titulo : primerVerso;

  /// True when the first verse adds information beyond the title, i.e. when a
  /// list row should show the `«…»` subtitle. This condition appeared verbatim
  /// in four screens.
  bool get mostrarPrimerVerso =>
      titulo.isNotEmpty && primerVerso.isNotEmpty && primerVerso != titulo;

  /// All verses, stanza breaks discarded. For the share text and for measuring.
  List<String> get versos => [for (final e in estrofas) ...e];

  @override
  bool operator ==(Object other) => other is Poema && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Poema($id, $autor — $etiqueta)';
}
