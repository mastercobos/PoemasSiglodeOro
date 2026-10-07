import 'package:flutter/material.dart';

import '../theme/poema_theme.dart';

/// The fade transition that appeared, character for character, in five
/// different screens.
Route<T> rutaFundido<T>(
  WidgetBuilder builder, {
  Duration duracion = const Duration(milliseconds: 250),
  RouteSettings? settings,
}) {
  return PageRouteBuilder<T>(
    settings: settings,
    transitionDuration: duracion,
    reverseTransitionDuration: duracion,
    pageBuilder: (context, _, __) => builder(context),
    transitionsBuilder: (_, animation, __, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

/// Ceiling on the system text scale for the floating nav pill's labels.
///
/// The labels follow the phone's font size up to here; beyond it four labels
/// no longer fit side by side on a phone-width pill.
const escalaMaximaPildora = 1.6;

/// Height reserved at the bottom of every scrollable so the last item isn't
/// swallowed by the floating nav pill.
///
/// `RootScreen` sets `extendBody: true`, so each tab's body runs underneath
/// the pill. Nothing compensated for that, and the final card in the index,
/// author, search and favourites lists was unreadable and untappable.
double espacioBarraFlotante(BuildContext context) {
  // The pill's fixed parts: 8 + 8 padding, 1 + 1 border, the 3 px selection
  // bar and its 4 px gap, the 22 px icon and the 4 px under it.
  const fijo = 8 + 8 + 1 + 1 + 3 + 4 + 22 + 4;
  const margenInferior = 16.0;
  // The label line grows with the text scale and depends on the app's font,
  // so it is measured rather than guessed.
  final escala = MediaQuery.textScalerOf(context)
      .scale(1)
      .clamp(1.0, escalaMaximaPildora);
  final etiqueta = TextPainter(
    text: TextSpan(
      text: 'Ag',
      // Merged the way the label's own Text widget merges it.
      style: DefaultTextStyle.of(context).style.merge(context.tipos.navLabel),
    ),
    textScaler: TextScaler.linear(escala),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  final alto = fijo + etiqueta.height;
  etiqueta.dispose();
  return alto + margenInferior + MediaQuery.paddingOf(context).bottom;
}

/// Clamps text scaling to a ceiling, for layouts that genuinely can't grow
/// (a fixed-size avatar beside a name).
///
/// Deliberately **not** used on the poem body. That screen used to cap
/// scaling at 1.15, which is the one place a low-vision reader most needs
/// large type, and the scroll view can absorb any height.
class EscalaLimitada extends StatelessWidget {
  final double maximo;
  final Widget child;

  const EscalaLimitada({super.key, required this.maximo, required this.child});

  @override
  Widget build(BuildContext context) {
    final actual = MediaQuery.textScalerOf(context).scale(1);
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(actual.clamp(1.0, maximo)),
      ),
      child: child,
    );
  }
}
