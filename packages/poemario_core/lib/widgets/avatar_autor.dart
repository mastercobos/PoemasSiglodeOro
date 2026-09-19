import 'package:flutter/material.dart';

import '../theme/poema_colors.dart';
import '../theme/poema_theme.dart';

/// Circle with the author's initial. Was reimplemented three times with three
/// different sizes and two different background colours.
class AvatarAutor extends StatelessWidget {
  final String autor;
  final double tamano;
  final bool apagado;

  const AvatarAutor({
    super.key,
    required this.autor,
    this.tamano = 46,
    this.apagado = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final inicial = autor.trim().isEmpty ? '?' : autor.trim()[0].toUpperCase();

    return ExcludeSemantics(
      child: Container(
        width: tamano,
        height: tamano,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: apagado ? Theme.of(context).disabledColor : c.sepia,
        ),
        alignment: Alignment.center,
        child: Text(
          inicial,
          style: context.tipos.avatarInicial.copyWith(
            color: c.sobreSepia,
            fontSize: tamano * 0.43,
          ),
        ),
      ),
    );
  }
}
