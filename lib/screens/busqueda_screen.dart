import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/poema.dart';
import '../utils/app_text_styles.dart';
import '../widgets/nav_bar_controller.dart';
import 'poema_screen.dart';

class BusquedaScreen extends StatefulWidget {
  final List<Poema> poemas;
  final List<Poema> todosLosPoemas;
  const BusquedaScreen(
      {super.key, required this.poemas, required this.todosLosPoemas});

  @override
  State<BusquedaScreen> createState() => _BusquedaScreenState();
}

class _BusquedaScreenState extends State<BusquedaScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  String _query = '';
  List<Poema> _resultados = [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
  }

  void _onQueryChanged() {
    final v = _controller.text;
    if (v == _query) return;
    final nuevos = _calcularResultados(v);
    setState(() {
      _query = v;
      _resultados = nuevos;
    });
    if (v.trim().isEmpty) {
      NavBarControllerScope.of(context)?.showNavBar();
    }
  }

  List<Poema> _calcularResultados(String raw) {
    final q = raw.trim().toLowerCase();
    if (q.isEmpty) return [];
    return widget.poemas.where((p) {
      return p.titulo.toLowerCase().contains(q) ||
          p.autor.toLowerCase().contains(q) ||
          p.texto.toLowerCase().contains(q);
    }).toList();
  }

  String _fragmentoConTexto(Poema p, String q) {
    final idx = p.texto.toLowerCase().indexOf(q);
    if (idx == -1) return '';
    final inicio = (idx - 40).clamp(0, p.texto.length);
    final fin = (idx + q.length + 40).clamp(0, p.texto.length);
    final frag = p.texto.substring(inicio, fin).replaceAll('\n', ' ');
    return '…${frag.trim()}…';
  }

  @override
  void dispose() {
    _controller.removeListener(_onQueryChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? const Color(0xFFF5E6C8) : const Color(0xFF3B2F2F);
    final q = _query.trim().toLowerCase();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // En móvil: false porque keyboard_height gestiona el padding manualmente.
      // En web: true para que el navegador maneje el teclado virtual de forma nativa.
      resizeToAvoidBottomInset: kIsWeb,
      appBar: AppBar(
        backgroundColor: const Color(0xFF3B2F2F),
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('Buscar', style: AppTextStyles.appBarTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: SearchBar(
              controller: _controller,
              focusNode: _focusNode,
              hintText: 'Buscar por título, autor o verso…',
              hintStyle: WidgetStateProperty.all(AppTextStyles.searchHint),
              textStyle: WidgetStateProperty.all(AppTextStyles.searchText),
              leading: const Icon(Icons.search, color: Color(0xFFD4AF6A)),
              trailing: _query.isNotEmpty
                  ? [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        tooltip: 'Borrar búsqueda',
                        onPressed: () {
                          _controller.clear();
                          NavBarControllerScope.of(context)?.showNavBar();
                        },
                      )
                    ]
                  : null,
              backgroundColor: WidgetStateProperty.all(Colors.white10),
              surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
              shadowColor: WidgetStateProperty.all(Colors.transparent),
              overlayColor: WidgetStateProperty.all(Colors.transparent),
              shape: WidgetStateProperty.all(RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
              padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 8)),
            ),
          ),
        ),
      ),
      body: _buildBody(q, textColor, isDark),
    );
  }

  Widget _buildBody(String q, Color textColor, bool isDark) {
    if (q.isEmpty) {
      // FIX CENTRADO: Center + Column con mainAxisSize.min y crossAxisAlignment.center
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.search, size: 56, color: Color(0xFFD4AF6A)),
            const SizedBox(height: 16),
            Text('Escribe para buscar',
                textAlign: TextAlign.center,
                style: GoogleFonts.playfairDisplay(
                    fontSize: 18, color: textColor)),
            const SizedBox(height: 8),
            Text('Busca por título, autor o cualquier verso',
                textAlign: TextAlign.center,
                style: AppTextStyles.poemaCount),
          ],
        ),
      );
    }

    if (_resultados.isEmpty) {
      return Center(
        child: Text('Sin resultados para "$_query"',
            textAlign: TextAlign.center,
            style: AppTextStyles.poemaCount),
      );
    }

    return ListView.builder(
      key: ValueKey(q),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      itemCount: _resultados.length,
      itemBuilder: (context, i) {
        final p = _resultados[i];
        final enTexto = !p.titulo.toLowerCase().contains(q) &&
            !p.autor.toLowerCase().contains(q);
        return _ResultadoCard(
          key: ValueKey(p.id),
          poema: p,
          query: q,
          todosLosPoemas: widget.todosLosPoemas,
          fragmento: enTexto ? _fragmentoConTexto(p, q) : null,
        );
      },
    );
  }
}

