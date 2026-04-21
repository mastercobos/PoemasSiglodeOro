import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/poema.dart';
import '../providers/favoritos_provider.dart';
import '../widgets/autor_link.dart';

class PoemaScreen extends StatefulWidget {
  final Poema poema;
  final List<Poema> todosLosPoemas;

  const PoemaScreen({
    super.key,
    required this.poema,
    required this.todosLosPoemas,
  });

  @override
  State<PoemaScreen> createState() => _PoemaScreenState();
}

class _PoemaScreenState extends State<PoemaScreen> {
  static const _cortesEstrofa = {4, 8, 11};

  final _shareKey = GlobalKey();
  bool _compartiendo = false;

  List<String> get _versos => widget.poema.texto
      .split('\n')
      .map((l) => l.trimRight())
      .where((l) => l.isNotEmpty)
      .toList();

  Widget _buildCuerpo(TextStyle estilo) {
    final versos = _versos;
    final spans = <TextSpan>[];
    for (int i = 0; i < versos.length; i++) {
      spans.add(TextSpan(text: versos[i]));
      if (i + 1 < versos.length) {
        final extraSpace = _cortesEstrofa.contains(i + 1) ? '\n\n' : '\n';
        spans.add(TextSpan(text: extraSpace));
      }
    }
    return SelectableText.rich(
      TextSpan(children: spans, style: estilo),
      textAlign: TextAlign.center,
    );
  }

