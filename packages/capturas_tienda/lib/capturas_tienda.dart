/// App Store screenshots of an anthology app, drawn without a device.
///
/// Each app calls [generarCapturas] from `capturas/capturas_test.dart` with
/// its own [AppConfig] and a [GuionCapturas] naming the poems to show, then
/// runs it from the app's folder:
///
///     flutter test capturas/
///
/// The real [RootScreen] is mounted with the app's real anthology, fonts and
/// icons, at the exact pixel size Apple asks for, laid out as on iOS. Every
/// screen is reached the way a reader would reach it (tabs, the inner
/// navigators), so the floating nav pill and the app bars are the real ones.
/// Output goes to `$SALIDA` (default `build/capturas`):
/// `<device>/<claro|oscuro>/NN_screen.png`.
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poemario_core/config/app_config.dart';
import 'package:poemario_core/data/poema.dart';
import 'package:poemario_core/data/poema_repository.dart';
import 'package:poemario_core/data/preferencias.dart';
import 'package:poemario_core/domain/orden_titulos.dart';
import 'package:poemario_core/domain/seleccion_diaria.dart';
import 'package:poemario_core/donaciones/tienda_propinas.dart';
import 'package:poemario_core/l10n/generated/app_localizations.dart';
import 'package:poemario_core/notifications/agenda_avisos.dart';
import 'package:poemario_core/notifications/planificador_avisos.dart';
import 'package:poemario_core/providers/ajustes_provider.dart';
import 'package:poemario_core/providers/favoritos_provider.dart';
import 'package:poemario_core/providers/notificaciones_provider.dart';
import 'package:poemario_core/providers/poema_del_dia_provider.dart';
import 'package:poemario_core/providers/propinas_provider.dart';
import 'package:poemario_core/providers/tema_provider.dart';
import 'package:poemario_core/screens/ajustes_screen.dart';
import 'package:poemario_core/screens/autor_screen.dart';
import 'package:poemario_core/screens/busqueda_screen.dart';
import 'package:poemario_core/screens/indice_screen.dart';
import 'package:poemario_core/screens/inicio_screen.dart';
import 'package:poemario_core/screens/poema_screen.dart';
import 'package:poemario_core/screens/root_screen.dart';
import 'package:poemario_core/utils/navegacion.dart';
import 'package:poemario_core/widgets/escala_tableta.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A screen size App Store Connect asks screenshots for.
class Dispositivo {
  final String nombre;

  /// Logical size; times [escala] it is the screenshot's size in pixels.
  final double ancho;
  final double alto;
  final double escala;

  /// Safe-area insets: the status bar / Dynamic Island and the home
  /// indicator, so the layout leaves the room it leaves on the device.
  final double margenSuperior;
  final double margenInferior;

  const Dispositivo({
    required this.nombre,
    required this.ancho,
    required this.alto,
    required this.escala,
    required this.margenSuperior,
    required this.margenInferior,
  });
}

/// iPhone 6.9″ (16 Pro Max class): 1320 × 2868. App Store Connect scales it
/// down for the smaller iPhones.
const iphone69 = Dispositivo(
  nombre: 'iphone_6.9',
  ancho: 440,
  alto: 956,
  escala: 3,
  margenSuperior: 62,
  margenInferior: 34,
);

/// iPad 13″: 2064 × 2752. Needed while the app declares iPad support.
const ipad13 = Dispositivo(
  nombre: 'ipad_13',
  ancho: 1032,
  alto: 1376,
  escala: 2,
  margenSuperior: 24,
  margenInferior: 20,
);

/// A poem named by its author and the start of its first verse, which stays
/// put when the anthology is rebuilt (ids and titles are less memorable).
class PoemaBuscado {
  final String autor;
  final String inicio;

  const PoemaBuscado(this.autor, this.inicio);

  Poema en(Anthology anthology) {
    final buscado = plegarParaOrden(inicio);
    for (final p in anthology.poemas) {
      if (p.autor == autor &&
          plegarParaOrden(p.primerVerso).startsWith(buscado)) {
        return p;
      }
    }
    throw StateError('No hay ningún poema de $autor que empiece por «$inicio»');
  }
}

/// What the screenshots show.
class GuionCapturas {
  final AppConfig config;

  /// The two poems of the day on Home; each also gets a reader screenshot.
  final PoemaBuscado primero;
  final PoemaBuscado segundo;

  /// Saved poems, shown grouped by author on the favourites tab. [primero]
  /// and [segundo] are added to them.
  final List<PoemaBuscado> favoritos;

  /// The author page shown.
  final String autor;

  /// A word typed into search.
  final String busqueda;

  const GuionCapturas({
    required this.config,
    required this.primero,
    required this.segundo,
    required this.favoritos,
    required this.autor,
    required this.busqueda,
  });
}

