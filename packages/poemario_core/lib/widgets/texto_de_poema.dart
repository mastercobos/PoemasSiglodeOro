import 'package:flutter/material.dart';

import '../data/poema.dart';

/// Builds [builder] once [poema]'s text is loaded.
///
/// A split anthology loads a poem's text when it is first shown
/// ([Poema.cargarTexto]); until then this shows [cargando]. A poem whose text
/// is already there is built straight away, with no empty frame.
class TextoDePoema extends StatelessWidget {
  final Poema poema;
  final WidgetBuilder builder;
  final Widget cargando;

  const TextoDePoema({
    super.key,
    required this.poema,
    required this.builder,
    this.cargando = const SizedBox.shrink(),
  });

  @override
  Widget build(BuildContext context) {
    if (poema.textoCargado) return builder(context);
    return FutureBuilder<void>(
      future: poema.cargarTexto(),
      builder: (context, estado) =>
          estado.connectionState == ConnectionState.done ? builder(context) : cargando,
    );
  }
}
