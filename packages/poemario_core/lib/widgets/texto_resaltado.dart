import 'package:flutter/material.dart';

import '../domain/orden_titulos.dart';
import '../theme/poema_colors.dart';

/// Highlights every occurrence of [consulta] inside [texto].
///
/// Two fixes over the original `_HighlightText`:
///
/// * it used `RichText`, which ignores the platform text-scale factor, so
///   search results stayed small for a reader who had turned system fonts up.
///   `Text.rich` respects it;
/// * matching is diacritic-insensitive, so typing "cancion" finds "canción".
///   The offsets still index the original string, because [plegarParaOrden]
///   only maps 'ñ' to two characters — handled below.
class TextoResaltado extends StatelessWidget {
  final String texto;
  final String consulta;
  final TextStyle estilo;
  final int? maxLineas;

  const TextoResaltado({
    super.key,
    required this.texto,
    required this.consulta,
    required this.estilo,
    this.maxLineas,
  });

  @override
  Widget build(BuildContext context) {
    if (consulta.isEmpty) {
      return Text(texto,
          style: estilo,
          maxLines: maxLineas,
          overflow: maxLineas == null ? null : TextOverflow.ellipsis);
    }

    final colores = context.colores;
    final estiloMarca = estilo.copyWith(
      color: colores.oro,
      fontWeight: FontWeight.bold,
      backgroundColor: colores.oroClaro.withValues(alpha: 0.25),
    );

    final spans = <TextSpan>[];
    for (final tramo in _tramos(texto, consulta)) {
      spans.add(TextSpan(
        text: texto.substring(tramo.inicio, tramo.fin),
        style: tramo.marcado ? estiloMarca : estilo,
      ));
    }

    return Text.rich(
      TextSpan(children: spans),
      style: estilo,
      maxLines: maxLineas,
      overflow: maxLineas == null ? null : TextOverflow.ellipsis,
    );
  }

  /// Walks the folded text, mapping each folded index back to an index in the
  /// original string so the highlight lands on the right characters.
  static List<_Tramo> _tramos(String texto, String consulta) {
    final mapa = <int>[]; // folded index -> original index
    final plegado = StringBuffer();
    for (var i = 0; i < texto.length; i++) {
      final trozo = plegarParaOrden(texto[i]);
      for (var j = 0; j < trozo.length; j++) {
        mapa.add(i);
      }
      plegado.write(trozo);
    }
    final aguja = plegarParaOrden(consulta);
    final pajar = plegado.toString();

    final tramos = <_Tramo>[];
    var cursor = 0;
    while (true) {
      final idx = pajar.indexOf(aguja, cursor);
      if (idx == -1 || aguja.isEmpty) {
        if (cursor < pajar.length) {
          tramos.add(_Tramo(mapa[cursor], texto.length, false));
        }
        break;
      }
      if (idx > cursor) tramos.add(_Tramo(mapa[cursor], mapa[idx], false));
      final finPlegado = idx + aguja.length;
      final finOriginal =
          finPlegado < mapa.length ? mapa[finPlegado] : texto.length;
      tramos.add(_Tramo(mapa[idx], finOriginal, true));
      cursor = finPlegado;
      if (cursor >= pajar.length) break;
    }
    return tramos;
  }
}

class _Tramo {
  final int inicio;
  final int fin;
  final bool marcado;
  const _Tramo(this.inicio, this.fin, this.marcado);
}
