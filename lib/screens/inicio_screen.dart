import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/poema.dart';
import '../providers/ajustes_provider.dart';
import 'poema_screen.dart';
import 'ajustes_inicio_screen.dart';

class InicioScreen extends StatelessWidget {
  final List<Poema> poemas;
  const InicioScreen({super.key, required this.poemas});

  int _semilla(DateTime fecha) =>
      fecha.year * 100000 + fecha.month * 1000 + fecha.day;

  int _rand(int semilla) =>
      ((semilla * 1664525 + 1013904223) & 0x7FFFFFFF);

  List<Poema> _poemasDelDia(List<Poema> pool) {
    if (pool.isEmpty) return [];
    if (pool.length == 1) return [pool[0]];

    final hoy  = DateTime.now();
    final ayer = hoy.subtract(const Duration(days: 1));
    final semHoy  = _semilla(hoy);
    final semAyer = _semilla(ayer);

    // Reconstruir el primer poema de ayer con la semilla de ayer
    final autorExcluidoAyer = pool[_rand(semAyer) % pool.length].autor;
    final poolAyer = pool.where((p) => p.autor != autorExcluidoAyer).toList();
    final p1Ayer = poolAyer.isNotEmpty
        ? poolAyer[_rand(semAyer) % poolAyer.length]
        : pool[_rand(semAyer) % pool.length];
    final autorAyer = p1Ayer.autor;

    // Primer poema de hoy: excluir autor de ayer
    final poolHoy = pool.where((p) => p.autor != autorAyer).toList();
    final p1 = poolHoy.isNotEmpty
        ? poolHoy[_rand(semHoy) % poolHoy.length]
        : pool[_rand(semHoy) % pool.length];

    // Segundo poema de hoy: excluir autor de p1 si hay más de un autor
    final poolP2 = pool.where((p) => p.autor != p1.autor).toList();
    final p2pool = poolP2.isNotEmpty ? poolP2 : pool.where((p) => p.id != p1.id).toList();
    if (p2pool.isEmpty) return [p1];
    final p2 = p2pool[_rand(_rand(semHoy)) % p2pool.length];

    return [p1, p2];
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AjustesProvider>(
      builder: (context, ajustes, _) {
        final pool = ajustes.autoresActivos.isEmpty
            ? <Poema>[]
            : poemas.where((p) => ajustes.autoresActivos.contains(p.autor)).toList();

        final destacados = _poemasDelDia(pool);

        final hoy = DateTime.now();
        const meses = [
          '', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
          'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
        ];
        final fechaStr = '${hoy.day} de ${meses[hoy.month]} de ${hoy.year}';

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  Text(fechaStr,
                      style: GoogleFonts.lato(
                          fontSize: 12,
                          letterSpacing: 2,
                          color: const Color(0xFF8B6914))),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Filtrar autores',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.tune,
                        color: Color(0xFF8B6914), size: 20),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AjustesInicioScreen()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('Poemas del día',
                  style: GoogleFonts.playfairDisplay(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF3B2F2F))),
              const SizedBox(height: 4),
              Container(
                width: 56, height: 2,
                decoration: BoxDecoration(
                    color: const Color(0xFF8B6914),
                    borderRadius: BorderRadius.circular(1)),
              ),
              const SizedBox(height: 10),
              Text(
                ajustes.totalActivos == ajustes.todosLosAutores.length
                    ? 'Todos los autores'
                    : '${ajustes.totalActivos} autor${ajustes.totalActivos != 1 ? 'es' : ''} seleccionado${ajustes.totalActivos != 1 ? 's' : ''}',
                style: GoogleFonts.lato(
                    fontSize: 11,
                    color: Colors.grey[500],
                    letterSpacing: 0.5),
              ),
              const SizedBox(height: 24),

              if (destacados.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Column(
                    children: [
                      const Icon(Icons.sentiment_neutral,
                          size: 48, color: Color(0xFFD4AF6A)),
                      const SizedBox(height: 16),
                      Text('Ningún autor seleccionado',
                          style: GoogleFonts.playfairDisplay(
                              fontSize: 18,
                              color: const Color(0xFF3B2F2F))),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        icon: const Icon(Icons.tune, color: Color(0xFF8B6914)),
                        label: Text('Configurar autores',
                            style: GoogleFonts.lato(
                                color: const Color(0xFF8B6914))),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AjustesInicioScreen()),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...destacados.map((p) => _TarjetaPoema(poema: p, todosLosPoemas: poemas)),
            ],
          ),
        );
      },
    );
  }
}

class _TarjetaPoema extends StatelessWidget {
  final Poema poema;
  final List<Poema> todosLosPoemas;
  const _TarjetaPoema({required this.poema, required this.todosLosPoemas});

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
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => PoemaScreen(poema: poema, todosLosPoemas: todosLosPoemas),
                transitionsBuilder: (_, animation, __, child) =>
                    FadeTransition(opacity: animation, child: child),
                transitionDuration: const Duration(milliseconds: 250),
              ),
            ),
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: const Color(0xFF3B2F2F),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(poema.etiqueta,
                      style: GoogleFonts.playfairDisplay(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  if (poema.titulo.isNotEmpty &&
                      poema.primerVerso.isNotEmpty &&
                      poema.primerVerso != poema.titulo)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text('«${poema.primerVerso}»',
                          style: GoogleFonts.lato(
                              fontSize: 12,
                              color: Colors.white54,
                              fontStyle: FontStyle.italic),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  const SizedBox(height: 4),
                  Text(poema.autor,
                      style: GoogleFonts.lato(
                          fontSize: 13,
                          color: const Color(0xFFD4AF6A),
                          fontStyle: FontStyle.italic)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
              child: Text(_fragmento(),
                  style: GoogleFonts.lato(
                      fontSize: 15,
                      height: 1.85,
                      color: const Color(0xFF4A3728))),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('Leer poema completo',
                      style: GoogleFonts.lato(
                          fontSize: 12,
                          color: const Color(0xFF8B6914),
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right,
                      size: 16, color: Color(0xFF8B6914)),
                ],
              ),
            ),
            const SizedBox(height: 6),
          ],
        ),
          ),
        ),
      ),
    );
  }
}
