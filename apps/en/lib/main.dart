import 'package:flutter/material.dart';
import 'package:poemario_core/bootstrap.dart';
import 'package:poemario_core/config/app_config.dart';
import 'package:poemario_core/screens/root_screen.dart';
import 'package:poemario_core/domain/orden_titulos.dart';
import 'package:poemario_core/theme/poema_colors.dart';
import 'package:poemario_core/theme/poema_theme.dart';

/// English anthology: different poems, palette, fonts, icon and bundle id.
///
/// Note that this file is the *entire* difference in code between the two
/// published apps. That is the test of whether the white-label split worked:
/// if adding a language ever needs an edit inside `poemario_core`, something
/// app-specific has leaked into core and belongs in [AppConfig] instead.
void main() {
  bootstrap(
    const AppConfig(
      locale: Locale('en'),
      nombreApp: 'English Verse',
      firmaCompartir: 'English Verse · A daily anthology',
      assetPoemas: 'assets/poemas/indice.json',
      assetOrnamento: 'assets/icon/quill_icon.png',
      // Sequences are numbered inline ("Sonnet I", "Sonnets from the
      // Portuguese, I") rather than with the Spanish corpus's leading
      // "- N -", so romanosPrimero doesn't apply — but the numerals still
      // need to sort as numbers, not as text ("Sonnet IX" before "Sonnet V"
      // is wrong).
      ordenTitulos: EstrategiaOrden.numeralesNaturales,
      // Long lines (alexandrines, blank verse) wrap on a phone: continue them
      // indented, measured per device, rather than centring the rest.
      disposicionVersos: DisposicionVersos.sangria,
      fuentes: FontPair(display: 'EBGaramond', body: 'SourceSans3'),
      coloresClaro: PoemaColors(
        oro: Color(0xFF8C2F45),
        oroClaro: Color(0xFFC98A9A),
        sepia: Color(0xFF2A1B1F),
        fondo: Color(0xFFFAF5F4),
        tarjeta: Colors.white,
        texto: Color(0xFF2A1B1F),
        textoSuave: Color(0xFF7A6068),
        sobreSepia: Colors.white,
        fondoCompartir: Color(0xFFF3E8E6),
        sombra: Color(0x142A1B1F),
      ),
      coloresOscuro: PoemaColors(
        oro: Color(0xFFE08AA0),
        oroClaro: Color(0xFFEBA9BA),
        sepia: Color(0xFF120A0D),
        fondo: Color(0xFF1A1114),
        tarjeta: Color(0xFF271A1F),
        texto: Color(0xFFF1E6E8),
        textoSuave: Color(0xFFA8939A),
        sobreSepia: Colors.white,
        fondoCompartir: Color(0xFF120A0D),
        sombra: Color(0x4D000000),
      ),
    ),
    home: (_) => const RootScreen(),
  );
}
