import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/poema.dart';
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
  String _query = '';

  List<Poema> get _resultados {
    if (_query.trim().isEmpty) return [];
    final q = _query.toLowerCase();
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
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resultados = _resultados;
    final q = _query.toLowerCase();

    return Scaffold(
      backgroundColor: const Color(0xFFFDF6EC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3B2F2F),
        foregroundColor: Colors.white,
        title: Text('Buscar',
            style: GoogleFonts.playfairDisplay(
                fontSize: 22, fontWeight: FontWeight.bold)),
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
            color: const Color(0xFF3B2F2F),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: SearchBar(
              controller: _controller,
              hintText: 'Buscar por título, autor o verso…',
              hintStyle: WidgetStateProperty.all(
                  GoogleFonts.lato(color: Colors.white38)),
              textStyle: WidgetStateProperty.all(
                  GoogleFonts.lato(color: Colors.white)),
              leading: const Icon(Icons.search, color: Color(0xFFD4AF6A)),
              trailing: _query.isNotEmpty
                  ? [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: () {
                          _controller.clear();
                          setState(() => _query = '');
                        },
                      )
                    ]
                  : null,
              backgroundColor:
                  WidgetStateProperty.all(Colors.white10),
              surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
              shadowColor: WidgetStateProperty.all(Colors.transparent),
              shape: WidgetStateProperty.all(RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
              padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 8)),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: _query.trim().isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.search,
                            size: 56, color: Color(0xFFD4AF6A)),
                        const SizedBox(height: 16),
                        Text('Escribe para buscar',
                            style: GoogleFonts.playfairDisplay(
                                fontSize: 18,
                                color: const Color(0xFF3B2F2F))),
                        const SizedBox(height: 8),
                        Text(
                          'Busca por título, autor o cualquier verso',
                          style: GoogleFonts.lato(
                              fontSize: 13,
                              color: const Color(0xFF8B6914)),
                        ),
                      ],
                    ),
                  )
                : resultados.isEmpty
                    ? Center(
                        child: Text(
                          'Sin resultados para "$_query"',
                          style: GoogleFonts.lato(
                              fontSize: 15,
                              color: const Color(0xFF8B6914)),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        itemCount: resultados.length,
                        itemBuilder: (context, i) {
                          final p = resultados[i];
                          final enTexto =
                              !p.titulo.toLowerCase().contains(q) &&
                                  !p.autor.toLowerCase().contains(q);
                          return _ResultadoCard(
                            poema: p,
                            query: q,
                            todosLosPoemas: widget.todosLosPoemas,
                            fragmento:
                                enTexto ? _fragmentoConTexto(p, q) : null,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _ResultadoCard extends StatelessWidget {
  final Poema poema;
  final String query;
  final String? fragmento;
  final List<Poema> todosLosPoemas;

  const _ResultadoCard({
    required this.poema,
    required this.query,
    required this.todosLosPoemas,
    this.fragmento,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD4AF6A)),
        boxShadow: [
          BoxShadow(
            color: Colors.brown.withValues(alpha: 0.07),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
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
                const Icon(Icons.menu_book_outlined,
                    size: 18, color: Color(0xFF8B6914)),
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
                          color: const Color(0xFF3B2F2F),
                        ),
                      ),
                      if (poema.titulo.isNotEmpty &&
                          poema.primerVerso.isNotEmpty &&
                          poema.primerVerso != poema.titulo)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '«${poema.primerVerso}»',
                            style: GoogleFonts.lato(
                              fontSize: 12,
                              color: Colors.grey[500],
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      const SizedBox(height: 3),
                      _HighlightText(
                        text: poema.autor,
                        query: query,
                        style: GoogleFonts.lato(
                          fontSize: 12,
                          color: const Color(0xFF8B6914),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      if (fragmento != null && fragmento!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: _HighlightText(
                            text: fragmento!,
                            query: query,
                            style: GoogleFonts.lato(
                              fontSize: 12,
                              color: Colors.grey[600],
                              height: 1.5,
                            ),
                          ),
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
    );
  }
}

class _HighlightText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle style;

  const _HighlightText({
    required this.text,
    required this.query,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) return Text(text, style: style);

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
          backgroundColor: const Color(0xFFFFF3CD),
        ),
      ));
      start = idx + query.length;
    }

    return RichText(text: TextSpan(children: spans));
  }
}
