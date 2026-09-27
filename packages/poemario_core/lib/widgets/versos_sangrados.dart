import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SelectedContent;

import '../theme/poema_colors.dart';

/// A stanza that is only a section mark: a numeral ("II", "3."), an asterism
/// or a row of dots. Editions print these between the parts of a poem.
final _marca = RegExp(r'^\s*([IVXLCDM]+\.?|\d+\.?|[*∗⁂](\s*[*∗])*|[-—–_.\s]{3,})\s*$');

bool esMarcaDeSeccion(List<String> estrofa) =>
    estrofa.length == 1 && _marca.hasMatch(estrofa.single);

/// Verses laid out for the screen they are on ([DisposicionVersos.sangria]).
///
/// Each verse is measured at the available width and the reader's text size.
/// One that fits stays on one line; one that doesn't is broken where the text
/// would wrap and continues on indented lines, so a wrapped half never looks
/// like a verse of its own. The verses are left-aligned in a block as wide as
/// the longest one ([centrar] centres that block). A stanza that is only a
/// section mark is drawn centred in a smaller, spaced style.
///
/// With [seleccionable] the lines sit in one selection container whose copy
/// joins wrapped pieces with a space, verses with a line break and stanzas
/// with a blank line, i.e. the poem's own text rather than the screen's lines.
class VersosSangrados extends StatefulWidget {
  final List<List<String>> estrofas;
  final TextStyle estilo;
  final bool centrar;
  final bool seleccionable;

  const VersosSangrados({
    super.key,
    required this.estrofas,
    required this.estilo,
    this.centrar = true,
    this.seleccionable = false,
  });

  @override
  State<VersosSangrados> createState() => _VersosSangradosState();
}

class _VersosSangradosState extends State<VersosSangrados> {
  // The last layout, reused while width, text size, style and text are the
  // same: a rebuild of the screen (a favourite toggled) doesn't re-measure.
  Object? _clave;
  _Maqueta? _maqueta;

  @override
  Widget build(BuildContext context) {
    final estilo = DefaultTextStyle.of(context).style.merge(widget.estilo);
    final escala = MediaQuery.textScalerOf(context);
    final direccion = Directionality.of(context);
    return LayoutBuilder(builder: (context, limites) {
      final clave = Object.hash(limites.maxWidth, escala, estilo,
          identityHashCode(widget.estrofas));
      if (clave != _clave || _maqueta == null) {
        _clave = clave;
        _maqueta = _Maqueta.medir(
            widget.estrofas, estilo, escala, direccion, limites.maxWidth);
      }
      return _dibujar(context, _maqueta!, estilo, escala);
    });
  }

  Widget _dibujar(BuildContext context, _Maqueta m, TextStyle estilo,
      TextScaler escala) {
    final tamano = estilo.fontSize ?? 14;
    final hueco = escala.scale(tamano) * (estilo.height ?? 1.2);
    final estiloMarca = estilo.copyWith(
      fontSize: tamano * .85,
      letterSpacing: 2,
      color: context.colores.textoSuave,
    );

    // Every line on screen, top to bottom, and what separates it from the
    // one before in the poem's text.
    final lineas = <Widget>[];
    final separadores = <String>[];
    for (var e = 0; e < m.estrofas.length; e++) {
      final estrofa = m.estrofas[e];
      if (estrofa == null) {
        if (e > 0) lineas.add(SizedBox(height: hueco));
        separadores.add(e > 0 ? '\n\n' : '');
        lineas.add(Text(widget.estrofas[e].single.trim(),
            style: estiloMarca,
            textAlign: TextAlign.center,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.clip));
        continue;
      }
      for (var v = 0; v < estrofa.length; v++) {
        final trozos = estrofa[v];
        for (var i = 0; i < trozos.length; i++) {
          if (e > 0 && v == 0 && i == 0) lineas.add(SizedBox(height: hueco));
          separadores.add(i > 0
              ? ' '
              : v > 0
                  ? '\n'
                  : e > 0
                      ? '\n\n'
                      : '');
          lineas.add(Padding(
            padding: EdgeInsetsDirectional.only(start: i == 0 ? 0 : m.sangria),
            child: Text(trozos[i], style: widget.estilo),
          ));
        }
      }
    }
    Widget bloque = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: lineas);
    if (widget.seleccionable) {
      bloque = _Unidos(separadores: separadores, child: bloque);
    }
    return Align(
      alignment: widget.centrar
          ? Alignment.topCenter
          : AlignmentDirectional.topStart,
      child: SizedBox(width: m.ancho, child: bloque),
    );
  }
}

/// Where each verse breaks at one width: per stanza, per verse, the pieces
/// (a stanza that is a section mark is null).
class _Maqueta {
  final List<List<List<String>>?> estrofas;
  final double ancho;
  final double sangria;
  const _Maqueta(this.estrofas, this.ancho, this.sangria);

  factory _Maqueta.medir(List<List<String>> estrofas, TextStyle estilo,
      TextScaler escala, TextDirection direccion, double disponible) {
    final pintor = TextPainter(textDirection: direccion, textScaler: escala);
    final sangria = escala.scale(estilo.fontSize ?? 14) * 1.5;

    double natural(String s) {
      pintor.text = TextSpan(text: s, style: estilo);
      pintor.layout();
      return pintor.width;
    }

    final marcas = [for (final e in estrofas) esMarcaDeSeccion(e)];
    var mayor = 0.0;
    for (var e = 0; e < estrofas.length; e++) {
      if (marcas[e]) continue;
      for (final v in estrofas[e]) {
        mayor = math.max(mayor, natural(v));
      }
    }
    // One logical pixel of slack against rounding between measuring and
    // painting, which would otherwise wrap a verse that exactly fits.
    final ancho = math.min(disponible, mayor.ceilToDouble() + 1);

    List<String> trocear(String verso) {
      final trozos = <String>[];
      var resto = verso;
      var hueco = ancho;
      while (true) {
        pintor.text = TextSpan(text: resto, style: estilo);
        pintor.layout(maxWidth: hueco);
        if (pintor.computeLineMetrics().length <= 1) break;
        final fin = pintor.getLineBoundary(const TextPosition(offset: 0)).end;
        // A single word wider than the line: let the Text wrap it.
        if (fin <= 0 || fin >= resto.length) break;
        trozos.add(resto.substring(0, fin).trimRight());
        resto = resto.substring(fin).trimLeft();
        hueco = ancho - sangria;
      }
      trozos.add(resto);
      return trozos;
    }

    final maqueta = [
      for (var e = 0; e < estrofas.length; e++)
        marcas[e] ? null : [for (final v in estrofas[e]) trocear(v)],
    ];
    pintor.dispose();
    return _Maqueta(maqueta, ancho, sangria);
  }
}

/// A selection container over the lines of [VersosSangrados]. Its children
/// register in reading order, one per line; the copy puts [separadores][i]
/// before line i (Flutter's default joins them with nothing).
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
