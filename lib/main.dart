import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'models/poema.dart';
import 'providers/favoritos_provider.dart';
import 'providers/ajustes_provider.dart';
import 'providers/tema_provider.dart';
import 'screens/root_screen.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final poemas = await _cargarPoemas();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FavoritosProvider(poemas)),
        ChangeNotifierProvider(create: (_) => AjustesProvider(poemas.map((p) => p.autor).toSet().toList()..sort())),
        ChangeNotifierProvider(create: (_) => TemaProvider()),
      ],
      child: MiApp(poemas: poemas),
    ),
  );
}

Future<List<Poema>> _cargarPoemas() async {
  final raw = await rootBundle.loadString('assets/poemas.json');
  final lista = jsonDecode(raw) as List;
  return lista
      .asMap()
      .entries
      .map((e) => Poema.fromJson(e.value as Map<String, dynamic>, index: e.key))
      .toList();
}

class MiApp extends StatelessWidget {
  final List<Poema> poemas;
  const MiApp({super.key, required this.poemas});

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF8B6914),
      brightness: brightness,
    ).copyWith(
      primary: const Color(0xFF8B6914),
      onPrimary: Colors.white,
      secondary: const Color(0xFFD4AF6A),
      surface: isDark ? const Color(0xFF1A1210) : const Color(0xFFFDF6EC),
      onSurface: isDark ? const Color(0xFFF5E6C8) : const Color(0xFF3B2F2F),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      splashColor: const Color(0x228B6914),
      highlightColor: const Color(0x118B6914),
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF1A1210) : const Color(0xFFFDF6EC),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark
            ? const Color(0xFF0F0A08)
            : const Color(0xFF3B2F2F),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.playfairDisplay(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: isDark ? 4 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isDark
                ? const Color(0xFF8B6914).withValues(alpha: 0.5)
                : const Color(0xFFD4AF6A),
            width: 0.8,
          ),
        ),
        color: isDark ? const Color(0xFF2A1F18) : Colors.white,
      ),
      dividerTheme: DividerThemeData(
        color: isDark
            ? const Color(0xFF8B6914).withValues(alpha: 0.4)
            : const Color(0xFFD4AF6A),
        thickness: 0.8,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? const Color(0xFF2A1F18)
            : const Color(0xFF3B2F2F),
        contentTextStyle: GoogleFonts.lato(color: Colors.white),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TemaProvider>(
      builder: (context, tema, _) {
        return MaterialApp(
          title: 'Antología Poética',
          debugShowCheckedModeBanner: false,
          themeMode: tema.modo,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          home: RootScreen(poemas: poemas),
        );
      },
    );
  }
}
