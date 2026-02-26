import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/poema.dart';
import '../utils/roman.dart';
import 'poema_screen.dart';

class AutorScreen extends StatelessWidget {
  final String autor;
  final List<Poema> poemas;
  final List<Poema> todosLosPoemas;

  const AutorScreen({
    super.key,
    required this.autor,
    required this.poemas,
    required this.todosLosPoemas,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1210) : const Color(0xFFFDF6EC);
    final rowColor = isDark ? const Color(0xFF2A1F18) : Colors.white;
    final textColor = isDark ? const Color(0xFFF5E6C8) : const Color(0xFF3B2F2F);
    final subColor = isDark ? Colors.white38 : const Color(0xFF666666);

    final sorted = [...poemas]
      ..sort((a, b) => compareTitulos(a.etiqueta, b.etiqueta));

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF3B2F2F),
        foregroundColor: Colors.white,
        title: Text(autor,
            style: GoogleFonts.playfairDisplay(
                fontSize: 18, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis),
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
              '${sorted.length} poema${sorted.length != 1 ? 's' : ''}',
              textAlign: TextAlign.center,
              style: GoogleFonts.lato(
                  color: const Color(0xFFD4AF6A),
                  fontSize: 12,
                  letterSpacing: 2.5),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: sorted.length,
              itemBuilder: (context, idx) {
                final poema = sorted[idx];
                return Column(
                  children: [
                    if (idx > 0)
                      Divider(
                        height: 1, indent: 16, endIndent: 16,
                        color: const Color(0xFFD4AF6A).withValues(alpha: 0.3),
                      ),
                    MergeSemantics(
                  child: Material(
                      color: rowColor,
                      child: InkWell(
                        onTap: () => Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (_, __, ___) => PoemaScreen(
                                poema: poema, todosLosPoemas: todosLosPoemas),
                            transitionsBuilder: (_, animation, __, child) =>
                                FadeTransition(opacity: animation, child: child),
                            transitionDuration:
                                const Duration(milliseconds: 250),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const ExcludeSemantics(
                                child: Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Icon(Icons.menu_book_outlined,
                                    size: 16, color: Color(0xFF8B6914)),
                              ),),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(poema.etiqueta,
                                        style: GoogleFonts.lato(
                                            fontSize: 15,
                                            color: textColor,
                                            fontWeight: FontWeight.w500)),
                                    if (poema.titulo.isNotEmpty &&
                                        poema.primerVerso.isNotEmpty &&
                                        poema.primerVerso != poema.titulo)
                                      Text('«${poema.primerVerso}»',
                                          style: GoogleFonts.lato(
                                              fontSize: 12,
                                              color: subColor,
                                              fontStyle: FontStyle.italic),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
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
                  ), // MergeSemantics
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
