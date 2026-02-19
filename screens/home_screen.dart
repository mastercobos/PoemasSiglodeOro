import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/poema.dart';
import 'poema_screen.dart';

class HomeScreen extends StatelessWidget {
  final List<Poema> poemas;

  const HomeScreen({super.key, required this.poemas});

  /// Agrupa por autor, ordena autores y poemas alfabéticamente.
  Map<String, List<Poema>> _agrupar() {
    final Map<String, List<Poema>> mapa = {};
    for (final p in poemas) {
      mapa.putIfAbsent(p.autor, () => []).add(p);
    }
    for (final lista in mapa.values) {
      lista.sort((a, b) =>
          a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase()));
    }
    return Map.fromEntries(
      mapa.entries.toList()
        ..sort((a, b) =>
            a.key.toLowerCase().compareTo(b.key.toLowerCase())),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grupos = _agrupar();
    final autores = grupos.keys.toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFDF6EC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3B2F2F),
        foregroundColor: Colors.white,
        title: Text(
          'Antología Poética',
          style: GoogleFonts.playfairDisplay(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFF8B6914), height: 1),
        ),
      ),
      body: Column(
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              itemCount: autores.length,
              itemBuilder: (context, i) {
                final autor = autores[i];
                return _AutorCard(
                  autor: autor,
                  poemas: grupos[autor]!,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────
// Tarjeta expandible por autor
// ──────────────────────────────────────────────────────────
class _AutorCard extends StatefulWidget {
  final String autor;
  final List<Poema> poemas;

  const _AutorCard({required this.autor, required this.poemas});

  @override
  State<_AutorCard> createState() => _AutorCardState();
}

class _AutorCardState extends State<_AutorCard> {
  bool _open = false;

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
            // ── Cabecera ──
            Material(
              color:
                  _open ? const Color(0xFF3B2F2F) : const Color(0xFFFAF0E0),
              child: InkWell(
                onTap: () => setState(() => _open = !_open),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      // Avatar
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _open
                              ? const Color(0xFF8B6914)
                              : const Color(0xFF3B2F2F),
                        ),
                        child: Center(
                          child: Text(
                            widget.autor.isNotEmpty
                                ? widget.autor[0].toUpperCase()
                                : '?',
                            style: GoogleFonts.playfairDisplay(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Nombre + conteo
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.autor,
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: _open
                                    ? Colors.white
                                    : const Color(0xFF3B2F2F),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${widget.poemas.length} poema'
                              '${widget.poemas.length != 1 ? 's' : ''}',
                              style: GoogleFonts.lato(
                                fontSize: 12,
                                color: _open
                                    ? const Color(0xFFD4AF6A)
                                    : const Color(0xFF8B6914),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Flecha animada
                      AnimatedRotation(
                        turns: _open ? 0.5 : 0,
                        duration: const Duration(milliseconds: 220),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          size: 28,
                          color: _open
                              ? const Color(0xFFD4AF6A)
                              : const Color(0xFF8B6914),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Cuerpo colapsable con AnimatedSize (más eficiente) ──
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              child: _open
                  ? _PoemasLista(poemas: widget.poemas)
                  : const SizedBox(width: double.infinity, height: 0),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────
// Lista de poemas dentro de la tarjeta
// ──────────────────────────────────────────────────────────
class _PoemasLista extends StatelessWidget {
  final List<Poema> poemas;

  const _PoemasLista({required this.poemas});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabecera "POEMAS"
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Container(width: 20, height: 1, color: const Color(0xFFD4AF6A)),
              const SizedBox(width: 8),
              Text(
                'POEMAS',
                style: GoogleFonts.lato(
                  fontSize: 10,
                  letterSpacing: 2,
                  color: const Color(0xFF8B6914),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                  child:
                      Container(height: 1, color: const Color(0xFFD4AF6A))),
            ],
          ),
        ),

        // Filas de poemas
        ...List.generate(poemas.length, (idx) {
          final poema = poemas[idx];
          return Column(
            children: [
              if (idx > 0)
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: Colors.brown.withValues(alpha: 0.1),
                ),
              Material(
                color: Colors.white,
                child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (_, __, ___) => PoemaScreen(poema: poema),
                      transitionsBuilder: (_, animation, __, child) =>
                          FadeTransition(opacity: animation, child: child),
                      transitionDuration: const Duration(milliseconds: 250),
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
                          child: Text(
                            poema.titulo,
                            style: GoogleFonts.lato(
                              fontSize: 15,
                              color: const Color(0xFF3B2F2F),
                              fontWeight: FontWeight.w500,
                            ),
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
    );
  }
}