import 'package:flutter/material.dart';

/// Every brand colour the UI needs, in one place, per brightness.
///
/// Widgets must never hardcode a hex value. Read colours with:
///
///     final c = context.colores;   // extension below
///     Container(color: c.sepia)
///
/// Each published app supplies its own light and dark instance through
/// [AppConfig], which is how the English app gets a different palette
/// without a single change in a screen file.
@immutable
class PoemaColors extends ThemeExtension<PoemaColors> {
  /// Deep accent. The old `0xFF8B6914`.
  final Color oro;

  /// Light accent, used for borders, dividers and the selected nav indicator.
  /// The old `0xFFD4AF6A`.
  final Color oroClaro;

  /// Dark chrome: app bars, card headers, avatar circles. The old `0xFF3B2F2F`.
  final Color sepia;

  /// Page background. The old `0xFFFDF6EC` / `0xFF1A1210`.
  final Color fondo;

  /// Card / list-row background. The old `Colors.white` / `0xFF2A1F18`.
  final Color tarjeta;

  /// Primary body text and verse colour.
  final Color texto;

  /// Secondary text: first-verse previews, poem counts, subtitles.
  final Color textoSuave;

  /// Text drawn on top of [sepia].
  final Color sobreSepia;

  /// Background of the generated share image. Usually a touch warmer
  /// than [fondo] so the PNG reads well on a social feed.
  final Color fondoCompartir;

  /// Shadow colour for cards, already carrying its alpha.
  final Color sombra;

  const PoemaColors({
    required this.oro,
    required this.oroClaro,
    required this.sepia,
    required this.fondo,
    required this.tarjeta,
    required this.texto,
    required this.textoSuave,
    required this.sobreSepia,
    required this.fondoCompartir,
    required this.sombra,
  });

  /// The palette shipped by the Spanish anthology, kept as a convenient
  /// starting point for new apps. Override what you need with [copyWith].
  static const claroPorDefecto = PoemaColors(
    oro: Color(0xFF8B6914),
    oroClaro: Color(0xFFD4AF6A),
    sepia: Color(0xFF3B2F2F),
    fondo: Color(0xFFFDF6EC),
    tarjeta: Colors.white,
    texto: Color(0xFF3B2F2F),
    textoSuave: Color(0xFF666666),
    sobreSepia: Colors.white,
    fondoCompartir: Color(0xFFFAF0E0),
    sombra: Color(0x17795548),
  );

  static const oscuroPorDefecto = PoemaColors(
    oro: Color(0xFF8B6914),
    oroClaro: Color(0xFFD4AF6A),
    sepia: Color(0xFF0F0A08),
    fondo: Color(0xFF1A1210),
    tarjeta: Color(0xFF2A1F18),
    texto: Color(0xFFF5E6C8),
    textoSuave: Colors.white38,
    sobreSepia: Colors.white,
    fondoCompartir: Color(0xFF1A0F0A),
    sombra: Color(0x4D000000),
  );

  @override
  PoemaColors copyWith({
    Color? oro,
    Color? oroClaro,
    Color? sepia,
    Color? fondo,
    Color? tarjeta,
    Color? texto,
    Color? textoSuave,
    Color? sobreSepia,
    Color? fondoCompartir,
    Color? sombra,
  }) {
    return PoemaColors(
      oro: oro ?? this.oro,
      oroClaro: oroClaro ?? this.oroClaro,
      sepia: sepia ?? this.sepia,
      fondo: fondo ?? this.fondo,
      tarjeta: tarjeta ?? this.tarjeta,
      texto: texto ?? this.texto,
      textoSuave: textoSuave ?? this.textoSuave,
      sobreSepia: sobreSepia ?? this.sobreSepia,
      fondoCompartir: fondoCompartir ?? this.fondoCompartir,
      sombra: sombra ?? this.sombra,
    );
  }

  /// Needed for the cross-fade when the user switches light/dark.
  @override
  PoemaColors lerp(ThemeExtension<PoemaColors>? other, double t) {
    if (other is! PoemaColors) return this;
    return PoemaColors(
      oro: Color.lerp(oro, other.oro, t)!,
      oroClaro: Color.lerp(oroClaro, other.oroClaro, t)!,
      sepia: Color.lerp(sepia, other.sepia, t)!,
      fondo: Color.lerp(fondo, other.fondo, t)!,
      tarjeta: Color.lerp(tarjeta, other.tarjeta, t)!,
      texto: Color.lerp(texto, other.texto, t)!,
      textoSuave: Color.lerp(textoSuave, other.textoSuave, t)!,
      sobreSepia: Color.lerp(sobreSepia, other.sobreSepia, t)!,
      fondoCompartir: Color.lerp(fondoCompartir, other.fondoCompartir, t)!,
      sombra: Color.lerp(sombra, other.sombra, t)!,
    );
  }
}

extension PoemaColorsX on BuildContext {
  /// Shorthand for the brand palette: `context.colores.oro`.
  PoemaColors get colores => Theme.of(this).extension<PoemaColors>()!;
}
