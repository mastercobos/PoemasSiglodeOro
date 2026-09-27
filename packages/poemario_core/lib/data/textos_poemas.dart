import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// The texts of a split anthology, in chunks loaded on demand.
///
/// A chunk is a JSON array of poem texts, `<carpeta>/<n>.json`, holding the
/// poems of the index from `inicios[n]` up to the next chunk's start. A
/// chunk is ~150 KB, so opening a poem decodes ~150 KB instead of the whole
/// anthology.
class TextosPoemas {
  /// Asset folder of the chunk files.
  final String carpeta;

  /// Index position of each chunk's first poem, ascending.
  final List<int> inicios;

  final Map<int, List<String>> _trozos = {};
  final Map<int, Future<void>> _pendientes = {};

  TextosPoemas({required this.carpeta, required this.inicios});

  int get numeroDeTrozos => inicios.length;

  /// The chunk that holds the poem at index position [indice].
  int trozoDe(int indice) {
    var bajo = 0, alto = inicios.length - 1;
    while (bajo < alto) {
      final medio = (bajo + alto + 1) >> 1;
      if (inicios[medio] <= indice) {
        bajo = medio;
      } else {
        alto = medio - 1;
      }
    }
    return bajo;
  }

  bool cargado(int trozo) => _trozos.containsKey(trozo);

  String? texto(int trozo, int posicion) => _trozos[trozo]?[posicion];

  String ruta(int trozo) => '$carpeta/$trozo.json';

  /// Loads one chunk; concurrent calls share the load.
  Future<void> cargar(int trozo) {
    if (cargado(trozo)) return Future.value();
    return _pendientes.putIfAbsent(trozo, () => _leer(trozo));
  }

  Future<void> _leer(int trozo) async {
    final datos = await rootBundle.load(ruta(trozo));
    _trozos[trozo] = decodificarTrozo(
        datos.buffer.asUint8List(datos.offsetInBytes, datos.lengthInBytes));
    _pendientes.removeWhere((t, _) => t == trozo);
  }

  /// Chunks decoded elsewhere (the search index decodes them all at once).
  void recibir(Map<int, List<String>> trozos) => _trozos.addAll(trozos);

  static List<String> decodificarTrozo(Uint8List bytes) =>
      (utf8.decoder.fuse(json.decoder).convert(bytes) as List).cast<String>();
}
