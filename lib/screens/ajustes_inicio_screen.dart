import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/ajustes_provider.dart';

class AjustesInicioScreen extends StatelessWidget {
  const AjustesInicioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF6EC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3B2F2F),
        foregroundColor: Colors.white,
        title: Text(
          'Poemas del día',
          style: GoogleFonts.playfairDisplay(
              fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFF8B6914), height: 1),
        ),
      ),
      body: Consumer<AjustesProvider>(
        builder: (context, ajustes, _) {
          final autores = ajustes.todosLosAutores;
          final activosCount = ajustes.autoresActivos.length;

          return Column(
            children: [
              // Cabecera informativa
              Container(
                width: double.infinity,
                color: const Color(0xFF3B2F2F),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Text(
                  'Elige los autores de los que quieres\nrecibir poemas aleatorios cada día',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lato(
                    color: const Color(0xFFD4AF6A),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),

              // Barra de acciones rápidas
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Text(
                      '$activosCount de ${autores.length} seleccionados',
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
                    const SizedBox(width: 4),
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

              Divider(height: 1, color: const Color(0xFFD4AF6A).withValues(alpha: 0.4)),

              // Lista de autores
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
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
                              : Colors.grey[300],
                        ),
                        child: Center(
                          child: Text(
                            autor.isNotEmpty
                                ? autor[0].toUpperCase()
                                : '?',
                            style: GoogleFonts.playfairDisplay(
                              color: activo ? Colors.white : Colors.grey,
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
                          color: activo
                              ? const Color(0xFF3B2F2F)
                              : Colors.grey,
                        ),
                      ),
                      trailing: Switch(
                        value: activo,
                        onChanged: (_) => ajustes.toggleAutor(autor),
                        activeColor: const Color(0xFF8B6914),
                        activeTrackColor:
                            const Color(0xFFD4AF6A).withValues(alpha: 0.4),
                      ),
                      onTap: () => ajustes.toggleAutor(autor),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
