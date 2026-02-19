import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/poema.dart';
import '../providers/favoritos_provider.dart';
import 'poema_screen.dart';

class FavoritosScreen extends StatelessWidget {
  const FavoritosScreen({super.key});

  /// Agrupa los favoritos por autor, ordenados alfabéticamente.
  Map<String, List<Poema>> _agrupar(List<Poema> poemas) {
    final Map<String, List<Poema>> mapa = {};
    for (final p in poemas) {
      mapa.putIfAbsent(p.autor, () => []).add(p);
    }
    for (final lista in mapa.values) {
      lista.sort((a, b) =>
          a.etiqueta.toLowerCase().compareTo(b.etiqueta.toLowerCase()));
    }
    return Map.fromEntries(
      mapa.entries.toList()
        ..sort((a, b) =>
            a.key.toLowerCase().compareTo(b.key.toLowerCase())),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FavoritosProvider>(
      builder: (context, favoritos, _) {
        final lista = favoritos.favoritos;

        if (lista.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.favorite_border,
                    size: 64, color: Color(0xFFD4AF6A)),
                const SizedBox(height: 20),
                Text(
                  'Aún no tienes favoritos',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 20,
                    color: const Color(0xFF3B2F2F),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Pulsa el corazón al leer un poema\npara guardarlo aquí.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lato(
                    fontSize: 14,
                    color: const Color(0xFF8B6914),
                    height: 1.6,
                  ),
                ),
              ],
            ),
          );
        }

        final grupos = _agrupar(lista);
        final autores = grupos.keys.toList();

        return Column(
          children: [
            Container(
              width: double.infinity,
              color: const Color(0xFF3B2F2F),
              padding: const EdgeInsets.only(top: 4, bottom: 14),
              child: Text(
                '— ${lista.length} poema${lista.length != 1 ? 's' : ''} guardado${lista.length != 1 ? 's' : ''} —',
                textAlign: TextAlign.center,
                style: GoogleFonts.lato(
                  color: const Color(0xFFD4AF6A),
                  fontSize: 12,
                  letterSpacing: 2.5,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                itemCount: autores.length,
                itemBuilder: (context, i) {
                  final autor = autores[i];
                  return _FavAutorCard(
                    autor: autor,
                    poemas: grupos[autor]!,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────────
class _FavAutorCard extends StatelessWidget {
  final String autor;
  final List<Poema> poemas;
  const _FavAutorCard({required this.autor, required this.poemas});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD4AF6A)),
        boxShadow: [
          BoxShadow(
            color: Colors.brown.withValues(alpha: 0.09),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            // Cabecera autor
            Container(
              color: const Color(0xFF3B2F2F),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF8B6914),
                    ),
                    child: Center(
                      child: Text(
                        autor.isNotEmpty ? autor[0].toUpperCase() : '?',
                        style: GoogleFonts.playfairDisplay(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      autor,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const Icon(Icons.favorite,
                      size: 16, color: Color(0xFFD4AF6A)),
                ],
              ),
            ),

            // Lista de poemas favoritos de este autor
            ...List.generate(poemas.length, (idx) {
              final poema = poemas[idx];
              return Column(
                children: [
                  if (idx > 0)
                    Divider(
                      height: 1, indent: 16, endIndent: 16,
                      color: Colors.brown.withValues(alpha: 0.1),
                    ),
                  Material(
                    color: Colors.white,
                    child: InkWell(
                      onTap: () => Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (_, __, ___) =>
                              PoemaScreen(poema: poema),
                          transitionsBuilder:
                              (_, animation, __, child) =>
                                  FadeTransition(
                                      opacity: animation, child: child),
                          transitionDuration:
                              const Duration(milliseconds: 250),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 13),
                        child: Row(
                          children: [
                            const Icon(Icons.menu_book_outlined,
                                size: 16, color: Color(0xFF8B6914)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    poema.etiqueta,
                                    style: GoogleFonts.lato(
                                      fontSize: 15,
                                      color: const Color(0xFF3B2F2F),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (poema.titulo.isNotEmpty &&
                                      poema.primerVerso.isNotEmpty &&
                                      poema.primerVerso != poema.titulo)
                                    Text(
                                      '«${poema.primerVerso}»',
                                      style: GoogleFonts.lato(
                                        fontSize: 12,
                                        color: Colors.grey[500],
                                        fontStyle: FontStyle.italic,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right,
                                size: 18, color: Color(0xFFD4AF6A)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
