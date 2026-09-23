import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/poema_repository.dart';
import '../l10n/generated/app_localizations.dart';
import '../notifications/agenda_avisos.dart';
import '../theme/poema_colors.dart';
import '../theme/poema_theme.dart';
import '../utils/navegacion.dart';
import '../widgets/nav_bar_scope.dart';
import 'busqueda_screen.dart';
import 'favoritos_screen.dart';
import 'indice_screen.dart';
import 'inicio_screen.dart';
import 'poema_screen.dart';

/// The four-tab shell.
///
/// Structure is unchanged — an [IndexedStack] of nested [Navigator]s, so each
/// tab keeps its own stack — with three fixes:
///
/// * **back no longer traps the user.** `canPop: false` with a handler that
///   only popped the inner navigator meant that, at a tab root, the Android
///   back button did nothing at all and the app could not be left;
/// * the show-nav-bar callback is a stored tear-off, so [NavBarScope] doesn't
///   notify every dependent on every frame;
/// * the redundant `ValueListenableBuilder` wrapping the `AnimatedBuilder` is
///   gone; the controller already carries the state.
///
/// The hidden `_ImeWarmup` text field is also gone. It focused an off-screen
/// `TextField` on the first frame to warm Android's input connection — clever,
/// but it leans on framework internals, can flash the keyboard on some OEM
/// builds, and confuses autofill heuristics. If the search tab's first tap
/// really is slow on your minimum-spec device, measure it and bring the trick
/// back deliberately rather than by default.
class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen>
    with SingleTickerProviderStateMixin {
  static const _tabs = 4;
  static const _umbralOcultar = 60.0;
  static const _umbralMostrar = -40.0;

  int _tab = 0;
  double _acumuladoScroll = 0;

  late final AnimationController _animacion;

  /// Stored once. As a fresh tear-off per build it defeated
  /// `NavBarScope.updateShouldNotify`.
  late final VoidCallback _mostrarNavBarCallback = _mostrarNavBar;

  final _clavesNavegador =
      List.generate(_tabs, (_) => GlobalKey<NavigatorState>());

  late final SolicitudDePoema _solicitudes;

  @override
  void initState() {
    super.initState();
    _animacion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Deep links from notifications. The notifier already holds a value if a
    // tap cold-started the app, so handle it once before subscribing.
    _solicitudes = context.read<SolicitudDePoema>();
    _solicitudes.addListener(_alPedirPoema);
    WidgetsBinding.instance.addPostFrameCallback((_) => _alPedirPoema());
  }

  @override
  void dispose() {
    _solicitudes.removeListener(_alPedirPoema);
    _animacion.dispose();
    super.dispose();
  }

  /// Handles a notification tap.
  ///
  /// The daily reminder ([SolicitudDePoema.inicio]) names both poems of the
  /// day, so it opens the *today* tab at its root, where both are shown.
  /// A poem id comes from a reminder scheduled by 1.1.0, which named a single
  /// poem; that one still opens the poem, through the today tab's navigator so
  /// back lands where a reader coming from a reminder expects. An id that no
  /// longer resolves — normal after the anthology is edited — just opens the
  /// app, which is the right failure.
  void _alPedirPoema() {
    if (!mounted) return;
    final id = _solicitudes.tomar();
    if (id == null) return;

    final poema = id == SolicitudDePoema.inicio
        ? null
        : context.read<Anthology>().porId(id);
    if (id != SolicitudDePoema.inicio && poema == null) return;

    setState(() => _tab = 0);
    // After the IndexedStack has switched, so the target navigator is mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = _clavesNavegador[0].currentState;
      if (nav == null) return;
      nav.popUntil((r) => r.isFirst);
      if (poema != null) nav.push(rutaFundido((_) => PoemaScreen(poema: poema)));
    });
  }

  void _alHacerScroll(ScrollNotification n) {
    if (n is ScrollUpdateNotification) {
      if (n.metrics.outOfRange || n.metrics.pixels <= 0) {
        _acumuladoScroll = 0;
        _mostrarNavBar();
        return;
      }
      _acumuladoScroll += n.scrollDelta ?? 0;
      if (_acumuladoScroll >= _umbralOcultar) {
        _acumuladoScroll = 0;
        _ocultarNavBar();
      } else if (_acumuladoScroll <= _umbralMostrar) {
        _acumuladoScroll = 0;
        _mostrarNavBar();
      }
    } else if (n is ScrollEndNotification) {
      _acumuladoScroll = 0;
      if (n.metrics.pixels <= 0) _mostrarNavBar();
    }
  }

  void _ocultarNavBar() => _animacion.forward();

  void _mostrarNavBar() => _animacion.reverse();

  void _alElegirPestana(int i) {
    if (i == _tab) {
      _clavesNavegador[i].currentState?.popUntil((r) => r.isFirst);
    } else {
      setState(() => _tab = i);
    }
    _mostrarNavBar();
    _acumuladoScroll = 0;
  }

  Widget _contenido(int index) => switch (index) {
        0 => const InicioScreen(),
        1 => const IndiceScreen(),
        2 => const BusquedaScreen(),
        3 => const FavoritosScreen(),
        _ => const SizedBox.shrink(),
      };

  Widget _pestana(int index) {
    return TickerMode(
      enabled: _tab == index,
      child: ExcludeFocus(
        excluding: _tab != index,
        child: Navigator(
          key: _clavesNavegador[index],
          onGenerateRoute: (settings) =>
              MaterialPageRoute(builder: (_) => _contenido(index)),
        ),
      ),
    );
  }

  /// Inner stack → previous tab → let the system close the app.
  void _alIntentarVolver(bool didPop, Object? _) {
    if (didPop) return;
    final nav = _clavesNavegador[_tab].currentState;
    if (nav?.canPop() ?? false) {
      nav!.pop();
      return;
    }
    if (_tab != 0) {
      setState(() => _tab = 0);
      return;
    }
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _alIntentarVolver,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              ThemeData.estimateBrightnessForColor(c.sepia) == Brightness.dark
                  ? Brightness.light
                  : Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
        ),
        child: Scaffold(
          extendBody: true,
          resizeToAvoidBottomInset: false,
          body: NavBarScope(
            mostrarNavBar: _mostrarNavBarCallback,
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.depth == 0) _alHacerScroll(n);
                return false;
              },
              child: Stack(
                children: [
                  IndexedStack(
                    index: _tab,
                    children: List.generate(_tabs, _pestana),
                  ),
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: MediaQuery.paddingOf(context).bottom + 16,
                    child: AnimatedBuilder(
                      animation: _animacion,
                      builder: (context, child) {
                        final t = _animacion.value;
                        return IgnorePointer(
                          ignoring: t > 0.5,
                          child: FractionalTranslation(
                            translation: Offset(0, t * 1.5),
                            child: Opacity(
                                opacity: (1 - t).clamp(0.0, 1.0), child: child),
                          ),
                        );
                      },
                      // Built once, outside the animation callback.
                      child: MediaQuery(
                        data: MediaQuery.of(context)
                            .copyWith(textScaler: TextScaler.noScaling),
                        child: _PildoraFlotante(
                          seleccionado: _tab,
                          alElegir: _alElegirPestana,
                        ),
                      ),
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

class _PildoraFlotante extends StatelessWidget {
  final int seleccionado;
  final ValueChanged<int> alElegir;

  const _PildoraFlotante({required this.seleccionado, required this.alElegir});

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final l10n = L10n.of(context);

    final items = <_ItemNav>[
      _ItemNav(Icons.wb_sunny_outlined, Icons.wb_sunny, l10n.tabInicio,
          l10n.semTabInicio),
      _ItemNav(Icons.menu_book_outlined, Icons.menu_book, l10n.tabIndice,
          l10n.semTabIndice),
      _ItemNav(Icons.search, Icons.search, l10n.tabBuscar, l10n.semTabBuscar),
      _ItemNav(Icons.favorite_border, Icons.favorite, l10n.tabFavoritos,
          l10n.semTabFavoritos),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: c.sepia,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: c.oro.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
              color: c.sombra,
              blurRadius: 20,
              offset: const Offset(0, 6),
              spreadRadius: -2),
        ],
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: _BotonNav(
                item: items[i],
                seleccionado: i == seleccionado,
                alPulsar: () => alElegir(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _BotonNav extends StatelessWidget {
  final _ItemNav item;
  final bool seleccionado;
  final VoidCallback alPulsar;

  const _BotonNav({
    required this.item,
    required this.seleccionado,
    required this.alPulsar,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final color = seleccionado ? c.oroClaro : c.sobreSepia.withValues(alpha: .54);

    return Semantics(
      label: item.semantica,
      button: true,
      selected: seleccionado,
      child: InkWell(
        onTap: alPulsar,
        borderRadius: BorderRadius.circular(40),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                width: seleccionado ? 28 : 0,
                height: seleccionado ? 3 : 0,
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: c.oroClaro,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ExcludeSemantics(
                child: Icon(
                  seleccionado ? item.iconoActivo : item.icono,
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(height: 4),
              ExcludeSemantics(
                child: Text(
                  item.etiqueta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.tipos.navLabel.copyWith(
                    color: color,
                    fontWeight:
                        seleccionado ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemNav {
  final IconData icono;
  final IconData iconoActivo;
  final String etiqueta;
  final String semantica;
  const _ItemNav(this.icono, this.iconoActivo, this.etiqueta, this.semantica);
}
