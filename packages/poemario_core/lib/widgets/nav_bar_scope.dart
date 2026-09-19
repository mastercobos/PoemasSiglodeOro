import 'package:flutter/widgets.dart';

/// Lets any descendant ask the root shell to reveal the floating nav bar
/// without threading a callback through every constructor.
///
/// The original compared `showNavBar != oldWidget.showNavBar` in
/// [updateShouldNotify]. Because the callback was a method tear-off created
/// fresh on every `build()` of the shell, that comparison was always true and
/// every dependent rebuilt on every frame of the hide/show animation. The
/// shell now stores the tear-off in a `late final` field, so the comparison
/// does what it looks like it does.
class NavBarScope extends InheritedWidget {
  final VoidCallback mostrarNavBar;

  const NavBarScope({
    super.key,
    required this.mostrarNavBar,
    required super.child,
  });

  static NavBarScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NavBarScope>();

  @override
  bool updateShouldNotify(NavBarScope oldWidget) =>
      mostrarNavBar != oldWidget.mostrarNavBar;
}
