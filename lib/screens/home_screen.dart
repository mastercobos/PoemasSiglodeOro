import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/poema.dart';
import 'autor_screen.dart';

class HomeScreen extends StatelessWidget {
  final List<Poema> poemas;
  const HomeScreen({super.key, required this.poemas});

  Map<String, List<Poema>> _agrupar() {
    final Map<String, List<Poema>> mapa = {};
    for (final p in poemas) {
      mapa.putIfAbsent(p.autor, () => []).add(p);
    }
    return Map.fromEntries(
      mapa.entries.toList()
        ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase())),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grupos = _agrupar();
    final autores = grupos.keys.toList();

    return Column(
      children: [
        Container(
          width: double.infinity,
          color: const Color(0xFF3B2F2F),
          padding: const EdgeInsets.only(top: 4, bottom: 14),
          child: Text(
            '— Índice de Autores —',
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            itemCount: autores.length,
            itemBuilder: (context, i) {
              final autor = autores[i];
              final lista = grupos[autor]!;
              return _AutorCard(
                autor: autor,
                poemas: lista,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AutorCard extends StatelessWidget {
  final String autor;
  final List<Poema> poemas;
  const _AutorCard({required this.autor, required this.poemas});

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
        child: Material(
          color: const Color(0xFFFAF0E0),
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) =>
                    AutorScreen(autor: autor, poemas: poemas, todosLosPoemas: poemas),
                transitionsBuilder: (_, animation, __, child) =>
                    FadeTransition(opacity: animation, child: child),
                transitionDuration: const Duration(milliseconds: 250),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 46, height: 46,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF3B2F2F),
                    ),
                    child: Center(
                      child: Text(
                        autor.isNotEmpty ? autor[0].toUpperCase() : '?',
                        style: GoogleFonts.playfairDisplay(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Nombre y conteo
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          autor,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF3B2F2F),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${poemas.length} poema'
                          '${poemas.length != 1 ? 's' : ''}',
                          style: GoogleFonts.lato(
                            fontSize: 12,
                            color: const Color(0xFF8B6914),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      size: 22, color: Color(0xFF8B6914)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
