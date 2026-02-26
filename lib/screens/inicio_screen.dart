import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/poema.dart';
import '../providers/ajustes_provider.dart';
import '../utils/app_text_styles.dart';
import 'poema_screen.dart';
import 'ajustes_inicio_screen.dart';

class InicioScreen extends StatefulWidget {
  final List<Poema> poemas;
  const InicioScreen({super.key, required this.poemas});

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> {
  // ⚡ Fecha y cadena calculadas una sola vez
  late final String _fechaStr;

  @override
  void initState() {
    super.initState();
    final hoy = DateTime.now();
    const meses = ['','enero','febrero','marzo','abril','mayo','junio',
        'julio','agosto','septiembre','octubre','noviembre','diciembre'];
    _fechaStr = '${hoy.day} de ${meses[hoy.month]} de ${hoy.year}';
  }

  int _semilla(DateTime fecha) =>
      fecha.year * 100000 + fecha.month * 1000 + fecha.day;

  int _rand(int s) => ((s * 1664525 + 1013904223) & 0x7FFFFFFF);

  List<Poema> _poemasDelDia(List<Poema> pool) {
    if (pool.isEmpty) return [];
    if (pool.length == 1) return [pool[0]];
    final hoy  = DateTime.now();
    final ayer = hoy.subtract(const Duration(days: 1));
    final semHoy  = _semilla(hoy);
    final semAyer = _semilla(ayer);
    final autorExcluidoAyer = pool[_rand(semAyer) % pool.length].autor;
    final poolAyer =
        pool.where((p) => p.autor != autorExcluidoAyer).toList();
    final p1Ayer = poolAyer.isNotEmpty
        ? poolAyer[_rand(semAyer) % poolAyer.length]
        : pool[_rand(semAyer) % pool.length];
    final autorAyer = p1Ayer.autor;
    final poolHoy = pool.where((p) => p.autor != autorAyer).toList();
    final p1 = poolHoy.isNotEmpty
        ? poolHoy[_rand(semHoy) % poolHoy.length]
        : pool[_rand(semHoy) % pool.length];
    final poolP2 = pool.where((p) => p.autor != p1.autor).toList();
    final p2pool = poolP2.isNotEmpty
        ? poolP2
        : pool.where((p) => p.id != p1.id).toList();
    if (p2pool.isEmpty) return [p1];
    final p2 = p2pool[_rand(_rand(semHoy)) % p2pool.length];
    return [p1, p2];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? const Color(0xFF1A1210) : const Color(0xFFFDF6EC);
    final titleColor =
        isDark ? const Color(0xFFF5E6C8) : const Color(0xFF3B2F2F);
    final subColor =
        isDark ? Colors.white54 : const Color(0xFF666666);

    // ⚡ selector: solo reconstruye este widget cuando autoresActivos cambia
    final ajustes = context.watch<AjustesProvider>();
    final pool = ajustes.autoresActivos.isEmpty
        ? <Poema>[]
        : widget.poemas
            .where((p) => ajustes.autoresActivos.contains(p.autor))
            .toList();
    // ⚡ _poemasDelDia es determinista para el mismo día y pool,
    //    el resultado es siempre el mismo dentro de una sesión
    final destacados = _poemasDelDia(pool);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF3B2F2F),
        foregroundColor: Colors.white,
        title: Text('Antología Poética', style: AppTextStyles.appBarTitle),
        centerTitle: true,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFF8B6914), height: 1),
        ),
        actions: [
          IconButton(
            tooltip: 'Filtrar autores',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.tune,
                color: Color(0xFFD4AF6A),
                size: 22,
                semanticLabel: 'Filtrar autores del día'),
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AjustesInicioScreen())),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(_fechaStr,
                style: AppTextStyles.labelDoradoSmall
                    .copyWith(letterSpacing: 2)),
            const SizedBox(height: 6),
            Text('Poemas del día',
                style: isDark
                    ? AppTextStyles.inicioDayTitleDark
                    : AppTextStyles.inicioDayTitle),
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
                  fontSize: 11, color: subColor, letterSpacing: 0.5),
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
                            fontSize: 18, color: titleColor)),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.tune,
                          color: Color(0xFF8B6914)),
                      label: Text('Configurar autores',
                          style: GoogleFonts.lato(
                              color: const Color(0xFF8B6914))),
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const AjustesInicioScreen())),
                    ),
                  ],
                ),
              )
            else
              ...destacados.map((p) => _TarjetaPoema(
                  key: ValueKey(p.id),
                  poema: p,
                  todosLosPoemas: widget.poemas)),
          ],
        ),
      ),
    );
  }
}

class _TarjetaPoema extends StatelessWidget {
  final Poema poema;
  final List<Poema> todosLosPoemas;
  const _TarjetaPoema(
      {super.key, required this.poema, required this.todosLosPoemas});

  // ⚡ Sombras static: se crean una sola vez para toda la app
  static const _shadowLight = [
    BoxShadow(
        color: Color(0x17795548), blurRadius: 12, offset: Offset(0, 4))
  ];
  static const _shadowDark = [
    BoxShadow(
        color: Color(0x4D000000), blurRadius: 12, offset: Offset(0, 4))
  ];

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2A1F18) : Colors.white;
    final versoColor =
        isDark ? const Color(0xFFF5E6C8) : const Color(0xFF4A3728);
    final fragmento = _fragmento();

    return MergeSemantics(
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFD4AF6A)),
          boxShadow: isDark ? _shadowDark : _shadowLight,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Material(
            color: cardColor,
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => PoemaScreen(
                      poema: poema, todosLosPoemas: todosLosPoemas),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(poema.etiqueta,
                            style: AppTextStyles.cardTitleWhite),
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
                            style: AppTextStyles.autorItalicDorado),
                      ],
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(18, 16, 18, 6),
                    child: Text(fragmento,
                        style: GoogleFonts.lato(
                            fontSize: 15,
                            height: 1.85,
                            color: versoColor)),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding:
                          const EdgeInsets.only(right: 8, bottom: 6),
                      child: TextButton.icon(
                        onPressed: null,
                        icon: const ExcludeSemantics(
                            child: Icon(Icons.menu_book_outlined,
                                size: 16, color: Color(0xFF8B6914))),
                        label: Text('Leer poema completo',
                            style: GoogleFonts.lato(
                                fontSize: 13,
                                color: const Color(0xFF8B6914),
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