/// Declares one test per device and theme, each writing every screenshot.
void generarCapturas(
  GuionCapturas guion, {
  List<Dispositivo> dispositivos = const [iphone69, ipad13],
}) {
  late Anthology anthology;
  late List<Poema> delDia;
  late List<Poema> favoritos;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await cargarFuentes(guion.config.fuentes.body);
    anthology = await PoemaRepository(
      assetPath: guion.config.assetPoemas,
      compararTitulos: guion.config.compararTitulos,
    ).cargar();
    // Search needs it ready; for a split anthology it also loads every text.
    await anthology.indiceBusqueda;
    delDia = [guion.primero.en(anthology), guion.segundo.en(anthology)];
    favoritos = [
      ...delDia,
      for (final b in guion.favoritos) b.en(anthology),
    ];
    for (final p in favoritos) {
      await p.cargarTexto();
    }
  });

  for (final d in dispositivos) {
    for (final oscuro in [false, true]) {
      testWidgets(
        '${d.nombre} ${oscuro ? 'oscuro' : 'claro'}',
        (tester) => _recorrido(
          tester,
          guion: guion,
          dispositivo: d,
          oscuro: oscuro,
          anthology: anthology,
          delDia: delDia,
          favoritos: favoritos,
        ),
        // iOS back chevrons, scroll physics and page transitions.
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
        timeout: const Timeout(Duration(minutes: 5)),
      );
    }
  }
}

