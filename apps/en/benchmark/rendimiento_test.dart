// Timing check on the real English anthology, mirroring
// packages/poemario_core/benchmark/rendimiento_test.dart (kept app-side per
// rule 6: nothing app-specific belongs in poemario_core).
//   cd apps/en && flutter test benchmark/rendimiento_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:poemario_core/data/poema.dart';
import 'package:poemario_core/domain/orden_titulos.dart';

const _ruta = 'assets/poemas.json';
const _repeticiones = 10;

void medir(String nombre, void Function() f) {
  f();
  final t = <double>[];
  for (var i = 0; i < _repeticiones; i++) {
    final sw = Stopwatch()..start();
    f();
    t.add(sw.elapsedMicroseconds / 1000);
  }
  t.sort();
  // ignore: avoid_print
  print('${nombre.padRight(30)} median ${t[t.length ~/ 2].toStringAsFixed(2).padLeft(8)} ms'
      '   worst ${t.last.toStringAsFixed(2).padLeft(8)} ms');
}

void main() {
  test('rendimiento', () {
    final raw = File(_ruta).readAsStringSync();
    // ignore: avoid_print
    print('\n${raw.length ~/ 1024} KiB of JSON\n');

    medir('jsonDecode', () => jsonDecode(raw));

    final lista = jsonDecode(raw) as List;
    // ignore: avoid_print
    print('${lista.length} poems in the file\n');

    List<Poema> poemas = [];
    medir('Poema.fromJson x all', () {
      poemas = [
        for (var i = 0; i < lista.length; i++)
          Poema.fromJson(lista[i] as Map<String, dynamic>, index: i),
      ];
    });

    final autores = poemas.map((p) => p.autor).toSet();
    // ignore: avoid_print
    print('\n${poemas.length} poemas, ${autores.length} autores\n');

    medir('plegarParaOrden x all titles', () {
      for (final p in poemas) {
        plegarParaOrden(p.etiqueta);
      }
    });
  }, timeout: const Timeout(Duration(minutes: 5)));
}
