import 'package:flutter/widgets.dart';

/// Permite que cualquier pantalla hija acceda al controlador de la nav bar
/// sin necesidad de pasar callbacks por todos los constructores.
class NavBarControllerScope extends InheritedWidget {
  final VoidCallback showNavBar;

  const NavBarControllerScope({
    super.key,
    required this.showNavBar,
    required super.child,
  });

  static NavBarControllerScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<NavBarControllerScope>();
  }

  @override
  bool updateShouldNotify(NavBarControllerScope oldWidget) =>
      showNavBar != oldWidget.showNavBar;
}