Future<void> _recorrido(
  WidgetTester tester, {
  required GuionCapturas guion,
  required Dispositivo dispositivo,
  required bool oscuro,
  required Anthology anthology,
  required List<Poema> delDia,
  required List<Poema> favoritos,
}) async {
  final config = guion.config;
  final d = dispositivo;
  final margenes = FakeViewPadding(
    top: d.margenSuperior * d.escala,
    bottom: d.margenInferior * d.escala,
  );
  tester.view
    ..physicalSize = Size(d.ancho * d.escala, d.alto * d.escala)
    ..devicePixelRatio = d.escala
    ..padding = margenes
    ..viewPadding = margenes;
  addTearDown(tester.view.reset);

  // This package only ever runs under `flutter test`.
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({});
  final prefs = await Preferencias.abrir(prefijo: config.prefijoPreferencias);
  await prefs.migrar(anthology);
  await prefs.guardarLista(
      'favoritos_v2', [for (final p in favoritos) p.id]);

  final tema = TemaProvider(prefs);
  await tema.establecer(oscuro ? ThemeMode.dark : ThemeMode.light);
  final ajustes =
      AjustesProvider(todosLosAutores: anthology.autores, prefs: prefs);
  final diario = _DelDiaFijo(
    anthology: anthology,
    prefs: prefs,
    ajustes: ajustes,
    fijos: delDia,
  );
  final avisos = NotificacionesProvider(
    prefs: prefs,
    servicio: _AgendaQuieta(),
    diario: diario,
    horaPorDefecto: NotificacionesProvider.horaPorDefecto,
    textos: () => const TextosAviso(
        titulo: '', linea: _sinTexto, cuerpoGenerico: ''),
  );
  // The settings screenshot shows the daily reminder switched on.
  await avisos.activar();
  final solicitudes = SolicitudDePoema();
  final clave = GlobalKey();

  await tester.pumpWidget(RepaintBoundary(
    key: clave,
    child: MultiProvider(
      providers: [
        Provider<AppConfig>.value(value: config),
        Provider<Anthology>.value(value: anthology),
        Provider<Preferencias>.value(value: prefs),
        ListenableProvider<SolicitudDePoema>.value(value: solicitudes),
        ChangeNotifierProvider<PropinasProvider>(
          create: (_) => PropinasProvider(
              tienda: _TiendaCerrada(), ids: config.idsPropinas),
        ),
        ChangeNotifierProvider<TemaProvider>.value(value: tema),
        ChangeNotifierProvider(
          create: (_) => FavoritosProvider(anthology: anthology, prefs: prefs),
        ),
        ChangeNotifierProvider<AjustesProvider>.value(value: ajustes),
        ChangeNotifierProvider<PoemaDelDiaProvider>.value(value: diario),
        ChangeNotifierProvider<NotificacionesProvider>.value(value: avisos),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        themeMode: tema.modo,
        theme: config.temaClaro,
        darkTheme: config.temaOscuro,
        locale: config.locale,
        supportedLocales: L10n.supportedLocales,
        localizationsDelegates: const [
          L10n.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (_, app) => EscalaTableta(child: app!),
        home: const RootScreen(),
      ),
    ),
  ));

  // Images and split-anthology texts load on the real event loop, which the
  // test's fake clock doesn't run; let it turn between frames.
  Future<void> asentar() async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.pumpAndSettle();
  }

  final salida = Platform.environment['SALIDA'] ?? 'build/capturas';
  final carpeta = '$salida/${d.nombre}/${oscuro ? 'oscuro' : 'claro'}';
  Future<void> capturar(String nombre) async {
    await asentar();
    final limite =
        clave.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final png = await tester.runAsync(() async {
      final imagen = await limite.toImage(pixelRatio: d.escala);
      final datos = await imagen.toByteData(format: ui.ImageByteFormat.png);
      imagen.dispose();
      return datos!.buffer.asUint8List();
    });
    File('$carpeta/$nombre.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!);
  }

  NavigatorState navegadorDe(Type pantalla) =>
      Navigator.of(tester.element(find.byType(pantalla)));

  Future<void> pestana(String etiqueta) async {
    await tester.tap(find.descendant(
      of: find.byType(EscalaLimitada),
      matching: find.text(etiqueta),
    ));
    await asentar();
  }

  await asentar();
  final raiz = tester.element(find.byType(RootScreen));
  final l10n = L10n.of(raiz);
  // ignore: avoid_print
  print('${d.nombre}: letra × ${EscalaTableta.factorDe(raiz).toStringAsFixed(2)}');

  await capturar('01_inicio');

  for (final (i, poema) in delDia.indexed) {
    solicitudes.pedir(poema.id);
    await asentar();
    await capturar('0${i + 2}_poema');
    navegadorDe(PoemaScreen).pop();
    await asentar();
  }

  await pestana(l10n.tabIndice);
  await capturar('04_indice');

  navegadorDe(IndiceScreen)
      .push(rutaFundido((_) => AutorScreen(autor: guion.autor)));
  await asentar();
  await capturar('05_autor');
  navegadorDe(AutorScreen).pop();

  await pestana(l10n.tabBuscar);
  await tester.enterText(
    find.descendant(
        of: find.byType(BusquedaScreen), matching: find.byType(TextField)),
    guion.busqueda,
  );
  // Past the search's debounce; then drop the caret.
  await tester.pump(const Duration(milliseconds: 400));
  FocusManager.instance.primaryFocus?.unfocus();
  await capturar('06_busqueda');

  await pestana(l10n.tabFavoritos);
  await capturar('07_favoritos');

  await pestana(l10n.tabInicio);
  navegadorDe(InicioScreen).push(rutaFundido((_) => const AjustesScreen()));
  await capturar('08_ajustes');
}

/// Home's poems of the day, fixed to the ones the screenshots should show
/// rather than whatever the date picks.
class _DelDiaFijo extends PoemaDelDiaProvider {
  final List<Poema> fijos;

  _DelDiaFijo({
    required super.anthology,
    required super.prefs,
    required super.ajustes,
    required this.fijos,
  });

  @override
  SeleccionDiaria get seleccion {
    final hoy = DateTime.now();
    return SeleccionDiaria(DateTime(hoy.year, hoy.month, hoy.day), fijos);
  }
}

String _sinTexto(Poema _) => '';

/// Notifications that are always allowed and never scheduled.
class _AgendaQuieta implements AgendaAvisos {
  @override
  Future<bool> permisoConcedido() async => true;

  @override
  Future<EstadoPermisoAviso> pedirPermiso() async =>
      EstadoPermisoAviso.concedido;

  @override
  Future<void> reprogramar({
    required List<Poema> pool,
    required TimeOfDay hora,
    required TextosAviso textos,
    List<String> autoresRecientes = const [],
  }) async {}

  @override
  Future<void> cancelarTodo() async {}
}

/// No store: the tip jar hides itself, as it does until products exist.
class _TiendaCerrada implements TiendaPropinas {
  @override
  Future<bool> iniciar() async => false;

  @override
  Future<List<Propina>> consultar(Set<String> ids) async => const [];

  @override
  Future<void> comprar(Propina propina) async {}

  @override
  Stream<ResultadoPropina> get resultados => const Stream.empty();

  @override
  Future<void> cerrar() async {}
}

/// `flutter test` doesn't load the fonts a pubspec declares (text would
/// render as blocks), so they are read from the app's `pubspec.yaml` and
/// loaded by hand, plus Material's icon font from the Flutter SDK. Weight
/// and slant come from each file's own metadata.
///
/// The few widgets that keep the platform's own font (a [TextButton]'s
/// label) get [cuerpo], the app's body face: the iPhone's SF Pro isn't
/// available here.
Future<void> cargarFuentes(String cuerpo) async {
  final familias = <String, List<String>>{};
  String? actual;
  for (final linea in File('pubspec.yaml').readAsLinesSync()) {
    final familia = RegExp(r'^\s*-\s*family:\s*(\S+)').firstMatch(linea);
    if (familia != null) {
      actual = familia.group(1)!;
      familias[actual] = [];
      continue;
    }
    final archivo = RegExp(r'^\s*-\s*asset:\s*(\S+)').firstMatch(linea);
    if (archivo != null && actual != null) {
      familias[actual]!.add(archivo.group(1)!);
    }
  }

  for (final sistema in const [
    'CupertinoSystemText',
    'CupertinoSystemDisplay',
    'Roboto',
  ]) {
    familias[sistema] = [...?familias[cuerpo]];
  }

  final ejecutable = Platform.resolvedExecutable;
  final cache = ejecutable.indexOf('/bin/cache/');
  if (cache >= 0) {
    familias['MaterialIcons'] = [
      '${ejecutable.substring(0, cache)}'
          '/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ];
  }

  for (final MapEntry(key: familia, value: archivos) in familias.entries) {
    final cargador = FontLoader(familia);
    for (final ruta in archivos) {
      cargador.addFont(
          Future.value(ByteData.sublistView(File(ruta).readAsBytesSync())));
    }
    await cargador.load();
  }
}
