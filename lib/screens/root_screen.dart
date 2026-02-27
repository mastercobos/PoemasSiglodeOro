import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/poema.dart';
import '../widgets/nav_bar_controller.dart';
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
      value: 0,
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
    _navBarVisible.value = false;
    _navBarController.forward();
  }

  void _showNavBar() {
    if (_navBarVisible.value) return;
    _navBarVisible.value = true;
    _navBarController.reverse();
  }

  void _onTabSelected(int i) {
    if (i == _tab) {
      _navigatorKeys[i].currentState?.popUntil((route) => route.isFirst);
    } else {
      setState(() => _tab = i);
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
    return TickerMode(
      enabled: _tab == index,
      child: ExcludeFocus(
        excluding: _tab != index,
        child: Navigator(
          key: _navigatorKeys[index],
          onGenerateRoute: (settings) => MaterialPageRoute(
            builder: (_) => _tabContent(index),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBgColor =
        isDark ? const Color(0xFF0F0A08) : const Color(0xFF3B2F2F);
    final systemBottomPadding = MediaQuery.of(context).padding.bottom;

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
          resizeToAvoidBottomInset: false,
          body: NavBarControllerScope(
            showNavBar: _showNavBar,
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.depth == 0) _onScroll(n);
                return false;
              },
              child: Stack(
                children: [
                  IndexedStack(
                    index: _tab,
                    children: List.generate(4, _buildTab),
                  ),
                  // IME warmup solo en móvil nativo — no aplica en web
                  if (!kIsWeb) const _ImeWarmup(),
                  // Píldora flotante
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: systemBottomPadding + 16,
                    child: ValueListenableBuilder<bool>(
                      valueListenable: _navBarVisible,
                      builder: (context, _, __) {
                        return AnimatedBuilder(
                          animation: _navBarController,
                          builder: (context, child) {
                            final t = _navBarController.value;
                            return FractionalTranslation(
                              translation: Offset(0, t * 1.5),
                              child: Opacity(
                                opacity: (1.0 - t).clamp(0.0, 1.0),
                                child: child,
                              ),
                            );
                          },
                          child: MediaQuery(
                            data: MediaQuery.of(context)
                                .copyWith(textScaler: TextScaler.noScaling),
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
                ],
              ),
            ),
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

  static const _shadowsLight = [
    BoxShadow(color: Color(0x40000000), blurRadius: 20,
        offset: Offset(0, 6), spreadRadius: -2),
    BoxShadow(color: Color(0x1A8B6914), blurRadius: 12, offset: Offset(0, 2)),
  ];
  static const _shadowsDark = [
    BoxShadow(color: Color(0x80000000), blurRadius: 20,
        offset: Offset(0, 6), spreadRadius: -2),
    BoxShadow(color: Color(0x268B6914), blurRadius: 12, offset: Offset(0, 2)),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(
          color: const Color(0xFF8B6914).withValues(alpha: 0.6),
          width: 1,
        ),
        boxShadow: isDark ? _shadowsDark : _shadowsLight,
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        width: isSelected ? 28 : 0,
                        height: isSelected ? 3 : 0,
                        margin: const EdgeInsets.only(bottom: 4),
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
                      const SizedBox(height: 4),
                      ExcludeSemantics(
                        child: Text(
                          item.label,
                          style: GoogleFonts.lato(
                            fontSize: 10,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isSelected
                                ? const Color(0xFFD4AF6A)
                                : Colors.white54,
                          ),
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

// ─── IME Warmup (solo móvil nativo) ──────────────────────────────────────────
// Abre y cierra la conexión con el IME de Android en el primer frame,
// forzando la inicialización lazy antes de que el usuario toque nada.

class _ImeWarmup extends StatefulWidget {
  const _ImeWarmup();

  @override
  State<_ImeWarmup> createState() => _ImeWarmupState();
}

class _ImeWarmupState extends State<_ImeWarmup> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _focusNode.unfocus();
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // SizedBox.shrink en lugar de Positioned: no necesita Stack como padre
    // para existir en el árbol. Tamaño 0×0, completamente invisible.
    return SizedBox.shrink(
      child: Offstage(
        child: TextField(
          focusNode: _focusNode,
          enableInteractiveSelection: false,
          // fontSize > 0 requerido por Flutter (assertion)
          style: const TextStyle(fontSize: 1.0, color: Colors.transparent),
          decoration: const InputDecoration(
            border: InputBorder.none,
            focusedBorder: InputBorder.none,
            enabledBorder: InputBorder.none,
            isCollapsed: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }
}
