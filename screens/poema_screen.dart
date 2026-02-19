import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/poema.dart';

class PoemaScreen extends StatelessWidget {
  final Poema poema;

  const PoemaScreen({super.key, required this.poema});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF6EC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3B2F2F),
        foregroundColor: Colors.white,
        title: Text(
          poema.titulo,
          style: GoogleFonts.playfairDisplay(fontSize: 17, fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFF8B6914), height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Ornamento superior
            _ornament(),
            const SizedBox(height: 28),

            // Título
            Text(
              poema.titulo,
              textAlign: TextAlign.center,
              style: GoogleFonts.playfairDisplay(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF3B2F2F),
                height: 1.25,
              ),
            ),
            const SizedBox(height: 10),

            // Autor
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

            // Línea decorativa
            Container(
              width: 56,
              height: 2,
              decoration: BoxDecoration(
                color: const Color(0xFF8B6914),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(height: 34),

            // Cuerpo del poema
            Text(
              poema.texto,
              textAlign: TextAlign.center,
              style: GoogleFonts.lato(
                fontSize: 17,
                height: 2.05,
                color: const Color(0xFF3B2F2F),
                letterSpacing: 0.15,
              ),
            ),

            const SizedBox(height: 52),
            _ornament(),
            const SizedBox(height: 16),
          ],
        ),
      ),
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