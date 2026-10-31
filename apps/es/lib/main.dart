import 'package:flutter/material.dart';
import 'package:poemario_core/bootstrap.dart';
import 'package:poemario_core/config/app_config.dart';
import 'package:poemario_core/screens/root_screen.dart';
import 'package:poemario_core/domain/orden_titulos.dart';
import 'package:poemario_core/theme/poema_colors.dart';
import 'package:poemario_core/theme/poema_theme.dart';

/// Spanish anthology. Everything specific to this published app lives here
/// and in `pubspec.yaml`. No file in `poemario_core` mentions it.
const configApp = AppConfig(
  locale: Locale('es'),
  nombreApp: 'Antología Poética',
  firmaCompartir: 'Poemario · Siglo de Oro',
  nombreTienda: 'Poemario - Siglo de Oro',
  // The longest verse of any sonnet here: Gutierre de Cetina, LXXIX.
  versoMasLargo: 'muero.» «¡Ya sé lo que es!» «¿Qué es, pues?» «Ausencia.»',
  assetPoemas: 'assets/poemas.json',
  assetOrnamento: 'assets/icon/gafas_bigote_transparente.png',
  assetOrnamentoClaro: 'assets/icon/gafas_bigote_transparente_claro.png',
  // The "- XIV -" numbering convention only makes sense for this corpus.
  ordenTitulos: EstrategiaOrden.romanosPrimero,
  fuentes: FontPair(display: 'PlayfairDisplay', body: 'Lato'),
  coloresClaro: PoemaColors.claroPorDefecto,
  coloresOscuro: PoemaColors.oscuroPorDefecto,
  // Tip jar off for now: with no ids the app never queries the store and
  // Settings shows no tips section. To turn it on, uncomment; the ids must
  // match the consumable products in Play Console and App Store Connect.
  // idsPropinas: {'propina_cafe_1', 'propina_cafe_3', 'propina_cafe_5'},
  urlPrivacidad: 'https://mastercobos.github.io/website/privacidad.html',
);

void main() {
  bootstrap(configApp, home: (_) => const RootScreen());
}
