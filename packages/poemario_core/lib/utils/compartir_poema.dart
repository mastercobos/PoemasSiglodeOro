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

  /// 4:5, Instagram's portrait feed ratio: the tallest a post can be before
  /// the feed crops it, and a comfortable fit for a sonnet.
  static const _alto = 1000.0;
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

    // The card is captured two frames after mounting, which is not enough for
    // an image to load and decode; without this the emblem would be missing
    // from the shared PNG. A failure just means the fallback glyph is used.
    // The card is drawn in [tema], so it shows that theme's ornament.
    final asset = config.ornamentoPara(tema.brightness);
    final precarga = asset == null
        ? Future<void>.value()
        : precacheImage(AssetImage(asset), context).catchError((_) {});

    final textoPlano = _textoPlano(poema, config.firmaCompartir);

    try {
      await precarga;
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

/// The card that becomes the shared PNG: a fixed 800×1000 (4:5) frame, so
/// every shared poem is the same shape whatever its length.
///
/// What goes in the frame:
///
/// * A poem of up to [_umbralVersos] verses — a sonnet, which is nearly the
///   whole Spanish anthology — is always shown whole. If a long title leaves
///   it short of room it is scaled down slightly rather than losing a verse.
/// * A longer poem fills the frame with as many verses as fit, then "…".
///   The cut falls at a stanza break when that keeps most of what would fit
///   (see [seleccionarVersos]), so the preview reads as a complete thought.
///
/// The preview is a feature, not a fallback: a card plus the app's own
/// signature is a better invitation to open the app than a giant image or a
/// wall of shared plain text would be.
class TarjetaCompartir extends StatelessWidget {
  final Poema poema;
  final String firma;

  const TarjetaCompartir({super.key, required this.poema, required this.firma});

  /// Poems this short are never cut, only scaled down if they must be.
  static const _umbralVersos = 14;

  static const _huecoEstrofa = 16.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final t = context.tipos;

    final estiloVerso = t.verso.copyWith(
      fontSize: 22,
      height: 1.65,
      color: c.texto,
      letterSpacing: 0.2,
    );

    return Container(
      width: CompartirPoema._ancho,
      height: CompartirPoema._alto,
      color: c.fondoCompartir,
      padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 56),
      child: Column(
        children: [
          const Ornamento(anchoLinea: 60, tamanoIcono: 20),
          const SizedBox(height: 32),
          Text(
            poema.etiqueta,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: t.tituloPoema
                .copyWith(fontSize: 36, height: 1.3, color: c.texto),
          ),
          const SizedBox(height: 8),
          Text(
            poema.autor,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.autorCursiva
                .copyWith(fontSize: 22, color: c.oro, letterSpacing: 0.5),
          ),
          const SizedBox(height: 28),
          const Filete(ancho: 60),
          const SizedBox(height: 32),
          Expanded(
            child: LayoutBuilder(
              builder: (context, restricciones) => _versos(
                context,
                restricciones,
                estiloVerso,
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Ornamento(anchoLinea: 60, tamanoIcono: 20),
          const SizedBox(height: 24),
          Text(
            firma,
            style: t.cuerpoPequeno
                .copyWith(fontSize: 18, color: c.oro.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }

  Widget _versos(
    BuildContext context,
    BoxConstraints restricciones,
    TextStyle estilo,
  ) {
    final escalado = MediaQuery.textScalerOf(context);
    final direccion = Directionality.of(context);
    double alto(String verso) {
      final pintor = TextPainter(
        text: TextSpan(text: verso, style: estilo),
        textAlign: TextAlign.center,
        textDirection: direccion,
        textScaler: escalado,
      )..layout(maxWidth: restricciones.maxWidth);
      final h = pintor.height;
      pintor.dispose();
      return h;
    }

    final estrofas = poema.versos.length <= _umbralVersos
        ? poema.estrofas
        : seleccionarVersos(
            estrofas: poema.estrofas,
            altoVerso: alto,
            altoDisponible: restricciones.maxHeight,
            huecoEstrofa: _huecoEstrofa,
            altoPuntos: _huecoEstrofa + alto('…'),
          );
    final esPreview =
        estrofas.fold<int>(0, (n, e) => n + e.length) < poema.versos.length;

    final bloque = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < estrofas.length; i++) ...[
          if (i > 0) const SizedBox(height: _huecoEstrofa),
          for (final verso in estrofas[i])
            Text(verso, textAlign: TextAlign.center, style: estilo),
        ],
        if (esPreview) ...[
          const SizedBox(height: _huecoEstrofa),
          Text('…',
              textAlign: TextAlign.center,
              style: estilo.copyWith(color: context.colores.oro)),
        ],
      ],
    );

    // Only a whole short poem can overflow; scaleDown leaves anything that
    // fits at its natural size.
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(width: restricciones.maxWidth, child: bloque),
      ),
    );
  }

  /// The leading verses of [estrofas] that fit in [altoDisponible], stanza
  /// structure preserved, leaving room for the "…" line ([altoPuntos]).
  ///
  /// Cuts at the last stanza break that fits when that keeps at least three
  /// quarters of the verses that would fit; otherwise mid-stanza, since one
  /// huge stanza (a romance, a long blank-verse passage) would leave a nearly
  /// empty card.
  /// Always keeps at least one verse.
  @visibleForTesting
  static List<List<String>> seleccionarVersos({
    required List<List<String>> estrofas,
    required double Function(String verso) altoVerso,
    required double altoDisponible,
    required double huecoEstrofa,
    required double altoPuntos,
  }) {
    final limite = altoDisponible - altoPuntos;
    final resultado = <List<String>>[];
    var usado = 0.0;
    var versos = 0;
    var versosEnCorte = 0; // verses kept if we cut at the last stanza break

    fuera:
    for (final estrofa in estrofas) {
      final actual = <String>[];
      for (final verso in estrofa) {
        final hueco = actual.isEmpty && resultado.isNotEmpty ? huecoEstrofa : 0;
        final h = altoVerso(verso) + hueco;
        if (usado + h > limite && versos > 0) {
          if (actual.isNotEmpty) resultado.add(actual);
          break fuera;
        }
        usado += h;
        versos++;
        actual.add(verso);
      }
      resultado.add(actual);
      versosEnCorte = versos;
    }

    final completas = resultado.length -
        (versosEnCorte == versos ? 0 : 1); // stanzas that fit entirely
    if (versosEnCorte != versos && versosEnCorte * 4 >= versos * 3) {
      return resultado.sublist(0, completas);
    }
    return resultado;
  }
}
