import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Estilos de texto cacheados — evita crear nuevos objetos TextStyle
/// en cada build(). GoogleFonts.x() es costoso si se llama miles de veces.
abstract final class AppTextStyles {
  // ── Playfair Display ──────────────────────────────────────────────────────
  static final appBarTitle = GoogleFonts.playfairDisplay(
    fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white,
  );
  static final appBarTitleSmall = GoogleFonts.playfairDisplay(
    fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white,
  );
  static final appBarTitleTiny = GoogleFonts.playfairDisplay(
    fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white,
  );
  static final autorCardLight = GoogleFonts.playfairDisplay(
    fontSize: 17, fontWeight: FontWeight.bold, color: const Color(0xFF3B2F2F),
  );
  static final autorCardDark = GoogleFonts.playfairDisplay(
    fontSize: 17, fontWeight: FontWeight.bold, color: const Color(0xFFF5E6C8),
  );
  static final avatarLetter = GoogleFonts.playfairDisplay(
    fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white,
  );
  static final poemaTitle28Light = GoogleFonts.playfairDisplay(
    fontSize: 28, fontWeight: FontWeight.bold,
    color: const Color(0xFF3B2F2F), height: 1.25,
  );
  static final poemaTitle28Dark = GoogleFonts.playfairDisplay(
    fontSize: 28, fontWeight: FontWeight.bold,
    color: const Color(0xFFF5E6C8), height: 1.25,
  );
  static final cardTitleWhite = GoogleFonts.playfairDisplay(
    fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white,
  );
  static final inicioDayTitle = GoogleFonts.playfairDisplay(
    fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF3B2F2F),
  );
  static final inicioDayTitleDark = GoogleFonts.playfairDisplay(
    fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFFF5E6C8),
  );

  // ── Lato ──────────────────────────────────────────────────────────────────
  static final labelDorado = GoogleFonts.lato(
    fontSize: 12, letterSpacing: 2.5, color: const Color(0xFFD4AF6A),
  );
  static final labelDoradoSmall = GoogleFonts.lato(
    fontSize: 10, letterSpacing: 2, color: const Color(0xFF8B6914),
  );
  static final autorItalicDorado = GoogleFonts.lato(
    fontSize: 13, fontStyle: FontStyle.italic, color: const Color(0xFFD4AF6A),
  );
  static final poemaCount = GoogleFonts.lato(
    fontSize: 12, color: const Color(0xFF8B6914),
  );
  static final searchHint = GoogleFonts.lato(color: Colors.white38);
  static final searchText = GoogleFonts.lato(color: Colors.white);
  static final navLabelSelected = GoogleFonts.lato(
    fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFD4AF6A),
  );
  static final navLabelUnselected = GoogleFonts.lato(
    fontSize: 11, color: Colors.white54,
  );
  static final versoLight = GoogleFonts.lato(
    fontSize: 17, height: 2.05,
    color: const Color(0xFF3B2F2F), letterSpacing: 0.15,
  );
  static final versoDark = GoogleFonts.lato(
    fontSize: 17, height: 2.05,
    color: const Color(0xFFF5E6C8), letterSpacing: 0.15,
  );
}
