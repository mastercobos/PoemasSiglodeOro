import 'package:flutter/material.dart';

import '../theme/poema_colors.dart';
import '../theme/poema_theme.dart';
import 'linea_oro.dart';

/// The search field that sits in a sepia app bar: the Search tab's full-text
/// box and the Index's author filter. One widget so the two can't drift.
/// Carries the gold rule that ends every app bar, below the field.
class CampoBusqueda extends StatelessWidget implements PreferredSizeWidget {
  final TextEditingController controlador;
  final FocusNode? focusNode;
  final String pista;

  /// Tooltip of the clear button, shown while there is text.
  final String borrar;

  /// Called after the clear button empties the field.
  final VoidCallback? alBorrar;

  const CampoBusqueda({
    super.key,
    required this.controlador,
    required this.pista,
    required this.borrar,
    this.focusNode,
    this.alBorrar,
  });

  @override
  Size get preferredSize => const Size.fromHeight(61);

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final t = context.tipos;

    return Column(mainAxisSize: MainAxisSize.min, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: SearchBar(
          controller: controlador,
          focusNode: focusNode,
          hintText: pista,
          textInputAction: TextInputAction.search,
          hintStyle: WidgetStatePropertyAll(
              t.cuerpo.copyWith(color: c.sobreSepia.withValues(alpha: .38))),
          textStyle:
              WidgetStatePropertyAll(t.cuerpo.copyWith(color: c.sobreSepia)),
          leading: Icon(Icons.search, color: c.oroClaro),
          trailing: [
            // Rebuilds the button alone as the text changes, so a screen that
            // filters on a debounce doesn't have to setState per keystroke.
            ListenableBuilder(
              listenable: controlador,
              builder: (context, _) => controlador.text.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      tooltip: borrar,
                      icon: Icon(Icons.close,
                          color: c.sobreSepia.withValues(alpha: .54)),
                      onPressed: () {
                        controlador.clear();
                        alBorrar?.call();
                      },
                    ),
            ),
          ],
          backgroundColor:
              WidgetStatePropertyAll(c.sobreSepia.withValues(alpha: .10)),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shadowColor: const WidgetStatePropertyAll(Colors.transparent),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          padding:
              const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 8)),
        ),
      ),
      const LineaOro(),
    ]);
  }
}
