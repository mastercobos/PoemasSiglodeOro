import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poemario_core/donaciones/tienda_propinas.dart';
import 'package:poemario_core/notifications/agenda_avisos.dart';
import 'package:poemario_core/providers/propinas_provider.dart';
import 'package:poemario_core/screens/ajustes_screen.dart';

import 'support/harness.dart';

/// The tip jar as the reader sees it, on the real settings screen. Kept apart
/// from widget_test.dart so it doesn't inherit that file's open hang.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const cafe1 = Propina(id: 'c1', precio: '1,00 €', valor: 1);
  const cafe3 = Propina(id: 'c3', precio: '3,00 €', valor: 3);

  Future<PropinasProvider> montar(
    WidgetTester tester,
    TiendaFalsa tienda,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final propinas = PropinasProvider(tienda: tienda, ids: {'c1', 'c3'});
    await propinas.iniciar();
    await tester.pumpWidget(AppDePrueba(
      anthology: await anthologyDePrueba(),
      prefs: await preferenciasDePrueba({'esquema_prefs': 2}),
      solicitudes: SolicitudDePoema(),
      agenda: AgendaFalsa(),
      propinas: propinas,
      child: const AjustesScreen(),
    ));
    await tester.pump();
    return propinas;
  }

  testWidgets('shows one button per amount, cheapest first', (tester) async {
    await montar(tester, TiendaFalsa([cafe3, cafe1]));

    expect(find.text('APOYA LA ANTOLOGÍA'), findsOneWidget);
    expect(find.text('1,00 €'), findsOneWidget);
    expect(find.text('3,00 €'), findsOneWidget);
    expect(tester.getTopLeft(find.text('1,00 €')).dx,
        lessThan(tester.getTopLeft(find.text('3,00 €')).dx));
  });

  testWidgets('section is absent when the store has nothing', (tester) async {
    await montar(tester, TiendaFalsa());
    expect(find.text('APOYA LA ANTOLOGÍA'), findsNothing);
  });

  testWidgets('tapping buys, disables buttons, then says thanks',
      (tester) async {
    final tienda = TiendaFalsa([cafe1, cafe3]);
    await montar(tester, tienda);

    await tester.tap(find.text('3,00 €'));
    await tester.pump();
    expect(tienda.compradas, ['c3']);

    final boton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, '1,00 €'));
    expect(boton.onPressed, isNull, reason: 'no double purchase in flight');

    tienda.emitir(ResultadoPropina.completada);
    await tester.pump();
    await tester.pump();
    expect(find.text('¡Gracias por tu apoyo!'), findsOneWidget);
    expect(
        tester
            .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, '1,00 €'))
            .onPressed,
        isNotNull);
  });

  testWidgets('failure shows an error; cancel shows nothing', (tester) async {
    final tienda = TiendaFalsa([cafe1]);
    await montar(tester, tienda);

    await tester.tap(find.text('1,00 €'));
    await tester.pump();
    tienda.emitir(ResultadoPropina.cancelada);
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('No se pudo completar'), findsNothing);
    expect(find.text('¡Gracias por tu apoyo!'), findsNothing);

    await tester.tap(find.text('1,00 €'));
    await tester.pump();
    tienda.emitir(ResultadoPropina.fallida);
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('No se pudo completar'), findsOneWidget);
  });
}
