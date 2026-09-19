import 'package:flutter/material.dart';

import 'poema_colors.dart';

/// The two font families an app uses.
///
/// Fonts are **bundled**, not fetched at runtime. Declare them in the app's
/// own `pubspec.yaml` under `flutter: fonts:` and pass the family names here.
/// Families declared by the app package are resolvable from core by name,
/// so no `package:` prefix is needed.
///
/// This replaces `google_fonts`, which downloaded Playfair and Lato over the
/// network on first launch — wrong for an offline anthology, and the reason
/// the app could start up in Roboto on a plane.
@immutable
class FontPair {
  /// Serif face for titles, author names and poem titles.
  final String display;

  /// Sans face for body copy, verses and UI chrome.
  final String body;

  const FontPair({required this.display, required this.body});
}

/// Named text roles, so screens ask for a *role* rather than a size.
///
/// Colour deliberately lives in [PoemaColors], not here: a style that bakes in
/// its colour needs a light and a dark twin, which is what forced the old
/// `autorCardLight` / `autorCardDark` pairs. Apply colour at the call site:
///
///     Text(autor, style: context.tipos.autorTarjeta.copyWith(color: c.texto))
@immutable
class PoemaTextStyles {
  final TextStyle appBarTitulo;
  final TextStyle appBarTituloPequeno;
  final TextStyle tituloPoema;
  final TextStyle tituloTarjeta;
  final TextStyle autorTarjeta;
  final TextStyle avatarInicial;
  final TextStyle verso;
  final TextStyle autorCursiva;
  final TextStyle etiquetaEspaciada;
  final TextStyle cuerpo;
  final TextStyle cuerpoPequeno;
  final TextStyle navLabel;

  const PoemaTextStyles({
    required this.appBarTitulo,
    required this.appBarTituloPequeno,
    required this.tituloPoema,
    required this.tituloTarjeta,
    required this.autorTarjeta,
    required this.avatarInicial,
    required this.verso,
    required this.autorCursiva,
    required this.etiquetaEspaciada,
    required this.cuerpo,
    required this.cuerpoPequeno,
    required this.navLabel,
  });

  /// Builds every role from a [FontPair]. Because these are plain [TextStyle]
  /// objects created once per theme rather than per `build()`, this keeps the
  /// caching benefit the old `AppTextStyles` had, without the baked-in colours.
  factory PoemaTextStyles.from(FontPair fuentes) {
    final display = fuentes.display;
    final body = fuentes.body;
    return PoemaTextStyles(
      appBarTitulo: TextStyle(
          fontFamily: display, fontSize: 22, fontWeight: FontWeight.bold),
      appBarTituloPequeno: TextStyle(
          fontFamily: display, fontSize: 17, fontWeight: FontWeight.bold),
      tituloPoema: TextStyle(
          fontFamily: display,
          fontSize: 28,
          fontWeight: FontWeight.bold,
          height: 1.25),
      tituloTarjeta: TextStyle(
          fontFamily: display, fontSize: 18, fontWeight: FontWeight.bold),
      autorTarjeta: TextStyle(
          fontFamily: display, fontSize: 17, fontWeight: FontWeight.bold),
      avatarInicial: TextStyle(
          fontFamily: display, fontSize: 20, fontWeight: FontWeight.bold),
      verso: TextStyle(
          fontFamily: body, fontSize: 17, height: 2.05, letterSpacing: 0.15),
      autorCursiva: TextStyle(
          fontFamily: body, fontSize: 13, fontStyle: FontStyle.italic),
      etiquetaEspaciada:
          TextStyle(fontFamily: body, fontSize: 12, letterSpacing: 2.5),
      cuerpo: TextStyle(fontFamily: body, fontSize: 15),
      cuerpoPequeno: TextStyle(fontFamily: body, fontSize: 12),
      navLabel:
          TextStyle(fontFamily: body, fontSize: 10, fontWeight: FontWeight.w600),
    );
  }
}

/// Second [ThemeExtension], so text roles travel with the theme exactly the
/// way colours do.
@immutable
class PoemaTypography extends ThemeExtension<PoemaTypography> {
  final PoemaTextStyles estilos;
  const PoemaTypography(this.estilos);

  @override
  PoemaTypography copyWith({PoemaTextStyles? estilos}) =>
      PoemaTypography(estilos ?? this.estilos);

  /// Text roles don't interpolate — snapping is correct here.
  @override
  PoemaTypography lerp(ThemeExtension<PoemaTypography>? other, double t) =>
      t < 0.5 ? this : (other is PoemaTypography ? other : this);
}

extension PoemaTypographyX on BuildContext {
  PoemaTextStyles get tipos =>
      Theme.of(this).extension<PoemaTypography>()!.estilos;
}

/// Assembles a [ThemeData] from an app's palette and fonts.
///
/// Everything a widget might otherwise hardcode is registered here, so most
/// screens can drop their `final isDark = ...` line entirely.
ThemeData construirTema({
  required PoemaColors colores,
  required FontPair fuentes,
  required Brightness brillo,
}) {
  final tipos = PoemaTextStyles.from(fuentes);

  final colorScheme = ColorScheme.fromSeed(
    seedColor: colores.oro,
    brightness: brillo,
  ).copyWith(
    primary: colores.oro,
    onPrimary: colores.sobreSepia,
    secondary: colores.oroClaro,
    surface: colores.fondo,
    onSurface: colores.texto,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colores.fondo,
    splashColor: colores.oro.withValues(alpha: 0.13),
    highlightColor: colores.oro.withValues(alpha: 0.07),
    extensions: [PoemaTypography(tipos), colores],
    appBarTheme: AppBarTheme(
      backgroundColor: colores.sepia,
      foregroundColor: colores.sobreSepia,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: tipos.appBarTitulo.copyWith(color: colores.sobreSepia),
    ),
    cardTheme: CardThemeData(
      elevation: brillo == Brightness.dark ? 4 : 2,
      color: colores.tarjeta,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colores.oroClaro, width: 0.8),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: colores.oroClaro.withValues(alpha: 0.4),
      thickness: 0.8,
    ),
    listTileTheme: ListTileThemeData(
      titleTextStyle: tipos.cuerpo.copyWith(color: colores.texto),
      subtitleTextStyle: tipos.cuerpoPequeno.copyWith(color: colores.textoSuave),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: colores.sepia,
      contentTextStyle: tipos.cuerpo.copyWith(color: colores.sobreSepia),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}
