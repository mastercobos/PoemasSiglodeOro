import 'package:flutter/foundation.dart';

import 'textos_poemas.dart';

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
/// **The text can arrive later.** A large anthology ships an index (title,
/// author, first verse) that loads at startup and its texts in chunks that
/// load when a poem is shown ([TextosPoemas]); [texto] is empty until then
/// ([textoCargado]). A small one ships everything in one file and has its
/// text from the start.
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

  /// First non-empty verse. Stored rather than read from [estrofas], so lists,
  /// notifications and sorting never need the text.
  final String primerVerso;

  final String? _textoPropio;
  final TextosPoemas? _textos;
  final int _trozo;
  final int _posicion;

  const Poema({
    required this.id,
    required this.indiceOriginal,
    required this.titulo,
    required this.autor,
    required this.primerVerso,
    String? texto,
    TextosPoemas? textos,
    int trozo = 0,
    int posicion = 0,
  })  : _textoPropio = texto,
        _textos = textos,
        _trozo = trozo,
        _posicion = posicion;

  /// The whole poem. Empty while its chunk isn't loaded (see [textoCargado]).
  String get texto => _textoPropio ?? _textos?.texto(_trozo, _posicion) ?? '';

  bool get textoCargado => _textoPropio != null || (_textos?.cargado(_trozo) ?? false);

  /// Loads the chunk this poem's text is in, if it isn't loaded yet.
  Future<void> cargarTexto() =>
      textoCargado ? Future.value() : _textos!.cargar(_trozo);

  /// Verses grouped by stanza, blank lines removed within each group. Split
  /// the first time they are read once the text is there, not at load: a
  /// screen shows one poem, and splitting all ~15,000 of the English
  /// anthology at load was a fifth of its startup time.
  List<List<String>> get estrofas => textoCargado
      ? (_estrofas[this] ??= _dividirEnEstrofas(texto))
      : const [];

  static final _estrofas = Expando<List<List<String>>>('estrofas');

  /// A poem from a single-file anthology: the text comes with it.
  factory Poema.fromJson(Map<String, dynamic> json, {required int index}) {
    final titulo = (json['titulo'] as String?)?.trim() ?? '';
    final autor = _autor(json['autor'] as String?);
    final texto = (json['texto'] as String?) ?? '';
    final primera = _primeraLinea(texto);
    return Poema(
      id: _idExplicito(json['id']) ?? _idDerivado(autor, titulo, primera.trim()),
      indiceOriginal: index,
      titulo: titulo,
      autor: autor,
      primerVerso: primera.trimRight(),
      texto: texto,
    );
  }

  /// A poem from a split anthology's index: `[titulo, autor, primera, id?]`,
  /// `primera` being the first verse as the app's pipeline wrote it: the
  /// text's first non-empty line (English), or the first one after a leading
  /// section mark such as "I" (French, `asset.py`). The id hashes it, so for a
  /// published poem it must never change (rule 1).
  factory Poema.deIndice(
    List<dynamic> fila, {
    required int index,
    required TextosPoemas textos,
    required int trozo,
    required int posicion,
  }) {
    final titulo = (fila[0] as String?)?.trim() ?? '';
    final autor = _autor(fila[1] as String?);
    final primera = (fila[2] as String?) ?? '';
    return Poema(
      id: _idExplicito(fila.length > 3 ? fila[3] : null) ??
          _idDerivado(autor, titulo, primera.trim()),
      indiceOriginal: index,
      titulo: titulo,
      autor: autor,
      primerVerso: primera.trimRight(),
      textos: textos,
      trozo: trozo,
      posicion: posicion,
    );
  }

  static String _autor(String? autor) =>
      autor?.trim().isNotEmpty == true ? autor!.trim() : 'Anónimo';

  static String? _idExplicito(Object? id) =>
      (id as String?)?.trim().isNotEmpty == true ? id!.trim() : null;

  /// The first line with something on it, untrimmed. Its [String.trim] is
  /// what the id hashes, its [String.trimRight] is [primerVerso] (the first
  /// line of the first stanza, since [_dividirEnEstrofas] trims only the right).
  static String _primeraLinea(String texto) =>
      texto.split('\n').firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');

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
  static String _idDerivado(String autor, String titulo, String primeraLinea) {
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

  /// What lists show: the title, or the first verse for untitled poems.
  String get etiqueta => titulo.isNotEmpty ? titulo : primerVerso;

  /// True when the first verse adds information beyond the title, i.e. when a
  /// list row should show the `«…»` subtitle. This condition appeared verbatim
  /// in four screens. Quotes, punctuation and case are ignored: Wikisource
  /// titles an untitled poem by its first line in guillemets
  /// ("« J’ai beau comme un imbécile »"), which is no new information.
  bool get mostrarPrimerVerso =>
      titulo.isNotEmpty &&
      primerVerso.isNotEmpty &&
      _soloPalabras(primerVerso) != _soloPalabras(titulo);

  /// [primerVerso] without a quotation mark it opens or closes with, for
  /// showing it between the app's own «…» (or “…”): a verse that is itself
  /// the start of a quotation ("« Minerve combattra !… ") would otherwise
  /// read «« Minerve…». Display only; the id hashes [primerVerso].
  String get primerVersoSinComillas => primerVerso
      .replaceFirst(_comillaInicial, '')
      .replaceFirst(_comillaFinal, '');

  static final _comillaInicial = RegExp(r'^[«“"‹„]\s*');
  static final _comillaFinal = RegExp(r'\s*[»”"›]$');

  static final _noPalabra = RegExp(r'[^\p{L}\p{N}]+', unicode: true);
  static String _soloPalabras(String s) =>
      s.replaceAll(_noPalabra, '').toLowerCase();

  /// All verses, stanza breaks discarded. For the share text and for measuring.
  List<String> get versos => [for (final e in estrofas) ...e];

  @override
  bool operator ==(Object other) => other is Poema && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Poema($id, $autor — $etiqueta)';
}
