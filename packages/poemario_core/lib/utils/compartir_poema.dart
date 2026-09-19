import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../config/app_config.dart';
import '../data/poema.dart';
import '../theme/poema_colors.dart';
import '../theme/poema_theme.dart';
import '../widgets/ornamento.dart';

/// Builds and shares the poem card.
///
/// The original had *two* implementations: a `_ShareCard` widget that was
/// never instantiated, and a hand-rolled `Canvas` routine that duplicated the
/// entire layout as measurement arithmetic which had to be kept in sync with
/// the draw pass by hand. They had already drifted — the canvas version drew
/// the book glyph as "a simple book-like rectangle as icon placeholder".
///
/// This keeps the widget as the single source of truth and captures it with a
/// [RepaintBoundary] mounted off-screen in an [Overlay], so layout,
/// line-breaking and font fallback are the framework's job rather than ours.
class CompartirPoema {
  static const _ancho = 800.0;
  static const _pixelRatio = 3.0;

  /// Shares a PNG of the poem, falling back to plain text if the capture
  /// fails for any reason.
  ///
  /// [origen] anchors the iPad share popover; pass the share button's rect.
  static Future<void> compartir({
    required BuildContext context,
    required Poema poema,
    required Rect origen,
    required String mensajeError,
  }) async {
    // Resolve everything that needs a BuildContext *before* the first await:
    // the context may be gone by the time we come back.
    final config = context.config;
    final tema = Theme.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final overlay = Overlay.of(context, rootOverlay: true);

    final textoPlano = _textoPlano(poema, config.firmaCompartir);

    try {
      final bytes = await _capturar(
        overlay: overlay,
        tema: tema,
        poema: poema,
        firma: config.firmaCompartir,
      );

      if (bytes != null && bytes.isNotEmpty) {
        final dir = await getTemporaryDirectory();
        final archivo = File('${dir.path}/${_nombreArchivo(poema)}.png');
        await archivo.writeAsBytes(bytes);
        await SharePlus.instance.share(ShareParams(
          files: [XFile(archivo.path, mimeType: 'image/png')],
          subject: poema.etiqueta,
          text: '${poema.etiqueta} — ${poema.autor}',
          sharePositionOrigin: origen,
        ));
        return;
      }

      await SharePlus.instance.share(ShareParams(
        text: textoPlano,
        subject: poema.etiqueta,
        sharePositionOrigin: origen,
      ));
    } catch (e) {
      debugPrint('CompartirPoema: $e');
      try {
        await SharePlus.instance.share(ShareParams(
          text: textoPlano,
          subject: poema.etiqueta,
          sharePositionOrigin: origen,
        ));
      } catch (e2) {
        debugPrint('CompartirPoema (texto plano): $e2');
        messenger.showSnackBar(SnackBar(content: Text(mensajeError)));
      }
    }
  }

  /// Mounts the card off-screen, waits for it to lay out and paint, then reads
  /// the boundary's pixels.
  static Future<Uint8List?> _capturar({
    required OverlayState overlay,
    required ThemeData tema,
    required Poema poema,
    required String firma,
  }) async {
    final clave = GlobalKey();
    final entrada = OverlayEntry(
      builder: (_) => Positioned(
        // Far off-screen: laid out and painted, never visible.
        left: -_ancho * 2,
        top: 0,
        child: Theme(
          data: tema,
          child: MediaQuery(
            // The shared image must look the same regardless of the reader's
            // system font size.
            data: const MediaQueryData(textScaler: TextScaler.noScaling),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: RepaintBoundary(
                key: clave,
                child: Material(
                  type: MaterialType.transparency,
                  child: TarjetaCompartir(poema: poema, firma: firma),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entrada);
    try {
      // Two frames: one to lay out, one to be sure it has painted.
      await _esperarFrame();
      await _esperarFrame();

      final boundary =
          clave.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null || boundary.debugNeedsPaint) return null;

      final imagen = await boundary.toImage(pixelRatio: _pixelRatio);
      final datos = await imagen.toByteData(format: ui.ImageByteFormat.png);
      imagen.dispose();
      return datos?.buffer.asUint8List();
    } finally {
      entrada.remove();
    }
  }

  static Future<void> _esperarFrame() {
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) => completer.complete());
    WidgetsBinding.instance.scheduleFrame();
    return completer.future;
  }

  static String _textoPlano(Poema poema, String firma) =>
      '${poema.etiqueta}\n${poema.autor}\n\n'
      '${poema.texto.trim()}\n\n— $firma';

  static String _nombreArchivo(Poema poema) {
    final autor = _limpiar(poema.autor);
    final titulo =
        _limpiar(poema.etiqueta.trim().split(RegExp(r'\s+')).take(4).join(' '));
    return '${autor}_${titulo.isEmpty ? 'poema' : titulo}';
  }

  static String _limpiar(String texto) => texto
      .toLowerCase()
      .replaceAll(RegExp(r'[áàäâã]'), 'a')
      .replaceAll(RegExp(r'[éèëê]'), 'e')
      .replaceAll(RegExp(r'[íìïî]'), 'i')
      .replaceAll(RegExp(r'[óòöôõ]'), 'o')
      .replaceAll(RegExp(r'[úùüû]'), 'u')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp(r'[^a-z0-9]'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}

/// The card that becomes the shared PNG. Fixed 800 px wide, height driven by
/// the poem, stanza breaks taken from the data.
class TarjetaCompartir extends StatelessWidget {
  final Poema poema;
  final String firma;

  const TarjetaCompartir({super.key, required this.poema, required this.firma});

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final t = context.tipos;

    final estiloVerso = t.verso.copyWith(
      fontSize: 22,
      height: 2.0,
      color: c.texto,
      letterSpacing: 0.2,
    );

    return Container(
      width: CompartirPoema._ancho,
      color: c.fondoCompartir,
      padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 64),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Ornamento(anchoLinea: 60, tamanoIcono: 20),
          const SizedBox(height: 40),
          Text(
            poema.etiqueta,
            textAlign: TextAlign.center,
            style: t.tituloPoema.copyWith(
                fontSize: 36, height: 1.3, color: c.texto),
          ),
          const SizedBox(height: 8),
          Text(
            poema.autor,
            textAlign: TextAlign.center,
            style: t.autorCursiva.copyWith(
                fontSize: 22, color: c.oro, letterSpacing: 0.5),
          ),
          const SizedBox(height: 32),
          const Filete(ancho: 60),
          const SizedBox(height: 36),
          for (var i = 0; i < poema.estrofas.length; i++) ...[
            if (i > 0) const SizedBox(height: 18),
            for (final verso in poema.estrofas[i])
              Text(verso, textAlign: TextAlign.center, style: estiloVerso),
          ],
          const SizedBox(height: 40),
          const Ornamento(anchoLinea: 60, tamanoIcono: 20),
          const SizedBox(height: 28),
          Text(
            firma,
            style: t.cuerpoPequeno
                .copyWith(fontSize: 18, color: c.oro.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }
}
