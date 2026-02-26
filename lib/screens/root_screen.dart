import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/poema.dart';
import 'inicio_screen.dart';
import 'home_screen.dart';
import 'busqueda_screen.dart';
import 'favoritos_screen.dart';

class RootScreen extends StatefulWidget {
  final List<Poema> poemas;
  const RootScreen({super.key, required this.poemas});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen>
    with SingleTickerProviderStateMixin {
  int _tab = 0;

  late final AnimationController _navBarController;

  // ValueNotifier: al cambiar, solo reconstruye la píldora, no el IndexedStack
  final ValueNotifier<bool> _navBarVisible = ValueNotifier(true);

  double _scrollAccumulator = 0;
  static const double _showThreshold = -40.0;
  static const double _hideThreshold = 60.0;

  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  @override
  void initState() {
    super.initState();
    _navBarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 0, // 0 = visible, 1 = oculto
    );
  }

  @override
  void dispose() {
    _navBarController.dispose();
    _navBarVisible.dispose();
    super.dispose();
  }

  void _onScroll(ScrollNotification n) {
    if (n is ScrollUpdateNotification) {
      final delta = n.scrollDelta ?? 0;
      final pixels = n.metrics.pixels;

      if (n.metrics.outOfRange || pixels <= 0) {
        _scrollAccumulator = 0;
        _showNavBar();
        return;
      }

      _scrollAccumulator += delta;

      if (_scrollAccumulator >= _hideThreshold) {
        _scrollAccumulator = 0;
        _hideNavBar();
      } else if (_scrollAccumulator <= _showThreshold) {
        _scrollAccumulator = 0;
        _showNavBar();
      }
    } else if (n is ScrollEndNotification) {
      _scrollAccumulator = 0;
      if (n.metrics.pixels <= 0) _showNavBar();
    }
  }

  void _hideNavBar() {
    if (!_navBarVisible.value) return;
    _navBarVisible.value = false;   // sin setState
    _navBarController.forward();    // anima solo el widget de la píldora
  }

  void _showNavBar() {
    if (_navBarVisible.value) return;
    _navBarVisible.value = true;    // sin setState
    _navBarController.reverse();
  }

  void _onTabSelected(int i) {
    if (i == _tab) {
      _navigatorKeys[i].currentState?.popUntil((route) => route.isFirst);
    } else {
      setState(() => _tab = i); // setState solo para cambiar de tab
    }
    _showNavBar();
    _scrollAccumulator = 0;
  }

  Widget _tabContent(int index) {
    switch (index) {
      case 0: return InicioScreen(poemas: widget.poemas);
      case 1: return HomeScreen(poemas: widget.poemas);
      case 2: return BusquedaScreen(
          poemas: widget.poemas, todosLosPoemas: widget.poemas);
      case 3: return FavoritosScreen(todosLosPoemas: widget.poemas);
      default: return const SizedBox();
    }
  }

  Widget _buildTab(int index) {
    return Navigator(
      key: _navigatorKeys[index],
      onGenerateRoute: (settings) => MaterialPageRoute(
        builder: (_) => _tabContent(index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBgColor =
        isDark ? const Color(0xFF0F0A08) : const Color(0xFF3B2F2F);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final nav = _navigatorKeys[_tab].currentState;
        if (nav != null && nav.canPop()) nav.pop();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        child: Scaffold(
          extendBody: true,
          body: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.depth == 0) _onScroll(n);
              return false;
            },
            child: IndexedStack(
              index: _tab,
              children: List.generate(4, _buildTab),
            ),
          ),
          // ValueListenableBuilder: reconstruye SOLO la píldora, nunca el body
          bottomNavigationBar: ValueListenableBuilder<bool>(
            valueListenable: _navBarVisible,
            builder: (context, _, __) {
              return Padding(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  bottom: bottomPadding + 16,
                ),
                child: AnimatedBuilder(
                  animation: _navBarController,
                  builder: (context, child) {
                    final t = _navBarController.value;
                    final offset = Offset(0, t * 1.5);
                    final opacity = (1.0 - t).clamp(0.0, 1.0);
                    return FractionalTranslation(
                      translation: offset,
                      child: Opacity(
                        opacity: opacity,
                        child: child,
                      ),
                    );
                  },
                  child: _FloatingPill(
                    selectedIndex: _tab,
                    onDestinationSelected: _onTabSelected,
                    backgroundColor: navBgColor,
                    isDark: isDark,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─── Píldora flotante ─────────────────────────────────────────────────────────

class _FloatingPill extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Color backgroundColor;
  final bool isDark;

  const _FloatingPill({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.backgroundColor,
    required this.isDark,
  });

  static const _items = [
    _NavItem(Icons.wb_sunny_outlined, Icons.wb_sunny,   'Inicio',    'Inicio, poemas del día'),
    _NavItem(Icons.menu_book_outlined, Icons.menu_book, 'Índice',    'Índice de autores'),
    _NavItem(Icons.search,             Icons.search,    'Buscar',    'Buscar poemas'),
    _NavItem(Icons.favorite_border,    Icons.favorite,  'Favoritos', 'Mis poemas favoritos'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(
          color: const Color(0xFF8B6914).withValues(alpha: 0.6),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.25),
            blurRadius: 20,
            offset: const Offset(0, 6),
            spreadRadius: -2,
          ),
          BoxShadow(
            color: const Color(0xFF8B6914).withValues(alpha: isDark ? 0.15 : 0.10),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(_items.length, (i) {
          final item = _items[i];
          final isSelected = i == selectedIndex;
          return Expanded(
            child: Semantics(
              label: item.semanticLabel,
              button: true,
              selected: isSelected,
              child: InkWell(
                onTap: () => onDestinationSelected(i),
                borderRadius: BorderRadius.circular(40),
                splashColor: const Color(0xFF8B6914).withValues(alpha: 0.2),
                highlightColor: const Color(0xFF8B6914).withValues(alpha: 0.1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        width: isSelected ? 32 : 0,
                        height: isSelected ? 3 : 0,
                        margin: const EdgeInsets.only(bottom: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4AF6A),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      ExcludeSemantics(
                        child: Icon(
                          isSelected ? item.iconSelected : item.icon,
                          color: isSelected
                              ? const Color(0xFFD4AF6A)
                              : Colors.white54,
                          size: 22,
                        ),
                      ),
                      const SizedBox(height: 3),
                      ExcludeSemantics(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: GoogleFonts.lato(
                            fontSize: 10,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isSelected
                                ? const Color(0xFFD4AF6A)
                                : Colors.white54,
                          ),
                          child: Text(item.label),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData iconSelected;
  final String label;
  final String semanticLabel;
  const _NavItem(this.icon, this.iconSelected, this.label, this.semanticLabel);
}
