import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/poema.dart';
import '../data/poema_repository.dart';
import '../domain/orden_titulos.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/poema_colors.dart';
import '../theme/poema_theme.dart';
import '../utils/navegacion.dart';
import '../widgets/nav_bar_scope.dart';
import '../widgets/poema_list_tile.dart';

/// Full-text search.
///
/// The original lowercased every poem's entire body on every keystroke, on the
/// UI thread. Three changes:
///
/// * the corpus is folded once at load into [Poema.indiceBusqueda];
/// * input is debounced, so a fast typist triggers one pass rather than twelve;
/// * matching is diacritic-insensitive, so "cancion" finds "canción" and
///   "Becquer" finds "Bécquer" — which readers on a plain keyboard expect.
class BusquedaScreen extends StatefulWidget {
  const BusquedaScreen({super.key});

  @override
  State<BusquedaScreen> createState() => _BusquedaScreenState();
}

class _BusquedaScreenState extends State<BusquedaScreen> {
  static const _retardo = Duration(milliseconds: 180);

  final _controlador = TextEditingController();
  final _focus = FocusNode();

  Timer? _debounce;
  String _consulta = '';
  List<Poema> _resultados = const [];

  @override
  void initState() {
    super.initState();
    _controlador.addListener(_alEscribir);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controlador
      ..removeListener(_alEscribir)
      ..dispose();
    _focus.dispose();
    super.dispose();
  }

  void _alEscribir() {
    final texto = _controlador.text;
    if (texto.trim().isEmpty) {
      _debounce?.cancel();
      NavBarScope.of(context)?.mostrarNavBar();
      if (_consulta.isNotEmpty) {
        setState(() {
          _consulta = '';
          _resultados = const [];
        });
      }
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(_retardo, () => _buscar(texto));
  }

  void _buscar(String texto) {
    final aguja = plegarParaOrden(texto.trim());
    if (aguja == _consulta) return;
    final anthology = context.read<Anthology>();
    final encontrados = [
      for (final p in anthology.poemas)
        if (p.indiceBusqueda.contains(aguja)) p,
    ];
    if (!mounted) return;
    setState(() {
      _consulta = aguja;
      _resultados = encontrados;
    });
  }

  /// ~40 characters either side of the match, for hits in the body.
  String _fragmento(Poema p) {
    final idx = p.indiceBusqueda.indexOf(_consulta);
    if (idx == -1) return '';
    // indiceBusqueda is "titulo autor texto"; offset back into the body.
    final desplazamiento =
        plegarParaOrden('${p.titulo} ${p.autor} ').length;
    final enTexto = idx - desplazamiento;
    if (enTexto < 0 || enTexto >= p.texto.length) return '';
    final inicio = (enTexto - 40).clamp(0, p.texto.length);
    final fin = (enTexto + _consulta.length + 40).clamp(0, p.texto.length);
    return '…${p.texto.substring(inicio, fin).replaceAll('\n', ' ').trim()}…';
  }

  bool _coincideEnCabecera(Poema p) =>
      plegarParaOrden(p.titulo).contains(_consulta) ||
      plegarParaOrden(p.autor).contains(_consulta);

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final t = context.tipos;
    final l10n = L10n.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.buscarTitulo,
            style: t.appBarTitulo.copyWith(color: c.sobreSepia)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: SearchBar(
              controller: _controlador,
              focusNode: _focus,
              hintText: l10n.buscarPista,
              textInputAction: TextInputAction.search,
              hintStyle: WidgetStatePropertyAll(
                  t.cuerpo.copyWith(color: c.sobreSepia.withValues(alpha: .38))),
              textStyle:
                  WidgetStatePropertyAll(t.cuerpo.copyWith(color: c.sobreSepia)),
              leading: Icon(Icons.search, color: c.oroClaro),
              trailing: [
                if (_controlador.text.isNotEmpty)
                  IconButton(
                    tooltip: l10n.buscarBorrar,
                    icon: Icon(Icons.close,
                        color: c.sobreSepia.withValues(alpha: .54)),
                    onPressed: () {
                      _controlador.clear();
                      NavBarScope.of(context)?.mostrarNavBar();
                    },
                  ),
              ],
              backgroundColor:
                  WidgetStatePropertyAll(c.sobreSepia.withValues(alpha: .10)),
              surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
              shadowColor: const WidgetStatePropertyAll(Colors.transparent),
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
              padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 8)),
            ),
          ),
        ),
      ),
      body: _cuerpo(l10n),
    );
  }

  Widget _cuerpo(L10n l10n) {
    final c = context.colores;
    final t = context.tipos;

    if (_consulta.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 56, color: c.oroClaro),
            const SizedBox(height: 16),
            Text(l10n.buscarVacioTitulo,
                textAlign: TextAlign.center,
                style: t.tituloTarjeta.copyWith(color: c.texto)),
            const SizedBox(height: 8),
            Text(l10n.buscarVacioSubtitulo,
                textAlign: TextAlign.center,
                style: t.cuerpoPequeno.copyWith(color: c.oro)),
          ],
        ),
      );
    }

    if (_resultados.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.buscarSinResultados(_controlador.text.trim()),
            textAlign: TextAlign.center,
            style: t.cuerpo.copyWith(color: c.textoSuave),
          ),
        ),
      );
    }

    return ListView.builder(
      // Resetting the scroll position on a new query: without this the list
      // stays halfway down when the results change under it.
      key: ValueKey(_consulta),
      padding:
          EdgeInsets.fromLTRB(14, 10, 14, espacioBarraFlotante(context)),
      itemCount: _resultados.length,
      itemBuilder: (context, i) {
        final p = _resultados[i];
        return TarjetaPoemario(
          margen: const EdgeInsets.only(bottom: 10),
          radio: 10,
          child: PoemaListTile(
            key: ValueKey(p.id),
            poema: p,
            consulta: _consulta,
            mostrarAutor: true,
            fragmento: _coincideEnCabecera(p) ? null : _fragmento(p),
          ),
        );
      },
    );
  }
}
