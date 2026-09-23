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
///
/// What is stored is the history *in force on* a given day — before that
/// day's own poems — plus the date. Days since then are replayed from the
/// date alone ([SeleccionDiariaService.historialPara]). Storing the history
/// *after* today's poems, as 1.1.0 did, made every reschedule later in the
/// day recompute today while avoiding today's own authors, so from then on
/// each notification named a poem the app would not show.
class PoemaDelDiaProvider extends ChangeNotifier with WidgetsBindingObserver {
  static const claveHistorial = 'historial_base';
  static const claveFecha = 'historial_base_fecha';

  final Anthology _anthology;
  final Preferencias _prefs;
  final AjustesProvider _ajustes;

  /// History in force on [_fechaBase]. Empty with a null date on a fresh
  /// install.
  List<String> _base;
  DateTime? _fechaBase;

  DateTime _hoy;
  Set<String> _activosEnCache = const {};
  SeleccionDiaria? _cache;
  List<String> _historialEnCache = const [];

  PoemaDelDiaProvider({
    required Anthology anthology,
    required Preferencias prefs,
    required AjustesProvider ajustes,
  })  : _anthology = anthology,
        _prefs = prefs,
        _ajustes = ajustes,
        _base = prefs.leerLista(claveHistorial),
        _fechaBase = DateTime.tryParse(prefs.leerTexto(claveFecha) ?? ''),
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
    final poemas = pool;
    final fechaBase = _fechaBase;
    final historial = fechaBase == null
        ? _base
        : SeleccionDiariaService.historialPara(
            pool: poemas,
            desde: fechaBase,
            historialDesde: _base,
            fecha: _hoy,
          );
    final nueva = SeleccionDiariaService.paraFecha(
      pool: poemas,
      fecha: _hoy,
      autoresRecientes: historial,
    );
    _cache = nueva;
    _activosEnCache = activos;
    _historialEnCache = List.unmodifiable(historial);
    return nueva;
  }

  List<Poema> get poemasDelDia => seleccion.poemas;

  /// The history today's selection was made with — *not* including today's
  /// own authors. This is what the notification schedule must start from so
  /// that its first day reproduces today and every later day follows on.
  List<String> get historial {
    seleccion; // fills the cache
    return _historialEnCache;
  }

  /// Records that today was seen. Called from the home screen's first frame.
  /// Idempotent per day, and changes nothing the selection depends on: it
  /// only moves the replay's starting point forward to today.
  Future<void> registrarVisto() async {
    if (_fechaBase == _hoy) return;
    final base = historial;
    _base = base;
    _fechaBase = _hoy;
    await _prefs.guardarLista(claveHistorial, base);
    await _prefs.guardarTexto(claveFecha, _hoy.toIso8601String());
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
