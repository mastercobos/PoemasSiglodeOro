import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/poema.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/favoritos_provider.dart';
import '../theme/poema_colors.dart';
import '../theme/poema_theme.dart';
import '../utils/compartir_poema.dart';
import '../config/app_config.dart';
import '../widgets/texto_de_poema.dart';
import '../widgets/versos_ajustados.dart';
import '../widgets/autor_link.dart';
import '../widgets/linea_oro.dart';
import '../widgets/ornamento.dart';
import '../widgets/pellizco.dart';

/// Reading view for a single poem.
///
/// Changes worth knowing about:
///
/// * stanza breaks come from [Poema.estrofas], i.e. from the blank lines in
///   the source. The old screen deleted those, then re-inserted breaks after
///   lines 4, 8 and 11 — a sonnet's shape imposed on every poem in the book;
/// * text scaling is no longer clamped here. It was capped at 1.15, on the one
///   screen where a low-vision reader most needs large type;
/// * `todosLosPoemas` is gone from the constructor — the anthology comes from
///   a provider;
/// * the favourite snackbar wording is derived from the value the toggle
///   returns rather than from the pre-toggle read, which could show the
///   opposite message if a rebuild landed in between.
///
/// Pinching magnifies the page as a picture: the poem keeps its lines and
/// shape, and one finger pans it both ways. Text size proper is the system
/// setting, which the page follows; the magnification starts at 1× for every
/// poem and isn't saved. The text stays selectable when magnified.
class PoemaScreen extends StatefulWidget {
  final Poema poema;

  const PoemaScreen({super.key, required this.poema});

  @override
  State<PoemaScreen> createState() => _PoemaScreenState();
}

class _PoemaScreenState extends State<PoemaScreen> {
  static const _aumentoMaximo = 3.0;

  /// Read to anchor the iPad share popover.
  final _claveBotonCompartir = GlobalKey();
  bool _compartiendo = false;

  final _vertical = ScrollController();
  final _horizontal = ScrollController();
  late final _fisica = _FisicaPellizco(() => _pellizcando);

  double _aumento = 1;
  bool _pellizcando = false;

  // At the start of a pinch: the magnification, and the point of the page
  // between the fingers, at 1×.
  double _aumentoInicial = 1;
  Offset _puntoInicial = Offset.zero;

  Poema get _poema => widget.poema;

