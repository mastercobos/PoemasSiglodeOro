import 'package:flutter/material.dart';

import '../data/poema.dart';
import '../screens/poema_screen.dart';
import '../theme/poema_colors.dart';
import '../theme/poema_theme.dart';
import '../utils/navegacion.dart';
import 'texto_resaltado.dart';

/// One poem in a list: book glyph, label, optional first-verse subtitle,
/// optional matched excerpt, chevron.
///
/// The author, favourites and search screens each had their own copy of this
/// row, with slightly different paddings, icon sizes and subtitle colours, and
/// each repeated the same four-clause condition for whether to show the
/// `«first verse»` line (now [Poema.mostrarPrimerVerso]).
class PoemaListTile extends StatelessWidget {
  final Poema poema;

  /// When set, title, author and excerpt highlight their matches.
  final String consulta;

  /// Matched excerpt from the body, shown only when the hit wasn't in the
  /// title or the author name.
  final String? fragmento;

  /// Shows the author under the title. On by default in search, off inside an
  /// author's own list where it would repeat the app bar.
  final bool mostrarAutor;

  const PoemaListTile({
    super.key,
    required this.poema,
    this.consulta = '',
    this.fragmento,
    this.mostrarAutor = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final t = context.tipos;

    return MergeSemantics(
      child: Material(
        color: c.tarjeta,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            rutaFundido((_) => PoemaScreen(poema: poema)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(Icons.menu_book_outlined,
                        size: 16, color: c.oro),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextoResaltado(
                        texto: poema.etiqueta,
                        consulta: consulta,
                        estilo: t.cuerpo.copyWith(
                            color: c.texto, fontWeight: FontWeight.w500),
                      ),
                      if (poema.mostrarPrimerVerso)
                        Text(
                          '«${poema.primerVerso}»',
                          style: t.cuerpoPequeno.copyWith(
                              color: c.textoSuave,
                              fontStyle: FontStyle.italic),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (mostrarAutor) ...[
                        const SizedBox(height: 3),
                        TextoResaltado(
                          texto: poema.autor,
                          consulta: consulta,
                          estilo: t.cuerpoPequeno.copyWith(
                              color: c.oro, fontStyle: FontStyle.italic),
                        ),
                      ],
                      if (fragmento != null && fragmento!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: TextoResaltado(
                            texto: fragmento!,
                            consulta: consulta,
                            estilo: t.cuerpoPequeno
                                .copyWith(color: c.textoSuave, height: 1.5),
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 18, color: c.oroClaro),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The bordered, shadowed container every card in the app was drawing by hand.
class TarjetaPoemario extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry margen;
  final double radio;

  const TarjetaPoemario({
    super.key,
    required this.child,
    this.margen = const EdgeInsets.only(bottom: 14),
    this.radio = 12,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Container(
      margin: margen,
      decoration: BoxDecoration(
        color: c.tarjeta,
        borderRadius: BorderRadius.circular(radio),
        border: Border.all(color: c.oroClaro),
        boxShadow: [
          BoxShadow(color: c.sombra, blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radio),
        child: child,
      ),
    );
  }
}

/// Centred caption bar on a sepia band, under an app bar.
class BandaSubtitulo extends StatelessWidget {
  final String texto;

  const BandaSubtitulo(this.texto, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Container(
      width: double.infinity,
      color: c.sepia,
      padding: const EdgeInsets.only(top: 4, bottom: 14),
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: context.tipos.etiquetaEspaciada.copyWith(color: c.oroClaro),
      ),
    );
  }
}
