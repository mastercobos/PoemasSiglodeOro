import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'config/app_config.dart';
import 'data/poema_repository.dart';
import 'data/preferencias.dart';
import 'donaciones/servicio_propinas.dart';
import 'donaciones/tienda_propinas.dart';
import 'l10n/generated/app_localizations.dart';
import 'notifications/planificador_avisos.dart';
import 'notifications/servicio_avisos.dart';
import 'providers/ajustes_provider.dart';
import 'providers/notificaciones_provider.dart';
import 'providers/favoritos_provider.dart';
import 'providers/poema_del_dia_provider.dart';
import 'providers/propinas_provider.dart';
import 'providers/tema_provider.dart';

/// Starts an anthology app.
///
/// Every app package's `main()` is a call to this with its own [AppConfig].
/// Nothing app-specific may be added here — if a new app needs something
/// different, it becomes a field on [AppConfig].
///
/// [tiendaPropinas] exists so a preview or test can run the real app without
/// the store; production leaves it null.
Future<void> bootstrap(
  AppConfig config, {
  required WidgetBuilder home,
  TiendaPropinas? tiendaPropinas,
}) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Edge-to-edge. `setEnabledSystemUIMode` is the part the original was
  // missing: on Android 15 the system enforces edge-to-edge anyway, and
  // without this the insets come out wrong on 14 and below.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
  ));

  final prefs = await Preferencias.abrir(prefijo: config.prefijoPreferencias);

  final Anthology anthology;
  try {
    anthology = await PoemaRepository(
      assetPath: config.assetPoemas,
      compararTitulos: config.compararTitulos,
    ).cargar();
  } catch (e, st) {
    // A malformed asset used to produce a black screen and a stack trace in
    // the console. Now the user sees something they can act on.
    debugPrint('$e');
    debugPrintStack(stackTrace: st);
    runApp(_AppDeError(config: config));
    return;
  }

  // Must run before any provider reads preferences.
  await prefs.migrar(anthology);

  // Started here rather than lazily, because a tap that cold-started the app
  // has to be read before the first frame or the deep link is lost.
  final solicitudes = SolicitudDePoema();
  final avisos = ServicioAvisos(
    canalNombre: config.nombreApp,
    canalDescripcion: config.nombreApp,
    solicitudes: solicitudes,
  );
  await avisos.iniciar();

  // Not awaited: the store query can take seconds and the tip jar is optional.
  // Started now rather than when settings opens, because an interrupted
  // purchase is delivered at launch and has to be completed.
  final propinas = PropinasProvider(
    tienda: tiendaPropinas ?? ServicioPropinas(),
    ids: config.idsPropinas,
  );
  unawaited(propinas.iniciar());

  // The search index folds every poem (and, for a split anthology, loads
  // every text): seconds of work on a phone, so it starts once the first
  // screen is up, off the UI isolate. Search waits for it if it has to.
  WidgetsBinding.instance
      .addPostFrameCallback((_) => unawaited(anthology.indiceBusqueda));

  runApp(_AppPoemario(
    config: config,
    anthology: anthology,
    prefs: prefs,
    avisos: avisos,
    solicitudes: solicitudes,
    propinas: propinas,
    home: home,
  ));
}

/// Needed so the notification provider can resolve localised strings without
/// holding a BuildContext of its own.
final GlobalKey<NavigatorState> _claveNavegador = GlobalKey<NavigatorState>();

/// Localised notification copy. Public so the settings screen can preview it.
TextosAviso textosAviso(BuildContext context) {
  final l10n = L10n.of(context);
  return TextosAviso(
    titulo: l10n.notifTitulo,
    // An untitled poem's label *is* its first verse; don't print it twice.
    linea: (p) => p.mostrarPrimerVerso
        ? l10n.notifLinea(p.titulo, p.autor, p.primerVersoSinComillas)
        : l10n.notifLineaSinTitulo(p.primerVersoSinComillas, p.autor),
    cuerpoGenerico: l10n.notifCuerpoGenerico,
  );
}

class _AppPoemario extends StatelessWidget {
  final AppConfig config;
  final Anthology anthology;
  final Preferencias prefs;
  final ServicioAvisos avisos;
  final SolicitudDePoema solicitudes;
  final PropinasProvider propinas;
  final WidgetBuilder home;

  const _AppPoemario({
    required this.config,
    required this.anthology,
    required this.prefs,
    required this.avisos,
    required this.solicitudes,
    required this.propinas,
    required this.home,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppConfig>.value(value: config),
        // The anthology is immutable, so it's a plain value rather than a
        // notifier. This also removes the `todosLosPoemas` parameter that was
        // threaded through eight widget constructors.
        Provider<Anthology>.value(value: anthology),
        Provider<Preferencias>.value(value: prefs),
        Provider<ServicioAvisos>.value(value: avisos),
        // A Listenable, so plain Provider.value trips a debug assertion.
        // Consumers `read` it and attach their own listener.
        ListenableProvider<SolicitudDePoema>.value(value: solicitudes),
        ChangeNotifierProvider<PropinasProvider>.value(value: propinas),
        ChangeNotifierProvider(
          create: (_) => TemaProvider(prefs),
        ),
        ChangeNotifierProvider(
          create: (_) => FavoritosProvider(anthology: anthology, prefs: prefs),
        ),
        ChangeNotifierProvider(
          create: (_) => AjustesProvider(
            todosLosAutores: anthology.autores,
            prefs: prefs,
          ),
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
            servicio: avisos,
            diario: ctx.read<PoemaDelDiaProvider>(),
            horaPorDefecto: NotificacionesProvider.horaPorDefecto,
            // Resolved lazily against the navigator's context, so the strings
            // follow the app's locale without the provider holding a context.
            textos: () => textosAviso(_claveNavegador.currentContext!),
          ),
          update: (_, __, previo) => previo!,
          lazy: false,
        ),
      ],
      child: Consumer<TemaProvider>(
        builder: (context, tema, _) => MaterialApp(
          title: config.nombreApp,
          debugShowCheckedModeBanner: false,
          themeMode: tema.modo,
          theme: config.temaClaro,
          darkTheme: config.temaOscuro,
          // The original declared `intl` and `flutter_localizations` as
          // dependencies but wired neither, so Material's own strings — the
          // text-selection menu over every SelectableText, among others —
          // rendered in English inside a Spanish app.
          locale: config.locale,
          supportedLocales: L10n.supportedLocales,
          localizationsDelegates: const [
            L10n.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          navigatorKey: _claveNavegador,
          home: Builder(builder: home),
        ),
      ),
    );
  }
}

/// Shown when the anthology can't be loaded. Deliberately depends on nothing
/// but [AppConfig]: if the asset is broken, providers were never created.
class _AppDeError extends StatelessWidget {
  final AppConfig config;
  const _AppDeError({required this.config});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: config.nombreApp,
      debugShowCheckedModeBanner: false,
      theme: config.temaClaro,
      locale: config.locale,
      supportedLocales: L10n.supportedLocales,
      localizationsDelegates: const [
        L10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Builder(
        builder: (context) {
          final l10n = L10n.of(context);
          final colores = config.coloresClaro;
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.menu_book_outlined,
                        size: 56, color: colores.oro),
                    const SizedBox(height: 20),
                    Text(
                      l10n.errorCargaTitulo,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l10n.errorCargaSubtitulo,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
