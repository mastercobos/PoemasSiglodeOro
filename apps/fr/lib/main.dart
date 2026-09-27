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
void main() {
  bootstrap(
    const AppConfig(
      locale: Locale('fr'),
      nombreApp: 'Poésie française',
      firmaCompartir: 'Poésie française · Une anthologie quotidienne',
      assetPoemas: 'assets/poemas/indice.json',
      assetOrnamento: 'assets/icon/quill_icon.png',
      // French sequences number inline too ("Les Regrets, XXXI", "Sonnet
      // IV"), as in the English corpus, so numerals sort by value.
      ordenTitulos: EstrategiaOrden.numeralesNaturales,
      // Long lines (alexandrines, blank verse) would wrap on a phone: each
      // poem is shrunk to fit its longest verse, measured per device.
      disposicionVersos: DisposicionVersos.ajustada,
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
    ),
    home: (_) => const RootScreen(),
  );
}
