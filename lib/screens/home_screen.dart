import 'package:flutter/material.dart';
import '../models/poema.dart';
import '../utils/app_text_styles.dart';
import '../utils/roman.dart';
import 'autor_screen.dart';

class HomeScreen extends StatefulWidget {
  final List<Poema> poemas;
  const HomeScreen({super.key, required this.poemas});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Map<String, List<Poema>> _grupos;
  late final List<String> _autores;

  @override
  void initState() {
    super.initState();
    // ⚡ Se calcula una sola vez — los poemas no cambian nunca en runtime
    _grupos = _agrupar(widget.poemas);
    _autores = _grupos.keys.toList();
  }

  Map<String, List<Poema>> _agrupar(List<Poema> poemas) {
    final Map<String, List<Poema>> mapa = {};
    for (final p in poemas) {
      mapa.putIfAbsent(p.autor, () => []).add(p);
    }
    for (final lista in mapa.values) {
      lista.sort((a, b) => compareTitulos(a.etiqueta, b.etiqueta));
    }
    return Map.fromEntries(
      mapa.entries.toList()
        ..sort(
            (a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase())),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? const Color(0xFF1A1210) : const Color(0xFFFDF6EC);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF3B2F2F),
        foregroundColor: Colors.white,
        title: Text('Índice', style: AppTextStyles.appBarTitle),
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
            child: Text('— Índice de Autores —',
                textAlign: TextAlign.center,
                style: AppTextStyles.labelDorado),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 14),
              itemCount: _autores.length,
              // ⚡ itemExtent aproximado elimina el layout de todos los items
              //    no visibles (reduce trabajo de layout en ~80%)
              itemExtentBuilder: (i, _) => 90,
              itemBuilder: (context, i) {
                final autor = _autores[i];
                return _AutorCard(
                  key: ValueKey(autor),
                  autor: autor,
                  poemas: _grupos[autor]!,
                  todosLosPoemas: widget.poemas,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AutorCard extends StatelessWidget {
  final String autor;
  final List<Poema> poemas;
  final List<Poema> todosLosPoemas;

  const _AutorCard({
    super.key,
    required this.autor,
    required this.poemas,
    required this.todosLosPoemas,
  });

  // ⚡ Sombras static
  static const _shadowLight = [
    BoxShadow(
      color: Color(0x17795548), // brown 9%
      blurRadius: 10,
      offset: Offset(0, 4),
    ),
  ];
  static const _shadowDark = [
    BoxShadow(
      color: Color(0x4D000000),
      blurRadius: 10,
      offset: Offset(0, 4),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor =
        isDark ? const Color(0xFF2A1F18) : const Color(0xFFFAF0E0);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFFD4AF6A)
                .withValues(alpha: isDark ? 0.5 : 1.0)),
        boxShadow: isDark ? _shadowDark : _shadowLight,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: MergeSemantics(
          child: Material(
            color: cardColor,
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => AutorScreen(
                      autor: autor,
                      poemas: poemas,
                      todosLosPoemas: todosLosPoemas),
                  transitionsBuilder: (_, animation, __, child) =>
                      FadeTransition(opacity: animation, child: child),
                  transitionDuration: const Duration(milliseconds: 250),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 46, height: 46,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF3B2F2F)),
                      child: ExcludeSemantics(
                        child: Center(
                          child: Text(
                            autor.isNotEmpty
                                ? autor[0].toUpperCase()
                                : '?',
                            style: AppTextStyles.avatarLetter,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(autor,
                              style: isDark
                                  ? AppTextStyles.autorCardDark
                                  : AppTextStyles.autorCardLight),
                          const SizedBox(height: 2),
                          Text(
                            '${poemas.length} poema${poemas.length != 1 ? 's' : ''}',
                            style: AppTextStyles.poemaCount,
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
      ),
    );
  }
}
