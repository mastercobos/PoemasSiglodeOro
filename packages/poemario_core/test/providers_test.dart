import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poemario_core/domain/seleccion_diaria.dart';
import 'package:poemario_core/notifications/agenda_avisos.dart';
import 'package:poemario_core/providers/ajustes_provider.dart';
import 'package:poemario_core/providers/favoritos_provider.dart';
import 'package:poemario_core/providers/notificaciones_provider.dart';
import 'package:poemario_core/providers/poema_del_dia_provider.dart';
import 'package:poemario_core/providers/tema_provider.dart';

import 'support/harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FavoritosProvider', () {
    test('loads saved ids and ignores ones that no longer resolve', () async {
      final anthology = await anthologyDePrueba();
      final prefs = await preferenciasDePrueba({
        'favoritos_v2': ['a0-p0', 'poema-borrado'],
        'esquema_prefs': 2,
      });

      final favoritos =
          FavoritosProvider(anthology: anthology, prefs: prefs);
      expect(favoritos.favoritos.map((p) => p.id), ['a0-p0']);
    });

    test('toggle reports the resulting state and persists it', () async {
      final anthology = await anthologyDePrueba();
      final prefs = await preferenciasDePrueba({'esquema_prefs': 2});
      final favoritos =
          FavoritosProvider(anthology: anthology, prefs: prefs);
      final poema = anthology.porId('a1-p0')!;

      expect(await favoritos.alternar(poema), isTrue);
      expect(prefs.leerLista('favoritos_v2'), ['a1-p0']);
      expect(await favoritos.alternar(poema), isFalse);
      expect(prefs.leerLista('favoritos_v2'), isEmpty);
    });

    test('favourites come back in anthology order, not insertion order',
        () async {
      final anthology = await anthologyDePrueba();
      final prefs = await preferenciasDePrueba({'esquema_prefs': 2});
      final favoritos =
          FavoritosProvider(anthology: anthology, prefs: prefs);

      await favoritos.alternar(anthology.porId('a2-p0')!);
      await favoritos.alternar(anthology.porId('a0-p0')!);

      expect(favoritos.favoritos.map((p) => p.id), ['a0-p0', 'a2-p0']);
    });

    test('a corrupt stored list does not crash construction', () async {
      final anthology = await anthologyDePrueba();
      final prefs = await preferenciasDePrueba({
        'favoritos_v2': ['', '   ', 'a0-p0'],
        'esquema_prefs': 2,
      });
      expect(
        FavoritosProvider(anthology: anthology, prefs: prefs).total,
        1,
      );
    });
  });

  group('AjustesProvider', () {
    test('everything is active on a fresh install', () async {
      final anthology = await anthologyDePrueba(autores: 3, porAutor: 1);
      final prefs = await preferenciasDePrueba({'esquema_prefs': 2});
      final ajustes = AjustesProvider(
          todosLosAutores: anthology.autores, prefs: prefs);

      expect(ajustes.totalActivos, 3);
      expect(ajustes.todosSeleccionados, isTrue);
    });

    test('stale exclusions from removed authors are dropped on load',
        () async {
      final anthology = await anthologyDePrueba(autores: 2, porAutor: 1);
      final prefs = await preferenciasDePrueba({
        'autores_excluidos': ['Autor 0', 'Poeta que ya no está'],
        'esquema_prefs': 2,
      });
      final ajustes = AjustesProvider(
          todosLosAutores: anthology.autores, prefs: prefs);

      expect(ajustes.totalActivos, 1);
      await ajustes.alternarAutor('Autor 0');
      // The ghost is gone from storage too, rather than accumulating forever.
      expect(prefs.leerLista('autores_excluidos'), isEmpty);
    });

    test('select all / none', () async {
      final anthology = await anthologyDePrueba(autores: 3, porAutor: 1);
      final prefs = await preferenciasDePrueba({'esquema_prefs': 2});
      final ajustes = AjustesProvider(
          todosLosAutores: anthology.autores, prefs: prefs);

      await ajustes.deseleccionarTodos();
      expect(ajustes.ningunoSeleccionado, isTrue);
      await ajustes.seleccionarTodos();
      expect(ajustes.todosSeleccionados, isTrue);
      expect(prefs.leerLista('autores_excluidos'), isEmpty);
    });
  });

  group('TemaProvider', () {
    test('defaults to system and round-trips through preferences', () async {
      final prefs = await preferenciasDePrueba();
      final tema = TemaProvider(prefs);
      expect(tema.modo, ThemeMode.system);

      await tema.establecer(ThemeMode.dark);
      expect(prefs.leerTexto('tema'), 'dark');
      expect(TemaProvider(prefs).modo, ThemeMode.dark);
    });

    test('an unrecognised stored value falls back to system', () async {
      final prefs = await preferenciasDePrueba({'tema': 'sepia'});
      expect(TemaProvider(prefs).modo, ThemeMode.system);
    });
  });

  group('PoemaDelDiaProvider', () {
    test('the pool follows the author filter', () async {
      final anthology = await anthologyDePrueba(autores: 3, porAutor: 2);
      final prefs = await preferenciasDePrueba({'esquema_prefs': 2});
      final ajustes = AjustesProvider(
          todosLosAutores: anthology.autores, prefs: prefs);
      final diario = PoemaDelDiaProvider(
          anthology: anthology, prefs: prefs, ajustes: ajustes);

      expect(diario.pool.length, 6);
      await ajustes.alternarAutor('Autor 0');
      expect(diario.pool.length, 4);
      expect(diario.pool.every((p) => p.autor != 'Autor 0'), isTrue);
    });

    test('the selection is cached until the filter changes', () async {
      final anthology = await anthologyDePrueba(autores: 6, porAutor: 2);
      final prefs = await preferenciasDePrueba({'esquema_prefs': 2});
      final ajustes = AjustesProvider(
          todosLosAutores: anthology.autores, prefs: prefs);
      final diario = PoemaDelDiaProvider(
          anthology: anthology, prefs: prefs, ajustes: ajustes);

      final primera = diario.poemasDelDia;
      expect(identical(diario.poemasDelDia, primera), isTrue);

      await ajustes.deseleccionarTodos();
      expect(diario.poemasDelDia, isEmpty);
    });

    test('registrarVisto records the day once and changes nothing shown',
        () async {
      final anthology = await anthologyDePrueba(autores: 6, porAutor: 2);
      final prefs = await preferenciasDePrueba({'esquema_prefs': 3});
      final ajustes =
          AjustesProvider(todosLosAutores: anthology.autores, prefs: prefs);
      final diario = PoemaDelDiaProvider(
          anthology: anthology, prefs: prefs, ajustes: ajustes);

      final antes = diario.poemasDelDia;
      final historialAntes = diario.historial;
      await diario.registrarVisto();
      final fecha = prefs.leerTexto(PoemaDelDiaProvider.claveFecha);
      await diario.registrarVisto();

      expect(fecha, isNotNull);
      expect(prefs.leerTexto(PoemaDelDiaProvider.claveFecha), fecha);
      // The 1.1.0 bug: recording today put today's authors into the history
      // that the next reschedule started from, so the schedule recomputed
      // today while avoiding today's own poems.
      expect(diario.historial, historialAntes);
      expect(diario.poemasDelDia, antes);
    });

    test('days the app was not opened still count, as the schedule assumed',
        () async {
      final anthology = await anthologyDePrueba(autores: 8, porAutor: 2);
      final hoy = DateTime.now();
      final haceTres = DateTime(hoy.year, hoy.month, hoy.day - 3);
      final prefs = await preferenciasDePrueba({
        'esquema_prefs': 3,
        PoemaDelDiaProvider.claveHistorial: ['Autor 0', 'Autor 1'],
        PoemaDelDiaProvider.claveFecha: haceTres.toIso8601String(),
      });
      final ajustes =
          AjustesProvider(todosLosAutores: anthology.autores, prefs: prefs);
      final diario = PoemaDelDiaProvider(
          anthology: anthology, prefs: prefs, ajustes: ajustes);

      // What a schedule built three days ago named for today.
      final planeado = SeleccionDiariaService.serie(
        pool: anthology.poemas,
        desde: haceTres,
        dias: 4,
        autoresRecientes: const ['Autor 0', 'Autor 1'],
      ).last;
      expect(diario.poemasDelDia, planeado.poemas);
    });
  });

  group('NotificacionesProvider', () {
    Future<(NotificacionesProvider, AgendaFalsa)> construir({
      Map<String, Object> inicial = const {'esquema_prefs': 2},
    }) async {
      final anthology = await anthologyDePrueba(autores: 6, porAutor: 2);
      final prefs = await preferenciasDePrueba(inicial);
      final ajustes = AjustesProvider(
          todosLosAutores: anthology.autores, prefs: prefs);
      final diario = PoemaDelDiaProvider(
          anthology: anthology, prefs: prefs, ajustes: ajustes);
      final agenda = AgendaFalsa();
      return (
        NotificacionesProvider(
          prefs: prefs,
          servicio: agenda,
          diario: diario,
          horaPorDefecto: const TimeOfDay(hour: 9, minute: 0),
          textos: () => TextosAvisoDePrueba.instancia,
        ),
        agenda,
      );
    }

    test('off by default and schedules nothing', () async {
      final (avisos, agenda) = await construir();
      expect(avisos.activo, isFalse);
      expect(agenda.reprogramaciones, 0);
    });

    test('enabling asks for permission and schedules', () async {
      final (avisos, agenda) = await construir();
      expect(await avisos.activar(), isTrue);
      expect(avisos.activo, isTrue);
      expect(agenda.reprogramaciones, 1);
    });

    test('a refused prompt leaves the switch off and flags the refusal',
        () async {
      final (avisos, agenda) = await construir();
      agenda.respuestaAlPedir = EstadoPermisoAviso.denegado;

      expect(await avisos.activar(), isFalse);
      expect(avisos.activo, isFalse);
      expect(avisos.permisoDenegado, isTrue);
      expect(agenda.reprogramaciones, 0);
    });

    test('permission revoked later stops the schedule and tells the UI',
        () async {
      final (avisos, agenda) = await construir();
      await avisos.activar();

      // The reader turned notifications off in system settings.
      agenda.permiso = false;
      await avisos.establecerHora(const TimeOfDay(hour: 7, minute: 30));

      expect(avisos.permisoDenegado, isTrue);
      expect(agenda.reprogramaciones, 1); // no new attempt
    });

    test('changing the hour persists it and reschedules', () async {
      final (avisos, agenda) = await construir();
      await avisos.activar();
      await avisos.establecerHora(const TimeOfDay(hour: 7, minute: 30));

      expect(agenda.ultimaHora, const TimeOfDay(hour: 7, minute: 30));
      expect(agenda.reprogramaciones, 2);
    });

    test('disabling cancels everything', () async {
      final (avisos, agenda) = await construir();
      await avisos.activar();
      await avisos.desactivar();

      expect(avisos.activo, isFalse);
      expect(agenda.cancelaciones, greaterThan(0));
    });

    test('a saved hour is restored', () async {
      final (avisos, _) = await construir(
        inicial: {'esquema_prefs': 2, 'aviso_hora': 7 * 60 + 45},
      );
      expect(avisos.hora, const TimeOfDay(hour: 7, minute: 45));
    });

    test('an out-of-range stored hour falls back to the default', () async {
      final (avisos, _) = await construir(
        inicial: {'esquema_prefs': 2, 'aviso_hora': 99999},
      );
      expect(avisos.hora, const TimeOfDay(hour: 9, minute: 0));
    });
  });
}
