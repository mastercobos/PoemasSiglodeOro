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

  /// Asset path of this app's anthology, declared in the app's own pubspec.
  final String assetPoemas;

  /// Asset path of the image drawn between the gold rules above and below a
  /// poem and on the share card — normally the app's own icon. Must be
  /// declared in the app's pubspec. Null falls back to a generic book glyph.
  final String? assetOrnamento;

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

  const AppConfig({
    required this.locale,
    required this.nombreApp,
    required this.firmaCompartir,
    required this.coloresClaro,
    required this.coloresOscuro,
    required this.fuentes,
    this.assetPoemas = 'assets/poemas.json',
    this.assetOrnamento,
    this.ordenTitulos = EstrategiaOrden.alfabetico,
    this.prefijoPreferencias = '',
    this.idsPropinas = const {},
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
}

/// How the reader and the home cards lay out a poem's verses.
enum DisposicionVersos {
  /// Every line centred. A verse too long for the screen wraps and its rest
  /// is centred too, like a verse of its own. Fine where verses fit (the
  /// Spanish anthology's hendecasyllables).
  centrada,

  /// A centred block of left-aligned verses; a verse too long for the screen
  /// continues on indented lines, measured on each device. A stanza that is
  /// only a section mark ("II", "⁂") is drawn as a small heading. For long
  /// lines: alexandrines, English blank verse and ballad metre.
  sangria,
}

extension AppConfigX on BuildContext {
  /// The app's configuration. Provided above [MaterialApp] and never changes,
  /// so `read` is correct and cheaper than `watch`.
  AppConfig get config => read<AppConfig>();
}
