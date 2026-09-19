import 'package:flutter/material.dart';

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

/// Height reserved at the bottom of every scrollable so the last item isn't
/// swallowed by the floating nav pill.
///
/// `RootScreen` sets `extendBody: true`, so each tab's body runs underneath
/// the pill. Nothing compensated for that, and the final card in the index,
/// author, search and favourites lists was unreadable and untappable.
double espacioBarraFlotante(BuildContext context) {
  const altoPildora = 64.0;
  const margenInferior = 16.0;
  return altoPildora + margenInferior + MediaQuery.paddingOf(context).bottom;
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
