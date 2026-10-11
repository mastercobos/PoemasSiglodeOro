import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poemario_core/data/poema.dart';
import 'package:poemario_core/notifications/agenda_avisos.dart';
import 'package:poemario_core/screens/poema_screen.dart';
import 'package:poemario_core/theme/poema_theme.dart';
import 'package:poemario_core/utils/navegacion.dart';
import 'package:poemario_core/widgets/escala_tableta.dart';

import 'support/harness.dart';

/// A 4-4-3-3 sonnet whose seventh verse is the config's longest verse.
Poema _soneto() {
  final versos = [
    for (var i = 0; i < 14; i++)
      i == 6 ? configPrueba.versoMasLargo : 'verso $i',
  ];
  final texto = [
    versos.sublist(0, 4),
    versos.sublist(4, 8),
    versos.sublist(8, 11),
    versos.sublist(11),
  ].map((e) => e.join('\n')).join('\n\n');
  return Poema.fromJson(
      {'id': 's', 'autor': 'Autor 0', 'titulo': 'Soneto', 'texto': texto},
      index: 0);
}

void _pantalla(WidgetTester tester, Size tamano, double escala,
    {double arriba = 0, double abajo = 0}) {
  final margenes =
      FakeViewPadding(top: arriba * escala, bottom: abajo * escala);
  tester.view
    ..physicalSize = tamano * escala
    ..devicePixelRatio = escala
    ..padding = margenes
    ..viewPadding = margenes;
  addTearDown(tester.view.reset);
}

/// Pumps [pantalla] with the full provider stack.
Future<void> _montar(WidgetTester tester, Widget pantalla) async {
  final anthology = await anthologyDePrueba();
  final prefs = await preferenciasDePrueba(const {'esquema_prefs': 2});
  await tester.pumpWidget(AppDePrueba(
    anthology: anthology,
    prefs: prefs,
    solicitudes: SolicitudDePoema(),
    agenda: AgendaFalsa(),
    child: pantalla,
  ));
  await tester.pumpAndSettle();
}

void main() {
  final tipos = PoemaTextStyles.from(configPrueba.fuentes);

  test('a phone keeps its sizes, even the largest iPhone', () {
    for (final tamano in const [Size(375, 667), Size(440, 956)]) {
      expect(
        EscalaTableta.calcular(
            MediaQueryData(size: tamano), tipos, configPrueba.versoMasLargo),
        1,
      );
    }
  });

  testWidgets(
      'a sonnet fits whole on a tablet, the longest verse on one line, '
      'with larger text than a phone', (tester) async {
    _pantalla(tester, const Size(1032, 1376), 2, arriba: 24, abajo: 20);
    await _montar(tester, EscalaTableta(child: PoemaScreen(poema: _soneto())));
    await tester.pumpAndSettle();

    final contexto = tester.element(find.byType(PoemaScreen));
    expect(EscalaTableta.factorDe(contexto), greaterThan(1.2));

    final cuerpo = find
        .byWidgetPredicate((w) => w is SelectableText && w.textSpan != null);
    final rect = tester.getRect(cuerpo);

    // Whole: the last verse ends above the nav pill's reserved space.
    expect(rect.bottom,
        lessThanOrEqualTo(1376 - espacioBarraFlotante(contexto) + 0.5));

    // One line per verse: the block is exactly 14 verses and 3 stanza gaps
    // tall, so the long verse didn't wrap.
    final pintor = TextPainter(
      text: TextSpan(
        text: [
          for (final n in [4, 4, 3, 3]) List.filled(n, 'x').join('\n'),
        ].join('\n\n'),
        style: tipos.verso,
      ),
      textScaler: MediaQuery.textScalerOf(contexto),
      textDirection: TextDirection.ltr,
    )..layout();
    expect(rect.height, moreOrLessEquals(pintor.height, epsilon: 0.5));
    pintor.dispose();
  });

  testWidgets('the column widens with the factor', (tester) async {
    _pantalla(tester, const Size(1032, 1376), 2);
    late BuildContext contexto;
    await _montar(
      tester,
      EscalaTableta(child: Builder(builder: (c) {
        contexto = c;
        return const SizedBox();
      })),
    );
    final f = EscalaTableta.factorDe(contexto);
    expect(margenLateral(contexto),
        moreOrLessEquals((1032 - anchoMaximoColumna * f) / 2));
  });
}
