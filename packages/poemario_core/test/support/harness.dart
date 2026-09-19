import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:poemario_core/config/app_config.dart';
import 'package:poemario_core/data/poema.dart';
import 'package:poemario_core/data/poema_repository.dart';
import 'package:poemario_core/data/preferencias.dart';
import 'package:poemario_core/domain/orden_titulos.dart';
import 'package:poemario_core/l10n/generated/app_localizations.dart';
import 'package:poemario_core/notifications/agenda_avisos.dart';
import 'package:poemario_core/notifications/planificador_avisos.dart';
import 'package:poemario_core/providers/ajustes_provider.dart';
import 'package:poemario_core/providers/favoritos_provider.dart';
import 'package:poemario_core/providers/notificaciones_provider.dart';
import 'package:poemario_core/providers/poema_del_dia_provider.dart';
import 'package:poemario_core/providers/tema_provider.dart';
import 'package:poemario_core/theme/poema_colors.dart';
import 'package:poemario_core/theme/poema_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'asset_falso.dart';

/// Config used by every widget test. Fonts are left as the family names the
/// apps declare; the test environment falls back to Ahem, which is fine
/// because we assert on text and structure, not on glyphs.
const configPrueba = AppConfig(
  locale: Locale('es'),
  nombreApp: 'Antología de prueba',
  firmaCompartir: 'Prueba',
  ordenTitulos: EstrategiaOrden.romanosPrimero,
  fuentes: FontPair(display: 'PlayfairDisplay', body: 'Lato'),
  coloresClaro: PoemaColors.claroPorDefecto,
  coloresOscuro: PoemaColors.oscuroPorDefecto,
);

/// A small anthology with predictable content.
///
/// Authors are "Autor 0".."Autor n-1" and every poem has an explicit id, so
/// tests never depend on the hashing fallback.
Future<Anthology> anthologyDePrueba({
  int autores = 4,
  int porAutor = 3,
}) async {
  final json = [
    for (var a = 0; a < autores; a++)
      for (var p = 0; p < porAutor; p++)
        {
          'id': 'a$a-p$p',
          'autor': 'Autor $a',
          'titulo': 'Poema $p de $a',
          'texto': 'primer verso de $a$p\nsegundo verso\n\nsegunda estrofa',
        },
  ];
  return cargarDesdeAssetFalso(json, configPrueba.compararTitulos);
}

/// Registers [json] as `assets/poemas.json` and loads it through the *real*
/// repository, so tests exercise the same parsing, indexing and sorting the
/// app does rather than a hand-built stand-in.
Future<Anthology> cargarDesdeAssetFalso(
  List<Map<String, dynamic>> json,
  int Function(String, String) comparador, {
  String ruta = 'assets/poemas.json',
}) async {
  registrarAsset(ruta, comoJson(json));
  return PoemaRepository(assetPath: ruta, compararTitulos: comparador).cargar();
}

/// A [Preferencias] backed by mock shared_preferences.
Future<Preferencias> preferenciasDePrueba([
  Map<String, Object> inicial = const {},
]) async {
  SharedPreferences.setMockInitialValues(inicial);
  return Preferencias.abrir();
}

/// Records what the provider asked the OS to do.
class AgendaFalsa implements AgendaAvisos {
  bool permiso = true;
  EstadoPermisoAviso respuestaAlPedir = EstadoPermisoAviso.concedido;

  int reprogramaciones = 0;
  int cancelaciones = 0;
  List<Poema> ultimoPool = const [];
  TimeOfDay? ultimaHora;

  @override
  Future<bool> permisoConcedido() async => permiso;

  @override
  Future<EstadoPermisoAviso> pedirPermiso() async {
    if (respuestaAlPedir == EstadoPermisoAviso.concedido) permiso = true;
    return respuestaAlPedir;
  }

  @override
  Future<void> reprogramar({
    required List<Poema> pool,
    required TimeOfDay hora,
    required TextosAviso textos,
    List<String> autoresRecientes = const [],
  }) async {
    reprogramaciones++;
    ultimoPool = pool;
    ultimaHora = hora;
  }

  @override
  Future<void> cancelarTodo() async => cancelaciones++;
}

/// Wraps [child] in the full provider stack and a localised [MaterialApp],
/// so a screen can be pumped exactly as it runs in the app.
class AppDePrueba extends StatelessWidget {
  final Widget child;
  final Anthology anthology;
  final Preferencias prefs;
  final SolicitudDePoema solicitudes;
  final AgendaFalsa agenda;

  const AppDePrueba({
    super.key,
    required this.child,
    required this.anthology,
    required this.prefs,
    required this.solicitudes,
    required this.agenda,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppConfig>.value(value: configPrueba),
        Provider<Anthology>.value(value: anthology),
        Provider<Preferencias>.value(value: prefs),
        Provider<SolicitudDePoema>.value(value: solicitudes),
        ChangeNotifierProvider(create: (_) => TemaProvider(prefs)),
        ChangeNotifierProvider(
          create: (_) =>
              FavoritosProvider(anthology: anthology, prefs: prefs),
        ),
        ChangeNotifierProvider(
          create: (_) => AjustesProvider(
              todosLosAutores: anthology.autores, prefs: prefs),
        ),
        ChangeNotifierProxyProvider<AjustesProvider, PoemaDelDiaProvider>(
          create: (ctx) => PoemaDelDiaProvider(
            anthology: anthology,
            prefs: prefs,
            ajustes: ctx.read<AjustesProvider>(),
          ),
          update: (_, __, previo) => previo!,
        ),
        ChangeNotifierProxyProvider<PoemaDelDiaProvider,
            NotificacionesProvider>(
          create: (ctx) => NotificacionesProvider(
            prefs: prefs,
            servicio: agenda,
            diario: ctx.read<PoemaDelDiaProvider>(),
            horaPorDefecto: const TimeOfDay(hour: 9, minute: 0),
            textos: () => const TextosAviso(
                titulo: 't', cuerpo: _cuerpoFalso, cuerpoGenerico: 'g'),
          ),
          update: (_, __, previo) => previo!,
          lazy: false,
        ),
      ],
      child: MaterialApp(
        theme: configPrueba.temaClaro,
        darkTheme: configPrueba.temaOscuro,
        locale: configPrueba.locale,
        supportedLocales: L10n.supportedLocales,
        localizationsDelegates: const [
          L10n.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: child,
      ),
    );
  }
}

String _cuerpoFalso(Poema p) => p.etiqueta;

/// Notification copy for tests, so provider tests don't need a BuildContext.
abstract final class TextosAvisoDePrueba {
  static const instancia = TextosAviso(
    titulo: 'Poema del día',
    cuerpo: _cuerpoFalso,
    cuerpoGenerico: 'Hay poemas nuevos',
  );
}
