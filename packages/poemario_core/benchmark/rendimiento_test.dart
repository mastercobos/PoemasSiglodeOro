// Timing benchmark on the real Spanish anthology. Not part of the normal
// suite (`flutter test` only looks in test/); run with:
//   flutter test benchmark/rendimiento_test.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:poemario_core/data/poema.dart';
import 'package:poemario_core/data/poema_repository.dart';
import 'package:poemario_core/domain/orden_titulos.dart';
import 'package:poemario_core/domain/seleccion_diaria.dart';
import 'package:poemario_core/notifications/planificador_avisos.dart';

import '../test/support/asset_falso.dart';

const _ruta = '../../apps/es/assets/poemas.json';
const _repeticiones = 10;

/// Median and worst of [_repeticiones] runs, in milliseconds, after one
/// warm-up run.
Future<void> medir(String nombre, FutureOr<void> Function() f) async {
  await f();
  final t = <double>[];
  for (var i = 0; i < _repeticiones; i++) {
    final sw = Stopwatch()..start();
    await f();
    t.add(sw.elapsedMicroseconds / 1000);
  }
  t.sort();
  // ignore: avoid_print
  print('${nombre.padRight(44)} mediana ${t[t.length ~/ 2].toStringAsFixed(2).padLeft(8)} ms'
      '   peor ${t.last.toStringAsFixed(2).padLeft(8)} ms');
}


void main() {
  final raw = File(_ruta).readAsStringSync();
  final compara = comparadorDeTitulos(EstrategiaOrden.romanosPrimero);

  test('rendimiento', () async {
    // ignore: avoid_print
    print('\n${raw.length ~/ 1024} KiB de JSON\n');

    await medir('jsonDecode', () => jsonDecode(raw));

    final lista = jsonDecode(raw) as List;
    await medir('Poema.fromJson x todos', () {
      for (var i = 0; i < lista.length; i++) {
        Poema.fromJson(lista[i] as Map<String, dynamic>, index: i);
      }
    });

    registrarAsset('assets/poemas.json', raw);
    final repo = PoemaRepository(assetPath: 'assets/poemas.json', compararTitulos: compara);
    await medir('PoemaRepository.cargar (con isolate)', () async {
      registrarAsset('assets/poemas.json', raw);
      await TestWidgetsFlutterBinding.instance.runAsync(repo.cargar);
    });

    final anto = (await TestWidgetsFlutterBinding.instance.runAsync(repo.cargar))!;
    // ignore: avoid_print
    print('\n${anto.length} poemas, ${anto.autores.length} autores\n');

    await medir('plegarParaOrden x todos los titulos', () {
      for (final p in anto.poemas) {
        plegarParaOrden(p.etiqueta);
      }
    });

    final fecha = DateTime(2026, 9, 20);
    await medir('SeleccionDiaria.paraFecha (pool completo)',
        () => SeleccionDiariaService.paraFecha(pool: anto.poemas, fecha: fecha));
    await medir('SeleccionDiaria.serie 14 dias (pool completo)',
        () => SeleccionDiariaService.serie(pool: anto.poemas, desde: fecha, dias: 14));

    const textos = TextosAviso(
        titulo: 't', linea: _cuerpo, cuerpoGenerico: 'g');
    await medir('PlanificadorAvisos.construir (pool completo)', () {
      PlanificadorAvisos.construir(
        pool: anto.poemas,
        desde: fecha,
        hora: const TimeOfDay(hour: 9, minute: 0),
        textos: textos,
        autoresRecientes: const ['a', 'b'],
      );
    });
  }, timeout: const Timeout(Duration(minutes: 5)));
}

String _cuerpo(Poema p) => '${p.etiqueta} — ${p.autor}';