class _ResultadoCard extends StatelessWidget {
  final Poema poema;
  final String query;
  final String? fragmento;
  final List<Poema> todosLosPoemas;

  const _ResultadoCard({
    super.key,
    required this.poema,
    required this.query,
    required this.todosLosPoemas,
    this.fragmento,
  });

  static const _shadowLight = [
    BoxShadow(color: Color(0x12795548), blurRadius: 6, offset: Offset(0, 3)),
  ];
  static const _shadowDark = [
    BoxShadow(color: Color(0x4D000000), blurRadius: 6, offset: Offset(0, 3)),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2A1F18) : Colors.white;
    final textColor =
        isDark ? const Color(0xFFF5E6C8) : const Color(0xFF3B2F2F);
    final subColor = isDark ? Colors.white38 : const Color(0xFF555555);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: const Color(0xFFD4AF6A)
                .withValues(alpha: isDark ? 0.4 : 1.0)),
        boxShadow: isDark ? _shadowDark : _shadowLight,
      ),
      child: MergeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
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
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ExcludeSemantics(
                      child: Icon(Icons.menu_book_outlined,
                          size: 18, color: Color(0xFF8B6914))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HighlightText(
                            text: poema.etiqueta,
                            query: query,
                            style: GoogleFonts.playfairDisplay(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: textColor)),
                        if (poema.titulo.isNotEmpty &&
                            poema.primerVerso.isNotEmpty &&
                            poema.primerVerso != poema.titulo)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text('«${poema.primerVerso}»',
                                style: GoogleFonts.lato(
                                    fontSize: 12,
                                    color: subColor,
                                    fontStyle: FontStyle.italic),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        const SizedBox(height: 3),
                        _HighlightText(
                            text: poema.autor,
                            query: query,
                            style: GoogleFonts.lato(
                                fontSize: 12,
                                color: const Color(0xFF8B6914),
                                fontStyle: FontStyle.italic)),
                        if (fragmento != null && fragmento!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: _HighlightText(
                                text: fragmento!,
                                query: query,
                                style: GoogleFonts.lato(
                                    fontSize: 12,
                                    color: subColor,
                                    height: 1.5)),
                          ),
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
      ),
    );
  }
}

class _HighlightText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle style;
  const _HighlightText(
      {required this.text, required this.query, required this.style});

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) return Text(text, style: style);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lower = text.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;
    while (true) {
      final idx = lower.indexOf(query, start);
      if (idx == -1) {
        spans.add(TextSpan(text: text.substring(start), style: style));
        break;
      }
      if (idx > start) {
        spans.add(TextSpan(text: text.substring(start, idx), style: style));
      }
      spans.add(TextSpan(
        text: text.substring(idx, idx + query.length),
        style: style.copyWith(
          color: const Color(0xFF8B6914),
          fontWeight: FontWeight.bold,
          backgroundColor: isDark
              ? const Color(0xFF8B6914).withValues(alpha: 0.25)
              : const Color(0xFFFFF3CD),
        ),
      ));
      start = idx + query.length;
    }
    return RichText(text: TextSpan(children: spans));
  }
}
