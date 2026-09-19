import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poemario_core/notifications/agenda_avisos.dart';
import 'package:poemario_core/screens/ajustes_screen.dart';
import 'package:poemario_core/screens/busqueda_screen.dart';
import 'package:poemario_core/screens/favoritos_screen.dart';
import 'package:poemario_core/screens/poema_screen.dart';
import 'package:poemario_core/screens/root_screen.dart';

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

    testWidgets('a notification deep link opens the poem on the today tab',
        (tester) async {
      final (solicitudes, _) = await montar(tester, const RootScreen());

      solicitudes.pedir('a2-p1');
      await tester.pumpAndSettle();

      expect(find.text('Poema 1 de 2'), findsWidgets);
      // And the request is consumed, so a rebuild can't re-navigate.
      expect(solicitudes.value, isNull);
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
        find.textContaining('primer verso de a00\nsegundo verso\n\nsegunda'),
        findsOneWidget,
      );
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
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      expect(find.text('3 de 4 autores'), findsOneWidget);
    });
  });
}

/// Fires a system back press the way Android does.
Future<void> simularBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}
