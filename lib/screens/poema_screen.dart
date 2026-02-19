import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/poema.dart';
import '../providers/favoritos_provider.dart';

class PoemaScreen extends StatelessWidget {
  final Poema poema;

  const PoemaScreen({super.key, required this.poema});

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
      widgets.add(Text(versos[i], textAlign: TextAlign.center, style: estilo));
      if (_cortesEstrofa.contains(i + 1) && i + 1 < versos.length) {
        widgets.add(const SizedBox(height: 20));
      }
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final estiloVerso = GoogleFonts.lato(
      fontSize: 17,
      height: 1.85,
      color: const Color(0xFF3B2F2F),
      letterSpacing: 0.15,
    );

    return Consumer<FavoritosProvider>(
      builder: (context, favoritos, _) {
        final esFav = favoritos.esFavorito(poema);
        return Scaffold(
          backgroundColor: const Color(0xFFFDF6EC),
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
              IconButton(
                tooltip: esFav ? 'Quitar de favoritos' : 'Añadir a favoritos',
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Icon(
                    esFav ? Icons.favorite : Icons.favorite_border,
                    key: ValueKey(esFav),
                    color: esFav ? const Color(0xFFD4AF6A) : Colors.white70,
                  ),
                ),
                onPressed: () {
                  favoritos.toggleFavorito(poema);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        esFav ? 'Eliminado de favoritos' : 'Añadido a favoritos',
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
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _ornament(),
                const SizedBox(height: 28),

                Text(
                  poema.etiqueta,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF3B2F2F),
                    height: 1.25,
                  ),
                ),

                if (poema.titulo.isNotEmpty &&
                    poema.primerVerso.isNotEmpty &&
                    poema.primerVerso != poema.titulo)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '«${poema.primerVerso}»',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.lato(
                        fontSize: 13,
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),

                const SizedBox(height: 10),
                Text(
                  poema.autor,
                  style: GoogleFonts.lato(
                    fontSize: 14,
                    color: const Color(0xFF8B6914),
                    fontStyle: FontStyle.italic,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 30),
                Container(
                  width: 56, height: 2,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B6914),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const SizedBox(height: 34),

                ..._buildCuerpo(estiloVerso),

                const SizedBox(height: 52),
                _ornament(),
                const SizedBox(height: 16),
              ],
            ),
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
        const Icon(Icons.auto_stories, color: Color(0xFF8B6914), size: 18),
        const SizedBox(width: 10),
        Container(width: 44, height: 1, color: const Color(0xFF8B6914)),
      ],
    );
  }
}
