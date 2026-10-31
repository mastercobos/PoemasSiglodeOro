import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poemario_core/notifications/agenda_avisos.dart';
import 'package:poemario_core/screens/ajustes_screen.dart';
import 'package:poemario_core/screens/busqueda_screen.dart';
import 'package:poemario_core/screens/favoritos_screen.dart';
import 'package:poemario_core/screens/indice_screen.dart';
import 'package:poemario_core/screens/poema_screen.dart';
import 'package:poemario_core/screens/root_screen.dart';
import 'package:poemario_core/utils/navegacion.dart';
import 'package:poemario_core/widgets/versos_ajustados.dart';

import 'support/harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Pumps [pantalla] with the full provider stack.
  Future<(SolicitudDePoema, AgendaFalsa)> montar(
    WidgetTester tester,
    Widget pantalla, {
    Map<String, Object> prefsIniciales = const {'esquema_prefs': 2},
    int autores = 4,
  }) async {
    final anthology = await anthologyDePrueba(autores: autores);
    final prefs = await preferenciasDePrueba(prefsIniciales);
    final solicitudes = SolicitudDePoema();
    final agenda = AgendaFalsa();

    await tester.pumpWidget(AppDePrueba(
      anthology: anthology,
      prefs: prefs,
      solicitudes: solicitudes,
      agenda: agenda,
      child: pantalla,
    ));
    await tester.pumpAndSettle();
    return (solicitudes, agenda);
  }

  group('RootScreen', () {
    testWidgets('opens on the today tab and switches tabs', (tester) async {
      await montar(tester, const RootScreen());

      expect(find.text('Poemas del día'), findsOneWidget);

      await tester.tap(find.text('Índice'));
      await tester.pumpAndSettle();
      expect(find.text('— Índice de Autores —'), findsOneWidget);

      await tester.tap(find.text('Favoritos'));
      await tester.pumpAndSettle();
      expect(find.text('Aún no tienes favoritos'), findsOneWidget);
    });

    testWidgets('each tab keeps its own navigation stack', (tester) async {
      await montar(tester, const RootScreen());

      await tester.tap(find.text('Índice'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Autor 1'));
      await tester.pumpAndSettle();
      expect(find.text('Autor 1'), findsWidgets);

      // Leave and come back: the author screen is still open.
      await tester.tap(find.text('Inicio'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Índice'));
      await tester.pumpAndSettle();
      expect(find.text('Poema 0 de 1'), findsOneWidget);
    });

    testWidgets('back pops the inner stack, then returns to the first tab',
        (tester) async {
      await montar(tester, const RootScreen());

      await tester.tap(find.text('Índice'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Autor 1'));
      await tester.pumpAndSettle();

      // First back: out of the author screen, still on the index tab.
      await simularBack(tester);
      expect(find.text('— Índice de Autores —'), findsOneWidget);

      // Second back: to the today tab rather than doing nothing, which is what
      // the original did — leaving the user unable to leave the app at all.
      await simularBack(tester);
      expect(find.text('Poemas del día'), findsOneWidget);
    });

    testWidgets('tapping the active tab pops it to its root', (tester) async {
      await montar(tester, const RootScreen());

      await tester.tap(find.text('Índice'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Autor 2'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Índice'));
      await tester.pumpAndSettle();
      expect(find.text('— Índice de Autores —'), findsOneWidget);
    });

    testWidgets('a poem link from a 1.1.0 reminder still opens the poem',
        (tester) async {
      final (solicitudes, _) = await montar(tester, const RootScreen());

      solicitudes.pedir('a2-p1');
      await tester.pumpAndSettle();

      expect(find.text('Poema 1 de 2'), findsWidgets);
      // And the request is consumed, so a rebuild can't re-navigate.
      expect(solicitudes.value, isNull);
    });

    testWidgets('the daily reminder opens the today tab at its root',
        (tester) async {
      final (solicitudes, _) = await montar(tester, const RootScreen());

      // The reader was deep in another tab when they tapped the reminder.
      await tester.tap(find.text('Índice'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Autor 1'));
      await tester.pumpAndSettle();

      solicitudes.pedir(SolicitudDePoema.inicio);
      await tester.pumpAndSettle();

      expect(find.text('Poemas del día'), findsOneWidget);
      expect(solicitudes.value, isNull);
    });

    testWidgets('the nav labels follow the phone font size, up to a cap',
        (tester) async {
      // A narrow phone, so the widest Spanish label has the least room. The
      // test font is far wider than the bundled ones, so here the labels are
      // shrunk to fit; the space reserved under the lists must still cover
      // the pill.
      tester.view.physicalSize = const Size(360, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final etiqueta = find.text('Favoritos');
      final pildora = find
          .ancestor(of: etiqueta, matching: find.byType(EscalaLimitada))
          .first;
      Future<(double, double, double)> medir(double escala) async {
        tester.platformDispatcher.textScaleFactorTestValue = escala;
        await montar(tester, const RootScreen());
        final contexto = tester.element(etiqueta);
        final hueco = espacioBarraFlotante(contexto) - 16;
        return (
          MediaQuery.textScalerOf(contexto).scale(1),
          tester.getSize(pildora).height,
          hueco,
        );
      }

      final (normal, altoNormal, huecoNormal) = await medir(1);
      expect(normal, 1);
      expect(altoNormal, lessThanOrEqualTo(huecoNormal));

      final (grande, altoGrande, huecoGrande) = await medir(1.3);
      expect(grande, 1.3);
      expect(altoGrande, greaterThan(altoNormal));
      expect(altoGrande, lessThanOrEqualTo(huecoGrande));

      // At the phone's largest setting the labels stop at the cap, and the
      // pill still fits all four without overflowing.
      final (maxima, altoMaximo, huecoMaximo) = await medir(2);
      expect(maxima, escalaMaximaPildora);
      expect(altoMaximo, lessThanOrEqualTo(huecoMaximo));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a deep link to a poem that no longer exists is ignored',
        (tester) async {
      final (solicitudes, _) = await montar(tester, const RootScreen());

      solicitudes.pedir('poema-borrado');
      await tester.pumpAndSettle();

      expect(find.text('Poemas del día'), findsOneWidget);
    });
  });

  group('PoemaScreen', () {
    testWidgets('renders the poem with its own stanza breaks', (tester) async {
      final anthology = await anthologyDePrueba();
      final prefs = await preferenciasDePrueba({'esquema_prefs': 2});
      await tester.pumpWidget(AppDePrueba(
        anthology: anthology,
        prefs: prefs,
        solicitudes: SolicitudDePoema(),
        agenda: AgendaFalsa(),
        child: PoemaScreen(poema: anthology.porId('a0-p0')!),
      ));
      await tester.pumpAndSettle();

      // Two stanzas in the fixture, joined by a blank line — not by a break
      // after line 4 as the old hardcoded sonnet rule would have done.
      expect(
        find.textContaining('primer verso de 00\nsegundo verso\n\nsegunda'),
        findsOneWidget,
      );
      // The default layout (the Spanish app's) is the centred text above,
      // untouched by DisposicionVersos.ajustada.
      expect(find.byType(VersosAjustados), findsNothing);
    });

    testWidgets('the heart toggles and confirms with the right wording',
        (tester) async {
      final anthology = await anthologyDePrueba();
      final prefs = await preferenciasDePrueba({'esquema_prefs': 2});
      await tester.pumpWidget(AppDePrueba(
        anthology: anthology,
        prefs: prefs,
        solicitudes: SolicitudDePoema(),
        agenda: AgendaFalsa(),
        child: PoemaScreen(poema: anthology.porId('a0-p0')!),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Añadido a favoritos'), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(prefs.leerLista('favoritos_v2'), ['a0-p0']);
    });

    testWidgets('pinching magnifies the page; each poem opens at 1x',
        (tester) async {
      final anthology = await anthologyDePrueba();
      final prefs = await preferenciasDePrueba({'esquema_prefs': 2});
      Future<void> abrir() async {
        await tester.pumpWidget(AppDePrueba(
          anthology: anthology,
          prefs: prefs,
          solicitudes: SolicitudDePoema(),
          agenda: AgendaFalsa(),
          child: PoemaScreen(poema: anthology.porId('a0-p0')!),
        ));
        await tester.pumpAndSettle();
      }

      final versos = find
          .byWidgetPredicate((w) => w is SelectableText && w.textSpan != null);
      await abrir();
      final base = tester.getRect(versos);
      double tamano() =>
          tester.widget<SelectableText>(versos).textSpan!.style!.fontSize!;
      final tamanoBase = tamano();
      final centro = tester.getCenter(find.byType(Scaffold));

      // One finger scrolls or selects; it never magnifies.
      await tester.dragFrom(centro, const Offset(0, -40));
      await tester.pumpAndSettle();
      expect(tester.getRect(versos).size, base.size);

      // Fingers 40 px apart moved to 60: one and a half times.
      final uno = await tester.startGesture(centro - const Offset(0, 20));
      final dos = await tester.startGesture(centro + const Offset(0, 20));
      for (var i = 0; i < 5; i++) {
        await uno.moveBy(const Offset(0, -2));
        await dos.moveBy(const Offset(0, 2));
        await tester.pump();
      }
      await uno.up();
      await dos.up();
      await tester.pumpAndSettle();
      final grande = tester.getRect(versos);
      expect(grande.width, closeTo(base.width * 1.5, .5));
      expect(grande.height, closeTo(base.height * 1.5, .5));
      // Magnified, not laid out again: the text style is unchanged.
      expect(tamano(), tamanoBase);

      // Now wider than the screen, it pans sideways with one finger.
      final antes = tester.getRect(versos).left;
      await tester.dragFrom(centro, const Offset(-100, 0));
      await tester.pumpAndSettle();
      expect(tester.getRect(versos).left, lessThan(antes));

      // The next poem opens at 1x.
      await tester.pumpWidget(const SizedBox());
      await abrir();
      expect(tester.getRect(versos).size, base.size);
    });
  });

  group('BusquedaScreen', () {
    testWidgets('debounces, then matches ignoring accents', (tester) async {
      await montar(tester, const BusquedaScreen());

      await tester.enterText(find.byType(SearchBar), 'poema 1 de 2');
      await tester.pump(); // before the debounce elapses
      expect(find.text('Escribe para buscar'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(find.text('Poema 1 de 2'), findsWidgets);
    });

    testWidgets('shows the empty state for a query with no hits',
        (tester) async {
      await montar(tester, const BusquedaScreen());

      await tester.enterText(find.byType(SearchBar), 'zzzz');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      expect(find.textContaining('Sin resultados'), findsOneWidget);
    });

    testWidgets('clearing returns to the prompt', (tester) async {
      await montar(tester, const BusquedaScreen());

      await tester.enterText(find.byType(SearchBar), 'verso');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(SearchBar), '');
      await tester.pumpAndSettle();
      expect(find.text('Escribe para buscar'), findsOneWidget);
    });
  });

  group('IndiceScreen', () {
    testWidgets('filters authors as you type, ignoring case', (tester) async {
      await montar(tester, const IndiceScreen(), autores: 12);

      await tester.enterText(find.byType(SearchBar), 'AUTOR 1');
      await tester.pumpAndSettle();
      expect(find.text('Autor 1'), findsOneWidget);
      expect(find.text('Autor 10'), findsOneWidget);
      expect(find.text('Autor 11'), findsOneWidget);
      expect(find.text('Autor 2'), findsNothing);

      await tester.enterText(find.byType(SearchBar), 'Quevedo');
      await tester.pumpAndSettle();
      expect(find.text('Ningún autor coincide con «Quevedo»'), findsOneWidget);

      await tester.tap(find.byTooltip('Borrar búsqueda'));
      await tester.pumpAndSettle();
      expect(find.text('Autor 0'), findsOneWidget);
    });
  });

  group('FavoritosScreen', () {
    testWidgets('groups saved poems under their author', (tester) async {
      await montar(
        tester,
        const FavoritosScreen(),
        prefsIniciales: {
          'esquema_prefs': 2,
          'favoritos_v2': ['a0-p0', 'a0-p1', 'a2-p0'],
        },
      );

      expect(find.text('Autor 0'), findsOneWidget);
      expect(find.text('Autor 2'), findsOneWidget);
      expect(find.textContaining('3 poemas guardados'), findsOneWidget);
    });
  });

  group('AjustesScreen', () {
    testWidgets('the reminder hour only appears once reminders are on',
        (tester) async {
      await montar(tester, const AjustesScreen());

      expect(find.text('Hora del aviso'), findsNothing);

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      expect(find.text('Hora del aviso'), findsOneWidget);
    });

    testWidgets('turning an author off updates the count', (tester) async {
      await montar(tester, const AjustesScreen());

      expect(find.text('4 de 4 autores'), findsOneWidget);
      // The reminder card above the list has a Switch of its own, so aim at the
      // one inside the first author's row. The sections above push that row
      // past the list's build extent, so scroll to it first.
      final fila = find.widgetWithText(ListTile, 'Autor 0');
      await tester.scrollUntilVisible(fila, 200);
      final interruptor = find.descendant(
        of: fila,
        matching: find.byType(Switch),
      );
      await tester.ensureVisible(interruptor);
      await tester.pumpAndSettle();
      await tester.tap(interruptor);
      await tester.pumpAndSettle();
      // The row now sits at the top of the screen, with the count above it and
      // past the build extent, so scroll back up to read it.
      await tester.scrollUntilVisible(find.text('3 de 4 autores'), -200);
      expect(find.text('3 de 4 autores'), findsOneWidget);
    });

    testWidgets('the sources entry opens the credits with each link',
        (tester) async {
      await montar(tester, const AjustesScreen());

      // Last in the screen, below the author list.
      final entrada = find.text('Fuente de prueba');
      await tester.scrollUntilVisible(entrada, 200);
      await tester.ensureVisible(entrada);
      await tester.pumpAndSettle();
      await tester.tap(entrada);
      await tester.pumpAndSettle();

      expect(find.text('Fuentes de los textos'), findsOneWidget);
      expect(find.text('Textos de prueba, bajo una licencia de prueba.'),
          findsOneWidget);
      expect(find.text('https://example.org'), findsOneWidget);
    });

    testWidgets('the privacy entry opens the policy in the browser',
        (tester) async {
      final abiertos = <String>[];
      const canal = MethodChannel('plugins.flutter.io/url_launcher');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(canal,
          (llamada) async {
        if (llamada.method == 'launch') {
          abiertos.add((llamada.arguments as Map)['url'] as String);
        }
        return true;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(canal, null));

      await montar(tester, const AjustesScreen());

      final entrada = find.text('Política de privacidad');
      await tester.scrollUntilVisible(entrada, 200);
      await tester.ensureVisible(entrada);
      await tester.pumpAndSettle();
      await tester.tap(entrada);
      await tester.pumpAndSettle();

      expect(abiertos, ['https://example.org/privacidad']);
    });
  });
}

/// Fires a system back press the way Android does.
Future<void> simularBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}
