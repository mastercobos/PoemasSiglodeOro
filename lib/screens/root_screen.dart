import 'package:flutter/material.dart';
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

class _RootScreenState extends State<RootScreen> {
  int _tab = 0;

  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  Widget _tabContent(int index) {
    switch (index) {
      case 0: return InicioScreen(poemas: widget.poemas);
      case 1: return HomeScreen(poemas: widget.poemas);
      case 2: return BusquedaScreen(poemas: widget.poemas, todosLosPoemas: widget.poemas);
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final nav = _navigatorKeys[_tab].currentState;
        if (nav != null && nav.canPop()) nav.pop();
      },
      child: Theme(
        data: Theme.of(context).copyWith(
          navigationBarTheme: NavigationBarThemeData(
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return GoogleFonts.lato(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? const Color(0xFFD4AF6A) : Colors.white54,
              );
            }),
          ),
        ),
        child: Scaffold(
          backgroundColor: const Color(0xFFFDF6EC),
          body: IndexedStack(
            index: _tab,
            children: List.generate(4, _buildTab),
          ),
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              border: Border(
                  top: BorderSide(color: Color(0xFF8B6914), width: 1)),
            ),
            child: NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (i) {
                if (i == _tab) {
                  _navigatorKeys[i]
                      .currentState
                      ?.popUntil((route) => route.isFirst);
                } else {
                  setState(() => _tab = i);
                }
              },
              backgroundColor: const Color(0xFF3B2F2F),
              indicatorColor:
                  const Color(0xFF8B6914).withValues(alpha: 0.4),
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.transparent,
              elevation: 0,
              labelBehavior:
                  NavigationDestinationLabelBehavior.alwaysShow,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.wb_sunny_outlined, color: Colors.white54),
                  selectedIcon: Icon(Icons.wb_sunny, color: Color(0xFFD4AF6A)),
                  label: 'Inicio',
                ),
                NavigationDestination(
                  icon: Icon(Icons.menu_book_outlined, color: Colors.white54),
                  selectedIcon: Icon(Icons.menu_book, color: Color(0xFFD4AF6A)),
                  label: 'Índice',
                ),
                NavigationDestination(
                  icon: Icon(Icons.search, color: Colors.white54),
                  selectedIcon: Icon(Icons.search, color: Color(0xFFD4AF6A)),
                  label: 'Buscar',
                ),
                NavigationDestination(
                  icon: Icon(Icons.favorite_border, color: Colors.white54),
                  selectedIcon: Icon(Icons.favorite, color: Color(0xFFD4AF6A)),
                  label: 'Favoritos',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