  Future<void> _compartirImagen(BuildContext context) async {
    if (_compartiendo) return;
    setState(() => _compartiendo = true);
    HapticFeedback.lightImpact();

    try {
      // Wait for the card to finish painting. We poll debugNeedsPaint
      // with a small delay rather than assuming a fixed timeout.
      RenderRepaintBoundary? boundary;
      for (int i = 0; i < 10; i++) {
        await Future.delayed(const Duration(milliseconds: 50));
        boundary = _shareKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
        if (boundary != null && !boundary.debugNeedsPaint) break;
      }

      debugPrint('[Share] boundary: $boundary  needsPaint: ${boundary?.debugNeedsPaint}');

      Uint8List? bytes;
      if (boundary != null && !boundary.debugNeedsPaint) {
        final image = await boundary.toImage(pixelRatio: 3.15);
        debugPrint('[Share] image: ${image.width}x${image.height}');
        final byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);
        bytes = byteData?.buffer.asUint8List();
        debugPrint('[Share] bytes: ${bytes?.length}');
      } else {
        debugPrint('[Share] boundary never finished painting');
      }

      if (bytes != null && bytes.isNotEmpty) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/${_nombreArchivo()}.png');
        await file.writeAsBytes(bytes);
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'image/png')],
          subject: widget.poema.etiqueta,
          text: '${widget.poema.etiqueta} — ${widget.poema.autor}',
        );
      } else {
        await Share.share(_textoPlano(), subject: widget.poema.etiqueta);
      }
    } catch (e, st) {
      debugPrint('[Share] error: $e\n$st');
      try {
        await Share.share(_textoPlano(), subject: widget.poema.etiqueta);
      } catch (e2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No se pudo compartir: $e2',
                  style: GoogleFonts.lato()),
              backgroundColor: const Color(0xFF3B2F2F),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _compartiendo = false);
    }
  }

  String _sanitize(String text) {
    String s = text
        .toLowerCase()
        .replaceAll(RegExp(r'[áàäâã]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöôõ]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll(RegExp(r'ñ'), 'n')
        .replaceAll(RegExp(r'[^a-z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    while (s.startsWith('_')) s = s.substring(1);
    while (s.endsWith('_')) s = s.substring(0, s.length - 1);
    return s;
  }

  String _nombreArchivo() {
    final autor = _sanitize(widget.poema.autor);
    final words = widget.poema.etiqueta.trim().split(RegExp(r'\s+'));
    final titulo = _sanitize(words.take(4).join(' '));
    return '${autor}_${titulo.isEmpty ? 'poema' : titulo}';
  }

  String _textoPlano() {
    return '${widget.poema.etiqueta}\n${widget.poema.autor}\n\n'
        '${widget.poema.texto.trim()}\n\n— Poemario';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? const Color(0xFF1A1210) : const Color(0xFFFDF6EC);
    final titleColor =
        isDark ? const Color(0xFFF5E6C8) : const Color(0xFF3B2F2F);
    final versoColor =
        isDark ? const Color(0xFFF5E6C8) : const Color(0xFF3B2F2F);
    final subColor = isDark ? Colors.white38 : const Color(0xFF666666);

    final estiloVerso = GoogleFonts.lato(
      fontSize: 17,
      height: 2.05,
      color: versoColor,
      letterSpacing: 0.15,
    );

    return Consumer<FavoritosProvider>(
      builder: (context, favoritos, _) {
        final esFav = favoritos.esFavorito(widget.poema);
        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            backgroundColor: const Color(0xFF3B2F2F),
            foregroundColor: Colors.white,
            title: Text(
              widget.poema.etiqueta,
              style: GoogleFonts.playfairDisplay(
                  fontSize: 17, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            centerTitle: true,
            elevation: 0,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(color: const Color(0xFF8B6914), height: 1),
            ),
            actions: [
              IconButton(
                tooltip: 'Compartir: ${widget.poema.etiqueta}',
                icon: _compartiendo
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white70,
                        ),
                      )
                    : const Icon(Icons.share_outlined, color: Colors.white70),
                onPressed:
                    _compartiendo ? null : () => _compartirImagen(context),
              ),
              IconButton(
                tooltip: esFav
                    ? 'Quitar de favoritos: ${widget.poema.etiqueta}'
                    : 'Añadir a favoritos: ${widget.poema.etiqueta}',
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Icon(
                    esFav ? Icons.favorite : Icons.favorite_border,
                    key: ValueKey(esFav),
                    color:
                        esFav ? const Color(0xFFD4AF6A) : Colors.white70,
                    semanticLabel: esFav
                        ? 'Guardado en favoritos'
                        : 'No guardado en favoritos',
                  ),
                ),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  favoritos.toggleFavorito(widget.poema);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        esFav
                            ? 'Eliminado de favoritos'
                            : 'Añadido a favoritos',
                        style: GoogleFonts.lato(),
                      ),
                      backgroundColor: const Color(0xFF3B2F2F),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  );
                },
              ),
            ],
          ),
          body: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── Main scrollable content ──────────────────────────────────
              Positioned.fill(
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(
                      MediaQuery.of(context)
                          .textScaler
                          .scale(1.0)
                          .clamp(1.0, 1.15),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 36),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        ExcludeSemantics(child: _ornament()),
                        const SizedBox(height: 28),
                        SelectableText(
                          widget.poema.etiqueta,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: titleColor,
                            height: 1.25,
                          ),
                        ),
                        if (widget.poema.titulo.isNotEmpty &&
                            widget.poema.primerVerso.isNotEmpty &&
                            widget.poema.primerVerso != widget.poema.titulo)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: SelectableText(
                              '«${widget.poema.primerVerso}»',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.lato(
                                fontSize: 13,
                                color: subColor,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        const SizedBox(height: 10),
                        AutorLink(
                            autor: widget.poema.autor,
                            todosLosPoemas: widget.todosLosPoemas),
                        const SizedBox(height: 30),
                        ExcludeSemantics(
                          child: Container(
                            width: 56,
                            height: 2,
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B6914),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ),
                        const SizedBox(height: 34),
                        Semantics(
                          label: 'Poema: ${widget.poema.etiqueta}, '
                              'de ${widget.poema.autor}',
                          child: _buildCuerpo(estiloVerso),
                        ),
                        const SizedBox(height: 52),
                        ExcludeSemantics(child: _ornament()),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Hidden share card ────────────────────────────────────────
              // Positioned far off-screen (left: -9000) so the user never
              // sees it, but Flutter still performs a full layout + paint
              // pass — which is required before toImage() can be called.
              // SizedBox(0,0) and Opacity(0) both suppress painting; we
              // must give the card real unconstrained space instead.
              Positioned(
                left: -9000,
                top: 0,
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: RepaintBoundary(
                      key: _shareKey,
                      child: _ShareCard(
                        poema: widget.poema,
                        isDark: isDark,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _ornament() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(width: 44, height: 1, color: const Color(0xFF8B6914)),
        const SizedBox(width: 10),
        const Icon(Icons.auto_stories,
            color: Color(0xFF8B6914), size: 18),
        const SizedBox(width: 10),
        Container(width: 44, height: 1, color: const Color(0xFF8B6914)),
      ],
    );
  }
}

// ─── Shareable image card ─────────────────────────────────────────────────────
// Rendered off-screen (left: -9000) so Flutter fully lays it out and paints it.
// Captured as PNG via RepaintBoundary when the user taps share.
// Fixed 800 px wide — looks good on any social network.

class _ShareCard extends StatelessWidget {
  final Poema poema;
  final bool isDark;
  const _ShareCard({required this.poema, required this.isDark});

  static const _cortesEstrofa = {4, 8, 11};

  List<String> get _versos => poema.texto
      .split('\n')
      .map((l) => l.trimRight())
      .where((l) => l.isNotEmpty)
      .toList();

  @override
  Widget build(BuildContext context) {
    final bgColor =
        isDark ? const Color(0xFF1A0F0A) : const Color(0xFFFAF0E0);
    final titleColor =
        isDark ? const Color(0xFFF5E6C8) : const Color(0xFF3B2F2F);
    final versoColor =
        isDark ? const Color(0xFFF5E6C8) : const Color(0xFF3B2F2F);

    final versos = _versos;
    final estiloVerso = GoogleFonts.lato(
      fontSize: 22,
      height: 2.0,
      color: versoColor,
      letterSpacing: 0.2,
    );

    final versoWidgets = <Widget>[];
    for (int i = 0; i < versos.length; i++) {
      versoWidgets.add(
        Text(versos[i], textAlign: TextAlign.center, style: estiloVerso),
      );
      if (_cortesEstrofa.contains(i + 1) && i + 1 < versos.length) {
        versoWidgets.add(const SizedBox(height: 18));
      }
    }

    return MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.noScaling),
      child: Container(
        width: 800,
        color: bgColor,
        padding:
            const EdgeInsets.symmetric(horizontal: 60, vertical: 64),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ornament(),
            const SizedBox(height: 40),
            Text(
              poema.etiqueta,
              textAlign: TextAlign.center,
              style: GoogleFonts.playfairDisplay(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: titleColor,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              poema.autor,
              textAlign: TextAlign.center,
              style: GoogleFonts.lato(
                fontSize: 22,
                color: const Color(0xFF8B6914),
                fontStyle: FontStyle.italic,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              width: 60,
              height: 2,
              decoration: BoxDecoration(
                color: const Color(0xFF8B6914),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(height: 36),
            ...versoWidgets,
            const SizedBox(height: 40),
            _ornament(),
            const SizedBox(height: 28),
            Text(
              'Poemario · Siglo de Oro',
              style: GoogleFonts.lato(
                fontSize: 18,
                color: const Color(0xFF8B6914).withValues(alpha: 0.7),
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ornament() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(width: 60, height: 1, color: const Color(0xFF8B6914)),
        const SizedBox(width: 12),
        const Icon(Icons.auto_stories, color: Color(0xFF8B6914), size: 20),
        const SizedBox(width: 12),
        Container(width: 60, height: 1, color: const Color(0xFF8B6914)),
      ],
    );
  }
}
