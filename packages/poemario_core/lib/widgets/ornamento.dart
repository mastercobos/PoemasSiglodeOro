import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../theme/poema_colors.dart';

/// Rule — emblem — rule. Used above and below the poem, and in the share
/// image, where it used to be hand-drawn on a canvas as a rectangle with a
/// line through it because the two implementations had drifted apart.
///
/// The emblem is the app's own icon when [AppConfig.assetOrnamento] is set,
/// otherwise a generic book glyph.
class Ornamento extends StatelessWidget {
  final double anchoLinea;
  final double tamanoIcono;

  static const _escalaEmblema = 1.7;

  const Ornamento({super.key, this.anchoLinea = 44, this.tamanoIcono = 18});

  @override
  Widget build(BuildContext context) {
    final oro = context.colores.oro;
    final asset = context.config.assetOrnamento;
    final glifo = Icon(Icons.auto_stories, color: oro, size: tamanoIcono);
    return ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(width: anchoLinea, height: 1, color: oro),
          SizedBox(width: tamanoIcono * 0.55),
          if (asset == null)
            glifo
          else
            _Emblema(
              asset: asset,
              // A detailed icon needs more room than a one-colour glyph to
              // stay legible.
              lado: tamanoIcono * _escalaEmblema,
              alternativa: glifo,
            ),
          SizedBox(width: tamanoIcono * 0.55),
          Container(width: anchoLinea, height: 1, color: oro),
        ],
      ),
    );
  }
}

/// The app icon as a small rounded badge.
class _Emblema extends StatelessWidget {
  final String asset;
  final double lado;
  final Widget alternativa;

  const _Emblema({
    required this.asset,
    required this.lado,
    required this.alternativa,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(lado * 0.22),
      child: Image(
        // Same provider [CompartirPoema] pre-caches, so the share capture
        // finds it decoded.
        image: AssetImage(asset),
        width: lado,
        height: lado,
        filterQuality: FilterQuality.medium,
        // A missing asset should cost the ornament, not the poem screen.
        errorBuilder: (_, __, ___) => alternativa,
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