  @override
  void dispose() {
    _vertical.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  Offset get _desplazamiento => Offset(
        _horizontal.hasClients ? _horizontal.offset : 0,
        _vertical.hasClients ? _vertical.offset : 0,
      );

  void _empezarPellizco(Offset foco) {
    _pellizcando = true;
    _aumentoInicial = _aumento;
    _puntoInicial = (_desplazamiento + foco) / _aumento;
  }

  void _pellizcar(double escala, Offset foco) {
    final aumento =
        (_aumentoInicial * escala).clamp(1.0, _aumentoMaximo).toDouble();
    setState(() => _aumento = aumento);
    // The point that was between the fingers stays between them, wherever
    // they have moved: pinching also pans.
    final destino = _puntoInicial * aumento - foco;
    if (_horizontal.hasClients) _horizontal.jumpTo(math.max(0, destino.dx));
    if (_vertical.hasClients) _vertical.jumpTo(math.max(0, destino.dy));
    // Shrinking can leave either scroll past its new end; pull it back once
    // the page is laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in [_horizontal, _vertical]) {
        if (c.hasClients && c.offset > c.position.maxScrollExtent) {
          c.jumpTo(c.position.maxScrollExtent);
        }
      }
    });
  }

  void _terminarPellizco() => _pellizcando = false;

  Rect _rectBotonCompartir() {
    final box =
        _claveBotonCompartir.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      return box.localToGlobal(Offset.zero) & box.size;
    }
    final size = MediaQuery.sizeOf(context);
    return Rect.fromLTWH(size.width - 60, 0, 60, 60);
  }

  Future<void> _compartir() async {
    if (_compartiendo) return;
    setState(() => _compartiendo = true);
    unawaited(HapticFeedback.lightImpact());
    try {
      await _poema.cargarTexto(); // the card and the text share need it
      if (!mounted) return;
      await CompartirPoema.compartir(
        context: context,
        poema: _poema,
        origen: _rectBotonCompartir(),
        mensajeError: L10n.of(context).compartirError,
      );
    } finally {
      if (mounted) setState(() => _compartiendo = false);
    }
  }

  Future<void> _alternarFavorito() async {
    final l10n = L10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    unawaited(HapticFeedback.mediumImpact());

    final guardado = await context.read<FavoritosProvider>().alternar(_poema);
    if (!mounted) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content:
            Text(guardado ? l10n.favoritosAnadido : l10n.favoritosEliminado),
        duration: const Duration(seconds: 2),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final t = context.tipos;
    final l10n = L10n.of(context);

    // `select` instead of a Consumer over the whole screen: only the heart
    // rebuilds when favourites change.
    final esFavorito = context.select<FavoritosProvider, bool>(
      (f) => f.esFavorito(_poema),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_poema.etiqueta,
            style: t.appBarTituloPequeno.copyWith(color: c.sobreSepia),
            overflow: TextOverflow.ellipsis),
        bottom: const LineaOro(),
        actions: [
          IconButton(
            key: _claveBotonCompartir,
            tooltip: l10n.compartirTitulo(_poema.etiqueta),
            onPressed: _compartiendo ? null : _compartir,
            icon: _compartiendo
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: c.sobreSepia),
                  )
                : Icon(Icons.share_outlined, color: c.sobreSepia),
          ),
          IconButton(
            tooltip: esFavorito
                ? l10n.favoritosQuitar(_poema.etiqueta)
                : l10n.favoritosAnadir(_poema.etiqueta),
            onPressed: _alternarFavorito,
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Icon(
                esFavorito ? Icons.favorite : Icons.favorite_border,
                key: ValueKey(esFavorito),
                color: esFavorito ? c.oroClaro : c.sobreSepia,
                semanticLabel: esFavorito
                    ? l10n.favoritosGuardado
                    : l10n.favoritosNoGuardado,
              ),
            ),
          ),
        ],
      ),
      body: Pellizco(
        alEmpezar: _empezarPellizco,
        alCambiar: _pellizcar,
        alTerminar: _terminarPellizco,
        child: LayoutBuilder(
          builder: (context, limites) => SingleChildScrollView(
            controller: _vertical,
            physics: _fisica,
            child: SingleChildScrollView(
              controller: _horizontal,
              physics: _fisica,
              scrollDirection: Axis.horizontal,
              child: _Lupa(
                aumento: _aumento,
                ancho: limites.maxWidth,
                child: _pagina(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The page as laid out at 1×.
  Widget _pagina(BuildContext context) {
    final c = context.colores;
    final t = context.tipos;
    final l10n = L10n.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 36, 28, 48),
      child: Column(
        children: [
          const Ornamento(),
          const SizedBox(height: 28),
          SelectableText(
            _poema.etiqueta,
            textAlign: TextAlign.center,
            style: t.tituloPoema.copyWith(color: c.texto),
          ),
          if (_poema.mostrarPrimerVerso)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: SelectableText(
                '«${_poema.primerVersoSinComillas}»',
                textAlign: TextAlign.center,
                style: t.cuerpoPequeno.copyWith(
                    fontSize: 13,
                    color: c.textoSuave,
                    fontStyle: FontStyle.italic),
              ),
            ),
          const SizedBox(height: 6),
          AutorLink(autor: _poema.autor),
          const SizedBox(height: 26),
          const Filete(),
          const SizedBox(height: 34),
          Semantics(
            label: l10n.semPoema(_poema.etiqueta, _poema.autor),
            child: TextoDePoema(
              poema: _poema,
              builder: (_) => _CuerpoPoema(
                poema: _poema,
                estilo: t.verso.copyWith(color: c.texto),
              ),
            ),
          ),
          const SizedBox(height: 52),
          const Ornamento(),
        ],
      ),
    );
  }
}

/// [child] laid out at [ancho] and drawn [aumento] times larger, taking up
/// the magnified size so the scroll views around it reach every part.
/// [FittedBox] carries the transform into hit testing and selection, so
/// taps, long presses and selection handles land on the magnified text.
class _Lupa extends StatelessWidget {
  final double aumento;
  final double ancho;
  final Widget child;

  const _Lupa(
      {required this.aumento, required this.ancho, required this.child});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: ancho * aumento,
        child: FittedBox(
          fit: BoxFit.fitWidth,
          alignment: Alignment.topLeft,
          child: SizedBox(width: ancho, child: child),
        ),
      );
}

/// The platform's scroll physics, holding still while a pinch is on: the
/// fingers are magnifying, not scrolling, and the screen moves the page
/// itself to keep their point under them.
class _FisicaPellizco extends ScrollPhysics {
  final bool Function() enPellizco;

  const _FisicaPellizco(this.enPellizco, {super.parent});

  @override
  _FisicaPellizco applyTo(ScrollPhysics? ancestor) =>
      _FisicaPellizco(enPellizco, parent: buildParent(ancestor));

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) =>
      enPellizco() ? 0 : super.applyPhysicsToUserOffset(position, offset);

  @override
  Simulation? createBallisticSimulation(
          ScrollMetrics position, double velocity) =>
      super.createBallisticSimulation(position, enPellizco() ? 0 : velocity);
}

/// The verses.
///
/// One [SelectableText.rich] for the whole poem rather than a Text per line,
/// so a reader can select across stanzas in one gesture — and so the selection
/// they copy carries the poem's real line and stanza breaks.
class _CuerpoPoema extends StatelessWidget {
  final Poema poema;
  final TextStyle estilo;

  const _CuerpoPoema({required this.poema, required this.estilo});

  @override
  Widget build(BuildContext context) {
    final estrofas = poema.estrofas;
    if (context.config.disposicionVersos == DisposicionVersos.ajustada) {
      return SelectionArea(
        child: VersosAjustados(
            estrofas: estrofas, estilo: estilo, seleccionable: true),
      );
    }
    final spans = <TextSpan>[];
    for (var e = 0; e < estrofas.length; e++) {
      if (e > 0) spans.add(const TextSpan(text: '\n\n'));
      spans.add(TextSpan(text: estrofas[e].join('\n')));
    }
    return SelectableText.rich(
      TextSpan(children: spans, style: estilo),
      textAlign: TextAlign.center,
    );
  }
}
