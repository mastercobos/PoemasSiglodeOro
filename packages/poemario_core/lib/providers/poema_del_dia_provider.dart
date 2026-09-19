import 'package:flutter/material.dart';

import '../data/poema.dart';
import '../data/poema_repository.dart';
import '../data/preferencias.dart';
import '../domain/seleccion_diaria.dart';
import 'ajustes_provider.dart';

/// Owns today's selection and the short history of what was shown.
///
/// The selection used to be recomputed inside `build()`, allocating four
/// filtered lists every frame, and the date was captured once in `initState`
/// so an app left open past midnight kept showing yesterday. This provider
/// caches on (date, active authors) and refreshes when the app resumes.
///
/// It also persists the authors of the last few days. That history is what
/// the "don't repeat an author" rule consults, instead of re-deriving
/// yesterday's pick from today's pool — which gave the wrong answer whenever
/// the user changed their filter overnight.
class PoemaDelDiaProvider extends ChangeNotifier with WidgetsBindingObserver {
  static const _claveHistorial = 'historial_autores';
  static const _claveUltimaFecha = 'historial_fecha';

  final Anthology _anthology;
  final Preferencias _prefs;
  final AjustesProvider _ajustes;

  List<String> _historial;
  DateTime _hoy;
  Set<String> _activosEnCache = const {};
  SeleccionDiaria? _cache;

  PoemaDelDiaProvider({
    required Anthology anthology,
    required Preferencias prefs,
    required AjustesProvider ajustes,
  })  : _anthology = anthology,
        _prefs = prefs,
        _ajustes = ajustes,
        _historial = prefs.leerLista(_claveHistorial),
        _hoy = _soloFecha(DateTime.now()) {
    _ajustes.addListener(_invalidar);
    WidgetsBinding.instance.addObserver(this);
  }

  /// Poems in the pool after the author filter.
  List<Poema> get pool {
    final activos = _ajustes.autoresActivos;
    return [
      for (final p in _anthology.poemas)
        if (activos.contains(p.autor)) p,
    ];
  }

  SeleccionDiaria get seleccion {
    final activos = _ajustes.autoresActivos;
    final cache = _cache;
    if (cache != null &&
        cache.fecha == _hoy &&
        _activosEnCache.length == activos.length &&
        _activosEnCache.containsAll(activos)) {
      return cache;
    }
    final nueva = SeleccionDiariaService.paraFecha(
      pool: pool,
      fecha: _hoy,
      autoresRecientes: _historial,
    );
    _cache = nueva;
    _activosEnCache = activos;
    return nueva;
  }

  List<Poema> get poemasDelDia => seleccion.poemas;

  List<String> get historial => List.unmodifiable(_historial);

  /// Records today's authors once the user has actually seen them. Called from
  /// the home screen's first frame. Idempotent per day.
  Future<void> registrarVisto() async {
    final ultima = _prefs.leerTexto(_claveUltimaFecha);
    final hoyTexto = _hoy.toIso8601String();
    if (ultima == hoyTexto) return;

    _historial = [
      ...seleccion.autores,
      ..._historial,
    ].take(SeleccionDiariaService.ventanaHistorial *
            SeleccionDiariaService.poemasPorDia)
        .toList();

    await _prefs.guardarLista(_claveHistorial, _historial);
    await _prefs.guardarTexto(_claveUltimaFecha, hoyTexto);
  }

  void _invalidar() {
    _cache = null;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final ahora = _soloFecha(DateTime.now());
    if (ahora != _hoy) {
      _hoy = ahora;
      _invalidar();
    }
  }

  @override
  void dispose() {
    _ajustes.removeListener(_invalidar);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  static DateTime _soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);
}
