import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/poema.dart';
import 'poema_screen.dart';

class InicioScreen extends StatelessWidget {
  final List<Poema> poemas;

  const InicioScreen({super.key, required this.poemas});

  /// Devuelve 2 poemas distintos deterministas según el día actual.
  List<Poema> _poemasDelDia() {
    final hoy = DateTime.now();
    // Semilla basada en año + día del año → cambia cada día, igual para todos
    final semilla = hoy.year * 1000 + hoy.dayOfYear;
    final total = poemas.length;
    final i1 = semilla % total;
    final i2 = (semilla * 31 + 7) % total == i1
        ? (semilla * 31 + 8) % total
        : (semilla * 31 + 7) % total;
    return [poemas[i1], poemas[i2]];
  }

  @override
  Widget build(BuildContext context) {
    final destacados = _poemasDelDia();
    final hoy = DateTime.now();
    final meses = [
      '', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];
    final fechaStr = '${hoy.day} de ${meses[hoy.month]} de ${hoy.year}';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Fecha
          Text(
            fechaStr,
            style: GoogleFonts.lato(
              fontSize: 12,
              letterSpacing: 2,
              color: const Color(0xFF8B6914),
            ),
          ),
          const SizedBox(height: 6),

          // Título sección
          Text(
            'Poemas del día',
            style: GoogleFonts.playfairDisplay(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF3B2F2F),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 56, height: 2,
            decoration: BoxDecoration(
              color: const Color(0xFF8B6914),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(height: 28),

          // Tarjetas de los dos poemas
          ...destacados.map((p) => _TarjetaPoema(poema: p)),
        ],
      ),
    );
  }
}

class _TarjetaPoema extends StatelessWidget {
  final Poema poema;
  const _TarjetaPoema({required this.poema});

  /// Primeras líneas del poema como fragmento de muestra.
  String _fragmento() {
    final lineas = poema.texto
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .take(4)
        .join('\n');
    return '$lineas\n…';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD4AF6A)),
        boxShadow: [
          BoxShadow(
            color: Colors.brown.withValues(alpha: 0.09),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabecera marrón
            Container(
              color: const Color(0xFF3B2F2F),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    poema.titulo,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    poema.autor,
                    style: GoogleFonts.lato(
                      fontSize: 13,
                      color: const Color(0xFFD4AF6A),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),

            // Fragmento
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
              child: Text(
                _fragmento(),
                style: GoogleFonts.lato(
                  fontSize: 15,
                  height: 1.85,
                  color: const Color(0xFF4A3728),
                ),
              ),
            ),

            // Botón leer
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (_, __, ___) => PoemaScreen(poema: poema),
                    transitionsBuilder: (_, animation, __, child) =>
                        FadeTransition(opacity: animation, child: child),
                    transitionDuration: const Duration(milliseconds: 250),
                  ),
                ),
                icon: const Icon(Icons.menu_book_outlined,
                    size: 16, color: Color(0xFF8B6914)),
                label: Text(
                  'Leer poema completo',
                  style: GoogleFonts.lato(
                    fontSize: 13,
                    color: const Color(0xFF8B6914),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

extension on DateTime {
  int get dayOfYear {
    return difference(DateTime(year, 1, 1)).inDays + 1;
  }
}
