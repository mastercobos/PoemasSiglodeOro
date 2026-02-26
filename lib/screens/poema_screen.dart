import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/poema.dart';
import '../providers/favoritos_provider.dart';
import '../widgets/autor_link.dart';

class PoemaScreen extends StatelessWidget {
  final Poema poema;
  final List<Poema> todosLosPoemas;

  const PoemaScreen({
    super.key,
    required this.poema,
    required this.todosLosPoemas,
  });

  static const _cortesEstrofa = {4, 8, 11};

  List<String> get _versos => poema.texto
      .split('\n')
      .map((l) => l.trimRight())
      .where((l) => l.isNotEmpty)
      .toList();

  List<Widget> _buildCuerpo(TextStyle estilo) {
    final versos = _versos;
    final widgets = <Widget>[];
    for (int i = 0; i < versos.length; i++) {
      widgets.add(SelectableText(versos[i],
          textAlign: TextAlign.center, style: estilo));
      if (_cortesEstrofa.contains(i + 1) && i + 1 < versos.length) {
        widgets.add(const SizedBox(height: 20));
      }
    }
    return widgets;
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
    // ⑦ Contraste: #666666 sobre crema da 5.35:1 (WCAG AA ✓)
    final subColor =
        isDark ? Colors.white38 : const Color(0xFF666666);

    final estiloVerso = GoogleFonts.lato(
      fontSize: 17,
      height: 2.05,
      color: versoColor,
      letterSpacing: 0.15,
    );

    return Consumer<FavoritosProvider>(
      builder: (context, favoritos, _) {
        final esFav = favoritos.esFavorito(poema);
        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            backgroundColor: const Color(0xFF3B2F2F),
            foregroundColor: Colors.white,
            title: Text(
              poema.etiqueta,
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
              // ③ Semantics: tooltip ya actúa como label para TalkBack
              IconButton(
                tooltip: esFav
                    ? 'Quitar de favoritos: ${poema.etiqueta}'
                    : 'Añadir a favoritos: ${poema.etiqueta}',
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Icon(
                    esFav ? Icons.favorite : Icons.favorite_border,
                    key: ValueKey(esFav),
                    color: esFav
                        ? const Color(0xFFD4AF6A)
                        : Colors.white70,
                    // ③ semanticLabel para lectores de pantalla
                    semanticLabel: esFav
                        ? 'Guardado en favoritos'
                        : 'No guardado en favoritos',
                  ),
                ),
                onPressed: () {
                  // ⑨ Haptic feedback en acción de favorito
                  HapticFeedback.mediumImpact();
                  favoritos.toggleFavorito(poema);
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
          body: MediaQuery(
            // Limitamos el escalado de texto en la pantalla del poema.
            // La estructura visual del verso es parte del significado poético
            // y no puede romperse en líneas arbitrarias. Permitimos hasta
            // 1.15× para respetar la accesibilidad visual sin romper la métrica.
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(
                MediaQuery.of(context).textScaler.scale(1.0).clamp(1.0, 1.15),
              ),
            ),
            child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ③ El ornamento es decorativo — excluir de accesibilidad
                ExcludeSemantics(child: _ornament()),
                const SizedBox(height: 28),

                SelectableText(
                  poema.etiqueta,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                    height: 1.25,
                  ),
                ),

                if (poema.titulo.isNotEmpty &&
                    poema.primerVerso.isNotEmpty &&
                    poema.primerVerso != poema.titulo)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: SelectableText(
                      '«${poema.primerVerso}»',
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
                    autor: poema.autor, todosLosPoemas: todosLosPoemas),
                const SizedBox(height: 30),

                // ③ Separador decorativo
                ExcludeSemantics(
                  child: Container(
                    width: 56, height: 2,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B6914),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
                const SizedBox(height: 34),

                // ⑧ El cuerpo del poema: Semantics agrupa título + texto
                // para que TalkBack lo anuncie como una unidad
                Semantics(
                  label:
                      'Poema: ${poema.etiqueta}, de ${poema.autor}',
                  child: Column(
                    children: _buildCuerpo(estiloVerso),
                  ),
                ),

                const SizedBox(height: 52),
                ExcludeSemantics(child: _ornament()),
                const SizedBox(height: 16),
              ],
            ),
          ),
          ), // MediaQuery textScaler cap
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
