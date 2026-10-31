import 'package:flutter/material.dart';
import 'package:poemario_core/bootstrap.dart';
import 'package:poemario_core/config/app_config.dart';
import 'package:poemario_core/screens/root_screen.dart';
import 'package:poemario_core/domain/orden_titulos.dart';
import 'package:poemario_core/theme/poema_colors.dart';
import 'package:poemario_core/theme/poema_theme.dart';

/// French anthology: different poems, palette, fonts, icon and bundle id.
///
/// Note that this file is the *entire* difference in code between the two
/// published apps. That is the test of whether the white-label split worked:
/// if adding a language ever needs an edit inside `poemario_core`, something
/// app-specific has leaked into core and belongs in [AppConfig] instead.
const configApp = AppConfig(
  locale: Locale('fr'),
  nombreApp: 'Poésie française',
  firmaCompartir: 'Poésie française · Une anthologie quotidienne',
  nombreTienda: 'Poésie française',
  // The longest verse of any sonnet here: Verhaeren, « Les porcs ».
  versoMasLargo:
      'Leurs yeux, leurs groins n’étaient que graisse lourde, et d’entre',
  assetPoemas: 'assets/poemas/indice.json',
  assetOrnamento: 'assets/icon/victorhugo_transparente.png',
  assetOrnamentoClaro: 'assets/icon/victorhugo_transparente_claro.png',
  // French sequences number inline too ("Les Regrets, XXXI", "Sonnet
  // IV"), as in the English corpus, so numerals sort by value.
  ordenTitulos: EstrategiaOrden.numeralesNaturales,
  // Long lines (alexandrines, blank verse) would wrap on a phone: each
  // poem is shrunk to fit its longest verse, measured per device.
  disposicionVersos: DisposicionVersos.ajustada,
  // CC BY-SA asks for this credit inside the app, beside the material.
  creditos: [
    CreditoFuente(
      nombre: 'Wikisource',
      descripcion: 'La plupart des poèmes proviennent de Wikisource en '
          'français, transcrits et relus par ses contributeurs, puis '
          'choisis et corrigés pour cette application. Textes sous '
          'licence CC BY-SA 4.0 (creativecommons.org/licenses/by-sa/4.0)'
          '\u00a0; nos textes adaptés sont partagés sous la même licence.',
      enlace: 'https://fr.wikisource.org',
    ),
    CreditoFuente(
      nombre: 'Projet Gutenberg',
      descripcion: 'Livres du domaine public, pour les poèmes dont '
          'Wikisource n\u2019a pas de version relue.',
      enlace: 'https://www.gutenberg.org',
    ),
  ],
  urlPrivacidad:
      'https://mastercobos.github.io/website/confidentialite-poesie-francaise.html',
  fuentes: FontPair(display: 'EBGaramond', body: 'SourceSans3'),
  coloresClaro: PoemaColors(
    oro: Color(0xFF2E4A7D),
    oroClaro: Color(0xFF8FA3C8),
    sepia: Color(0xFF1B2233),
    fondo: Color(0xFFF6F4EE),
    tarjeta: Colors.white,
    texto: Color(0xFF1B2233),
    textoSuave: Color(0xFF5F6878),
    sobreSepia: Colors.white,
    fondoCompartir: Color(0xFFECE8DD),
    sombra: Color(0x141B2233),
  ),
  coloresOscuro: PoemaColors(
    oro: Color(0xFF9DB4E0),
    oroClaro: Color(0xFFBFD0EE),
    sepia: Color(0xFF0B0F18),
    fondo: Color(0xFF11151F),
    tarjeta: Color(0xFF1B2130),
    texto: Color(0xFFE8EBF2),
    textoSuave: Color(0xFF939BAD),
    sobreSepia: Colors.white,
    fondoCompartir: Color(0xFF0B0F18),
    sombra: Color(0x4D000000),
  ),
);

void main() {
  bootstrap(configApp, home: (_) => const RootScreen());
}
