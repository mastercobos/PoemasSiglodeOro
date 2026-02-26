import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/ajustes_provider.dart';
import '../providers/tema_provider.dart';

class AjustesInicioScreen extends StatelessWidget {
  const AjustesInicioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1210) : const Color(0xFFFDF6EC);
    final cardColor = isDark ? const Color(0xFF2A1F18) : Colors.white;
    final textColor = isDark ? const Color(0xFFF5E6C8) : const Color(0xFF3B2F2F);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Ajustes',
            style: GoogleFonts.playfairDisplay(
                fontSize: 20, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        children: [
          // ── Sección Apariencia ──────────────────────────────
          _Seccion(titulo: 'Apariencia', isDark: isDark),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFD4AF6A).withValues(alpha: isDark ? 0.4 : 0.8),
              ),
            ),
            child: Consumer<TemaProvider>(
              builder: (context, tema, _) {
                return Column(
                  children: [
                    _OpcionTema(
                      titulo: 'Automático',
                      subtitulo: 'Sigue la configuración del sistema',
                      icono: Icons.brightness_auto,
                      seleccionado: tema.modo == ThemeMode.system,
                      onTap: () => tema.setModo(ThemeMode.system),
                      textColor: textColor,
                      isDark: isDark,
                    ),
                    Divider(height: 1, indent: 56,
                        color: const Color(0xFFD4AF6A).withValues(alpha: 0.3)),
                    _OpcionTema(
                      titulo: 'Claro',
                      subtitulo: 'Fondo crema, texto oscuro',
                      icono: Icons.wb_sunny_outlined,
                      seleccionado: tema.modo == ThemeMode.light,
                      onTap: () => tema.setModo(ThemeMode.light),
                      textColor: textColor,
                      isDark: isDark,
                    ),
                    Divider(height: 1, indent: 56,
                        color: const Color(0xFFD4AF6A).withValues(alpha: 0.3)),
                    _OpcionTema(
                      titulo: 'Oscuro',
                      subtitulo: 'Fondo negro, menos fatiga ocular',
                      icono: Icons.nightlight_outlined,
                      seleccionado: tema.modo == ThemeMode.dark,
                      onTap: () => tema.setModo(ThemeMode.dark),
                      textColor: textColor,
                      isDark: isDark,
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // ── Sección Poemas del día ──────────────────────────
          _Seccion(titulo: 'Poemas del día', isDark: isDark),
          Consumer<AjustesProvider>(
            builder: (context, ajustes, _) {
              final autores = ajustes.todosLosAutores;
              final activosCount = ajustes.totalActivos;

              return Column(
                children: [
                  // Barra acciones rápidas
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        Text(
                          '$activosCount de ${autores.length} autores',
                          style: GoogleFonts.lato(
                            fontSize: 13,
                            color: const Color(0xFF8B6914),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => ajustes.seleccionarTodos(),
                          child: Text('Todos',
                              style: GoogleFonts.lato(
                                  color: const Color(0xFF8B6914),
                                  fontWeight: FontWeight.w600)),
                        ),
                        TextButton(
                          onPressed: activosCount > 0
                              ? () => ajustes.deseleccionarTodos()
                              : null,
                          child: Text('Ninguno',
                              style: GoogleFonts.lato(
                                  color: activosCount > 0
                                      ? const Color(0xFF8B6914)
                                      : Colors.grey,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),

                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFD4AF6A)
                            .withValues(alpha: isDark ? 0.4 : 0.8),
                      ),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: autores.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        indent: 72,
                        color: const Color(0xFFD4AF6A).withValues(alpha: 0.3),
                      ),
                      itemBuilder: (context, i) {
                        final autor = autores[i];
                        final activo = ajustes.estaActivo(autor);
                        return ListTile(
                          leading: Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: activo
                                  ? const Color(0xFF3B2F2F)
                                  : Colors.grey[isDark ? 700 : 300],
                            ),
                            child: Center(
                              child: Text(
                                autor.isNotEmpty
                                    ? autor[0].toUpperCase()
                                    : '?',
                                style: GoogleFonts.playfairDisplay(
                                  color: activo
                                      ? Colors.white
                                      : Colors.grey,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            autor,
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: activo ? textColor : Colors.grey,
                            ),
                          ),
                          trailing: Switch(
                            value: activo,
                            onChanged: (_) => ajustes.toggleAutor(autor),
                            activeThumbColor: const Color(0xFF8B6914),
                            activeTrackColor: const Color(0xFFD4AF6A)
                                .withValues(alpha: 0.4),
                          ),
                          onTap: () => ajustes.toggleAutor(autor),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Seccion extends StatelessWidget {
  final String titulo;
  final bool isDark;
  const _Seccion({required this.titulo, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Text(
        titulo.toUpperCase(),
        style: GoogleFonts.lato(
          fontSize: 11,
          letterSpacing: 2,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF8B6914),
        ),
      ),
    );
  }
}

class _OpcionTema extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final IconData icono;
  final bool seleccionado;
  final VoidCallback onTap;
  final Color textColor;
  final bool isDark;

  const _OpcionTema({
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    required this.seleccionado,
    required this.onTap,
    required this.textColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icono,
          color: seleccionado
              ? const Color(0xFF8B6914)
              : Colors.grey),
      title: Text(titulo,
          style: GoogleFonts.lato(
            fontSize: 15,
            fontWeight:
                seleccionado ? FontWeight.w600 : FontWeight.normal,
            color: seleccionado ? textColor : Colors.grey,
          )),
      subtitle: Text(subtitulo,
          style: GoogleFonts.lato(
              fontSize: 12, color: Colors.grey)),
      trailing: seleccionado
          ? const Icon(Icons.check_circle,
              color: Color(0xFF8B6914), size: 22)
          : const Icon(Icons.radio_button_unchecked,
              color: Colors.grey, size: 22),
    );
  }
}
