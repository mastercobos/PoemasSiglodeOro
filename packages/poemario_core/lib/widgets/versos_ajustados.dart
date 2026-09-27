import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SelectedContent;

import '../theme/poema_colors.dart';

/// A stanza that is only a section mark: a numeral ("II", "3."), an asterism
/// or a row of dots. Editions print these between the parts of a poem.
/// The French pipeline (`asset.py`) uses the same pattern.
final _marca = RegExp(r'^\s*([IVXLCDM]+\.?|\d+\.?|[*∗⁂](\s*[*∗])*|[-—–_.\s]{3,})\s*$');

bool esMarcaDeSeccion(List<String> estrofa) =>
    estrofa.length == 1 && _marca.hasMatch(estrofa.single);

/// Verses sized for the screen they are on ([DisposicionVersos.ajustada]).
///
/// The poem's longest verse is measured at the available width and the
/// reader's text size, and the whole poem is set just small enough for it to
/// fit on one line, never below [escalaMinima] of [estilo]. A poem that
/// still doesn't fit wraps its long verses; its line height is then split so
/// that a verse's wrapped lines sit closer together than two verses do.
/// A stanza that is only a section mark is drawn as a small heading.
///
/// With [seleccionable] the lines sit in one selection container whose copy
/// joins verses with a line break and stanzas with a blank line, i.e. the
/// poem's own text.
class VersosAjustados extends StatefulWidget {
  /// Smallest size a poem is shrunk to, as a fraction of [estilo]'s.
  static const escalaMinima = .8;

  /// Line height inside a wrapped verse, when the poem doesn't fit.
  static const alturaPartida = 1.45;

  final List<List<String>> estrofas;
  final TextStyle estilo;
  final TextAlign alineacion;
  final bool seleccionable;

  const VersosAjustados({
    super.key,
    required this.estrofas,
    required this.estilo,
    this.alineacion = TextAlign.center,
    this.seleccionable = false,
  });

  @override
  State<VersosAjustados> createState() => _VersosAjustadosState();
}

class _VersosAjustadosState extends State<VersosAjustados> {
  // The last measurement, reused while width, text size, style and text are
  // the same: a rebuild of the screen (a favourite toggled) doesn't re-measure.
  Object? _clave;
  _Medida? _medida;

  @override
  Widget build(BuildContext context) {
    final estilo = DefaultTextStyle.of(context).style.merge(widget.estilo);
    final escala = MediaQuery.textScalerOf(context);
    final direccion = Directionality.of(context);
    return LayoutBuilder(builder: (context, limites) {
      final clave = Object.hash(limites.maxWidth, escala, estilo,
          identityHashCode(widget.estrofas));
      if (clave != _clave || _medida == null) {
        _clave = clave;
        _medida = _Medida.tomar(
            widget.estrofas, estilo, escala, direccion, limites.maxWidth);
      }
      return _dibujar(context, _medida!, estilo, escala);
    });
  }

  Widget _dibujar(
      BuildContext context, _Medida m, TextStyle estilo, TextScaler escala) {
    final tamano = (estilo.fontSize ?? 14) * m.factor;
    final altura = estilo.height ?? 1.2;
    final base = widget.estilo.copyWith(
      fontSize: tamano,
      letterSpacing: estilo.letterSpacing == null
          ? null
          : estilo.letterSpacing! * m.factor,
    );
    // Fits: every verse is one line at the style's own height. Doesn't: a
    // tighter height inside a verse, the difference added between verses,
    // so one-line verses keep the same rhythm.
    final verso =
        m.cabe ? base : base.copyWith(height: VersosAjustados.alturaPartida);
    final entreVersos = m.cabe
        ? 0.0
        : escala.scale(tamano) * (altura - VersosAjustados.alturaPartida);
    final entreEstrofas = escala.scale(tamano) * altura;
    final estiloMarca = base.copyWith(
      fontSize: tamano * .85,
      letterSpacing: 2,
      color: context.colores.textoSuave,
    );

    // Every verse, top to bottom, and what separates it from the one before
    // in the poem's text.
    final lineas = <Widget>[];
    final separadores = <String>[];
    for (var e = 0; e < widget.estrofas.length; e++) {
      final estrofa = widget.estrofas[e];
      if (e > 0) lineas.add(SizedBox(height: entreEstrofas));
      if (esMarcaDeSeccion(estrofa)) {
        separadores.add(e > 0 ? '\n\n' : '');
        lineas.add(Text(estrofa.single.trim(),
            style: estiloMarca,
            textAlign: TextAlign.center,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.clip));
        continue;
      }
      for (var v = 0; v < estrofa.length; v++) {
        if (v > 0 && entreVersos > 0) lineas.add(SizedBox(height: entreVersos));
        separadores.add(v > 0
            ? '\n'
            : e > 0
                ? '\n\n'
                : '');
        lineas.add(
            Text(estrofa[v], style: verso, textAlign: widget.alineacion));
      }
    }
    final bloque = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: lineas);
    return widget.seleccionable
        ? _Unidos(separadores: separadores, child: bloque)
        : bloque;
  }
}

/// How much a poem is shrunk at one width, and whether it then fits.
class _Medida {
  final double factor;
  final bool cabe;
  const _Medida(this.factor, this.cabe);

  factory _Medida.tomar(List<List<String>> estrofas, TextStyle estilo,
      TextScaler escala, TextDirection direccion, double disponible) {
    final pintor = TextPainter(textDirection: direccion, textScaler: escala);
    var mayor = 0.0;
    for (final e in estrofas) {
      if (esMarcaDeSeccion(e)) continue;
      for (final v in e) {
        pintor.text = TextSpan(text: v, style: estilo);
        pintor.layout();
        mayor = math.max(mayor, pintor.width);
      }
    }
    pintor.dispose();
    // One logical pixel of slack against rounding between measuring and
    // painting, which would otherwise wrap a verse that exactly fits.
    final hueco = disponible - 1;
    if (mayor <= hueco) return const _Medida(1, true);
    // Width scales with font size (letter spacing is scaled with it).
    final factor = hueco / mayor;
    return factor >= VersosAjustados.escalaMinima
        ? _Medida(factor, true)
        : const _Medida(VersosAjustados.escalaMinima, false);
  }
}

/// A selection container over the lines of [VersosAjustados]. Its children
/// register in reading order, one per line; the copy puts [separadores][i]
/// before line i (Flutter's default joins them with nothing). One container,
/// not one per stanza: nested ones never received the selection.
class _Unidos extends StatefulWidget {
  final List<String> separadores;
  final Widget child;
  const _Unidos({required this.separadores, required this.child});

  @override
  State<_Unidos> createState() => _UnidosState();
}

class _UnidosState extends State<_Unidos> {
  final _delegado = _DelegadoUnido();

  @override
  void dispose() {
    _delegado.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _delegado.separadores = widget.separadores;
    return SelectionContainer(delegate: _delegado, child: widget.child);
  }
}

class _DelegadoUnido extends StaticSelectionContainerDelegate {
  List<String> separadores = const [];

  @override
  SelectedContent? getSelectedContent() {
    final texto = StringBuffer();
    var alguno = false;
    for (var i = 0; i < selectables.length; i++) {
      final c = selectables[i].getSelectedContent();
      if (c == null) continue;
      if (alguno && i < separadores.length) texto.write(separadores[i]);
      texto.write(c.plainText);
      alguno = true;
    }
    return alguno ? SelectedContent(plainText: texto.toString()) : null;
  }
}
