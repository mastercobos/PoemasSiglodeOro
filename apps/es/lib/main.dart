import 'package:flutter/material.dart';
import 'package:poemario_core/bootstrap.dart';
import 'package:poemario_core/config/app_config.dart';
import 'package:poemario_core/screens/root_screen.dart';
import 'package:poemario_core/domain/orden_titulos.dart';
import 'package:poemario_core/theme/poema_colors.dart';
import 'package:poemario_core/theme/poema_theme.dart';

/// Spanish anthology. Everything specific to this published app lives here
/// and in `pubspec.yaml`. No file in `poemario_core` mentions it.
void main() {
  bootstrap(
    const AppConfig(
      locale: Locale('es'),
      nombreApp: 'Antología Poética',
      firmaCompartir: 'Poemario · Siglo de Oro',
      assetPoemas: 'assets/poemas.json',
      // The "- XIV -" numbering convention only makes sense for this corpus.
      ordenTitulos: EstrategiaOrden.romanosPrimero,
      fuentes: FontPair(display: 'PlayfairDisplay', body: 'Lato'),
      coloresClaro: PoemaColors.claroPorDefecto,
      coloresOscuro: PoemaColors.oscuroPorDefecto,
      canalNotificaciones: 'poema_diario_es',
      horaNotificacionPorDefecto: TimeOfDay(hour: 9, minute: 0),
    ),
    home: (_) => const RootScreen(),
  );
}
