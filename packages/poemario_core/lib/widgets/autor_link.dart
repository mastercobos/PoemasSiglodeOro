import 'package:flutter/material.dart';

import '../screens/autor_screen.dart';
import '../theme/poema_colors.dart';
import '../theme/poema_theme.dart';
import '../utils/navegacion.dart';

/// Tappable author name.
///
/// The original filtered the whole anthology on every build to find the
/// author's poems, and used a bare [GestureDetector] — no ink response, no
/// semantics, and a tap target thinner than the 48dp minimum.
class AutorLink extends StatelessWidget {
  final String autor;
  final TextStyle? estilo;

  const AutorLink({super.key, required this.autor, this.estilo});

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Semantics(
      link: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => Navigator.of(context).push(
          rutaFundido((_) => AutorScreen(autor: autor)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Text(
            autor,
            style: estilo ??
                context.tipos.autorCursiva.copyWith(
                  fontSize: 14,
                  color: c.oro,
                  letterSpacing: 0.6,
                  decoration: TextDecoration.underline,
                  decorationColor: c.oro,
                ),
          ),
        ),
      ),
    );
  }
}
