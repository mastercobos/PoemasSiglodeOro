import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/orden_titulos.dart';
import '../theme/poema_colors.dart';
import '../theme/poema_theme.dart';

/// Everything that differs between the published apps.
///
/// This is the contract of the white-label setup: if a value would change
/// between the Spanish and the English app, it belongs here. If it wouldn't,
/// it belongs in core. No file under `lib/screens` or `lib/widgets` should
/// contain a colour literal, a font name, an app name or a Spanish string.
///
/// Read it anywhere with `context.config`.
@immutable
class AppConfig {
  /// The app's only locale. Each published app ships exactly one, so the
  /// anthology's language and the UI language can never disagree.
  final Locale locale;

  /// Shown in the task switcher and as the home tab's title.
  final String nombreApp;

  /// Signature line printed at the foot of the shared image and plain-text
  /// share, e.g. "Poemario · Siglo de Oro".
  final String firmaCompartir;

  /// The app's name as the stores list it, e.g. "Poemario - Siglo de Oro".
  /// A shared card cut short tells the reader to find the rest under it.
  final String nombreTienda;

  /// The longest verse of any sonnet in this anthology. On a tablet the text
  /// grows until a whole sonnet no longer fits the reader's height or this
  /// verse its width (see EscalaTableta).
  final String versoMasLargo;

  /// Asset path of this app's anthology, declared in the app's own pubspec.
  final String assetPoemas;

  /// Asset path of the image drawn between the gold rules above and below a
  /// poem and on the share card — normally the app's own icon. Must be
  /// declared in the app's pubspec. Null falls back to a generic book glyph.
  final String? assetOrnamento;

  /// The ornament for light mode, when [assetOrnamento] is too pale to read
  /// on the light background. Null uses [assetOrnamento] in both modes.
  final String? assetOrnamentoClaro;

  final PoemaColors coloresClaro;
  final PoemaColors coloresOscuro;
  final FontPair fuentes;

  /// See [EstrategiaOrden].
  final EstrategiaOrden ordenTitulos;

  /// Namespace for `SharedPreferences` keys. Each app has its own sandbox, so
  /// this only matters if you ever merge two anthologies into one binary —
  /// but it costs nothing now and is painful to retrofit later.
  final String prefijoPreferencias;

  /// How verses are laid out. See [DisposicionVersos].
  final DisposicionVersos disposicionVersos;

  /// Store product ids of the tip-jar amounts (consumables, created in Play
  /// Console and App Store Connect). Empty means the app has no tip jar.
  /// Ids the store doesn't know are skipped, so listing one before it exists
  /// is harmless.
  final Set<String> idsPropinas;

  /// Where the anthology's texts come from, shown under Settings → Sources.
  /// Licences such as CC BY-SA require this credit to travel with the app,
  /// not only on the store page. Empty hides the entry.
  final List<CreditoFuente> creditos;

  const AppConfig({
    required this.locale,
    required this.nombreApp,
    required this.firmaCompartir,
    required this.nombreTienda,
    required this.versoMasLargo,
    required this.coloresClaro,
    required this.coloresOscuro,
    required this.fuentes,
    this.assetPoemas = 'assets/poemas.json',
    this.assetOrnamento,
    this.assetOrnamentoClaro,
    this.ordenTitulos = EstrategiaOrden.alfabetico,
    this.prefijoPreferencias = '',
    this.idsPropinas = const {},
    this.creditos = const [],
    this.disposicionVersos = DisposicionVersos.centrada,
  });

  /// Comparator derived from [ordenTitulos]. Built once per config rather than
  /// per list build.
  int Function(String, String) get compararTitulos =>
      comparadorDeTitulos(ordenTitulos);

  ThemeData get temaClaro => construirTema(
        colores: coloresClaro,
        fuentes: fuentes,
        brillo: Brightness.light,
      );

  ThemeData get temaOscuro => construirTema(
        colores: coloresOscuro,
        fuentes: fuentes,
        brillo: Brightness.dark,
      );

  String clave(String nombre) => '$prefijoPreferencias$nombre';

  /// The ornament for a theme of [brillo]: the reader and the share card,
  /// which follows the app's theme.
  String? ornamentoPara(Brightness brillo) => brillo == Brightness.light
      ? assetOrnamentoClaro ?? assetOrnamento
      : assetOrnamento;
}

/// One source of the anthology's texts, written in the app's language.
@immutable
class CreditoFuente {
  /// The source's name as its licence asks to be credited, e.g. "Laurel".
  final String nombre;

  /// What came from it, under which licence, and what was changed.
  final String descripcion;

  /// The source's address. Shown as selectable text, so it can be copied.
  final String? enlace;

  const CreditoFuente({
    required this.nombre,
    required this.descripcion,
    this.enlace,
  });
}

/// How the reader and the home cards lay out a poem's verses.
enum DisposicionVersos {
  /// Every line centred. A verse too long for the screen wraps and its rest
  /// is centred too, like a verse of its own. Fine where verses fit (the
  /// Spanish anthology's hendecasyllables).
  centrada,

  /// Each poem is set just small enough for its longest verse to fit the
  /// screen on one line, measured on each device, down to 80% of the normal
  /// size; past that its long verses wrap, a wrapped verse's lines set
  /// closer together than two verses. A stanza that is only a section mark
  /// ("II", "⁂") is drawn as a small heading. For long lines: alexandrines,
  /// English blank verse and ballad metre.
  ajustada,
}

extension AppConfigX on BuildContext {
  /// The app's configuration. Provided above [MaterialApp] and never changes,
  /// so `read` is correct and cheaper than `watch`.
  AppConfig get config => read<AppConfig>();
}
