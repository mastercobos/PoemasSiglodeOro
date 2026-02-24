import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/poema.dart';
import '../screens/autor_screen.dart';

/// Texto del autor que al pulsarse navega a AutorScreen.
class AutorLink extends StatelessWidget {
  final String autor;
  final List<Poema> todosLosPoemas;
  final TextStyle? style;

  const AutorLink({
    super.key,
    required this.autor,
    required this.todosLosPoemas,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final poemasDelAutor =
        todosLosPoemas.where((p) => p.autor == autor).toList();

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) =>
              AutorScreen(autor: autor, poemas: poemasDelAutor, todosLosPoemas: todosLosPoemas),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 250),
        ),
      ),
      child: Text(
        autor,
        style: style ??
            GoogleFonts.lato(
              fontSize: 14,
              color: const Color(0xFF8B6914),
              fontStyle: FontStyle.italic,
              letterSpacing: 0.6,
              decoration: TextDecoration.underline,
              decorationColor: const Color(0xFF8B6914),
            ),
      ),
    );
  }
}
