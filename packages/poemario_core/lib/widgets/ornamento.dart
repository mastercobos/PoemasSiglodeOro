import 'package:flutter/material.dart';

import '../theme/poema_colors.dart';

/// Rule — book glyph — rule. Used above and below the poem, and in the share
/// image, where it used to be hand-drawn on a canvas as a rectangle with a
/// line through it because the two implementations had drifted apart.
class Ornamento extends StatelessWidget {
  final double anchoLinea;
  final double tamanoIcono;

  const Ornamento({super.key, this.anchoLinea = 44, this.tamanoIcono = 18});

  @override
  Widget build(BuildContext context) {
    final oro = context.colores.oro;
    return ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(width: anchoLinea, height: 1, color: oro),
          SizedBox(width: tamanoIcono * 0.55),
          Icon(Icons.auto_stories, color: oro, size: tamanoIcono),
          SizedBox(width: tamanoIcono * 0.55),
          Container(width: anchoLinea, height: 1, color: oro),
        ],
      ),
    );
  }
}

/// Short gold rule under a heading.
class Filete extends StatelessWidget {
  final double ancho;
  const Filete({super.key, this.ancho = 56});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: ancho,
        height: 2,
        decoration: BoxDecoration(
          color: context.colores.oro,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}
