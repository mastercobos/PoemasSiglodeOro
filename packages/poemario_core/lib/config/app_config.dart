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

  final PoemaColors coloresClaro;
  final PoemaColors coloresOscuro;
  final FontPair fuentes;

  /// See [EstrategiaOrden].
  final EstrategiaOrden ordenTitulos;

  /// Android notification channel id. Must be stable for the life of the app:
  /// changing it orphans the user's per-channel settings.
  final String canalNotificaciones;

  /// Default reminder time offered the first time the user enables
  /// notifications. They can change it afterwards.
  final TimeOfDay horaNotificacionPorDefecto;

  /// Namespace for `SharedPreferences` keys. Each app has its own sandbox, so
  /// this only matters if you ever merge two anthologies into one binary —
  /// but it costs nothing now and is painful to retrofit later.
  final String prefijoPreferencias;

  const AppConfig({
    required this.locale,
    required this.nombreApp,
    required this.firmaCompartir,
    required this.coloresClaro,
    required this.coloresOscuro,
    required this.fuentes,
    this.assetPoemas = 'assets/poemas.json',
    this.ordenTitulos = EstrategiaOrden.alfabetico,
    this.canalNotificaciones = 'poema_diario',
    this.horaNotificacionPorDefecto = const TimeOfDay(hour: 9, minute: 0),
    this.prefijoPreferencias = '',
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

extension AppConfigX on BuildContext {
  /// The app's configuration. Provided above [MaterialApp] and never changes,
  /// so `read` is correct and cheaper than `watch`.
  AppConfig get config => read<AppConfig>();
}
