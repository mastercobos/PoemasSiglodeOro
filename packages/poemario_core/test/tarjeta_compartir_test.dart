import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poemario_core/config/app_config.dart';
import 'package:poemario_core/data/poema.dart';
import 'package:poemario_core/utils/compartir_poema.dart';
import 'package:provider/provider.dart';

import 'support/harness.dart';

Poema _poema(List<int> estrofas, {String titulo = 'Título'}) {
  var n = 0;
  final texto = estrofas
      .map((v) => List.generate(v, (_) => 'verso ${n++}').join('\n'))
      .join('\n\n');
  return Poema.fromJson(
      {'id': 'x', 'autor': 'Autor', 'titulo': titulo, 'texto': texto},
      index: 0);
}

Future<void> _montar(WidgetTester tester, Poema poema) async {
  tester.view.physicalSize = const Size(1200, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(Provider<AppConfig>.value(
    value: configPrueba,
    child: MaterialApp(
      theme: configPrueba.temaClaro,
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.noScaling),
        child: Center(child: TarjetaCompartir(poema: poema, firma: 'Firma')),
      ),
    ),
  ));
}

int _versosPintados(WidgetTester tester) => find
    .byWidgetPredicate(
        (w) => w is Text && (w.data?.startsWith('verso ') ?? false))
    .evaluate()
    .length;

void main() {
  group('TarjetaCompartir', () {
    testWidgets('is always 4:5, whatever the poem length', (tester) async {
      for (final poema in [
        _poema([4]),
        _poema([4, 4, 3, 3]),
        _poema([60]),
      ]) {
        await _montar(tester, poema);
        expect(tester.getSize(find.byType(TarjetaCompartir)),
            const Size(800, 1000));
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('a sonnet is shown whole, even under a long title',
        (tester) async {
      await _montar(tester, _poema([4, 4, 3, 3], titulo: 'Muy largo ' * 30));
      expect(_versosPintados(tester), 14);
      expect(find.text('…'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a long poem fills the card and ends in an ellipsis',
        (tester) async {
      await _montar(tester, _poema([60]));
      expect(_versosPintados(tester), greaterThan(4));
      expect(_versosPintados(tester), lessThan(60));
      expect(find.text('…'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('seleccionarVersos', () {
    List<List<String>> estrofas(List<int> tamanos) {
      var n = 0;
      return [
        for (final t in tamanos) [for (var i = 0; i < t; i++) 'v${n++}']
      ];
    }

    // Every verse is 10 high, stanza gaps 5, the ellipsis line 10.
    List<List<String>> elegir(List<int> tamanos, double alto) =>
        TarjetaCompartir.seleccionarVersos(
          estrofas: estrofas(tamanos),
          altoVerso: (_) => 10,
          altoDisponible: alto,
          huecoEstrofa: 5,
          altoPuntos: 10,
        );

    test('keeps everything that fits', () {
      expect(elegir([2, 2], 100), estrofas([2, 2]));
    });

    test('cuts at a stanza break when it keeps most of what fits', () {
      // Room for 4 + gap + 1 verse; the break after 4 keeps 4 of 5.
      expect(elegir([4, 4], 65), estrofas([4]));
    });

    test('cuts mid-stanza when the break would waste the card', () {
      // Room for 4 + gap + 2 verses; the break after 4 keeps only 4 of 6.
      expect(elegir([4, 4], 75), [
        ['v0', 'v1', 'v2', 'v3'],
        ['v4', 'v5'],
      ]);
    });

    test('one giant stanza is cut to what fits', () {
      expect(elegir([50], 60), [
        [for (var i = 0; i < 5; i++) 'v$i']
      ]);
    });

    test('always keeps at least one verse', () {
      expect(elegir([3], 5), [
        ['v0']
      ]);
    });
  });
}
