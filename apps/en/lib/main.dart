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
      assetPoemas: 'assets/poemas.json',
      // No roman-numeral convention in this corpus: plain alphabetical.
      ordenTitulos: EstrategiaOrden.alfabetico,
      fuentes: FontPair(display: 'EBGaramond', body: 'SourceSans3'),
      coloresClaro: PoemaColors(
        oro: Color(0xFF3F5B8B),
        oroClaro: Color(0xFF8FA8CC),
        sepia: Color(0xFF1F2A3C),
        fondo: Color(0xFFF4F6FA),
        tarjeta: Colors.white,
        texto: Color(0xFF1F2A3C),
        textoSuave: Color(0xFF63708A),
        sobreSepia: Colors.white,
        fondoCompartir: Color(0xFFEDF1F8),
        sombra: Color(0x141F2A3C),
      ),
      coloresOscuro: PoemaColors(
        oro: Color(0xFF7FA0D6),
        oroClaro: Color(0xFF9FBCE8),
        sepia: Color(0xFF0B0F17),
        fondo: Color(0xFF10141C),
        tarjeta: Color(0xFF1A2130),
        texto: Color(0xFFE3E9F4),
        textoSuave: Colors.white38,
        sobreSepia: Colors.white,
        fondoCompartir: Color(0xFF0B0F17),
        sombra: Color(0x4D000000),
      ),
      canalNotificaciones: 'daily_poem_en',
      horaNotificacionPorDefecto: TimeOfDay(hour: 8, minute: 0),
    ),
    home: (_) => const RootScreen(),
  );
}
