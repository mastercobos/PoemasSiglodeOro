import 'dart:async';

import 'package:flutter/foundation.dart';

import '../donaciones/tienda_propinas.dart';

enum EstadoPropinas {
  inicial,
  cargando,
  lista,

  /// No store, or none of the configured products exist. The UI hides the
  /// whole section, so an app can ship before its store products are set up.
  noDisponible,
}

/// The tip jar: which amounts to offer and how the last purchase went.
///
/// Holds no platform code; everything store-specific is behind
/// [TiendaPropinas]. Call [iniciar] once at startup (not from the
/// constructor).
class PropinasProvider extends ChangeNotifier {
  final TiendaPropinas _tienda;
  final Set<String> _ids;
  StreamSubscription<ResultadoPropina>? _suscripcion;

  EstadoPropinas _estado = EstadoPropinas.inicial;
  List<Propina> _propinas = const [];
  bool _comprando = false;
  ResultadoPropina? _resultado;

  PropinasProvider({
    required TiendaPropinas tienda,
    required Set<String> ids,
  })  : _tienda = tienda,
        _ids = ids;

  EstadoPropinas get estado => _estado;
  List<Propina> get propinas => _propinas;
  bool get comprando => _comprando;

  /// Outcome of the most recent attempt, until the next one starts.
  ResultadoPropina? get resultado => _resultado;

  Future<void> iniciar() async {
    if (_estado != EstadoPropinas.inicial) return;
    if (_ids.isEmpty) {
      _estado = EstadoPropinas.noDisponible;
      return;
    }
    _estado = EstadoPropinas.cargando;
    notifyListeners();
    try {
      // Subscribed before the query, so a purchase left over from a previous
      // session is not missed.
      _suscripcion = _tienda.resultados.listen(_alResultado);
      if (await _tienda.iniciar()) {
        final lista = [...await _tienda.consultar(_ids)]
          ..sort((a, b) => a.valor.compareTo(b.valor));
        _propinas = lista;
      }
    } catch (e) {
      // Offline, store not signed in, plugin missing: the tip jar is optional,
      // so it disappears rather than reporting an error nobody can act on.
      debugPrint('Tip jar unavailable: $e');
      _propinas = const [];
    }
    _estado = _propinas.isEmpty
        ? EstadoPropinas.noDisponible
        : EstadoPropinas.lista;
    notifyListeners();
  }

  Future<void> comprar(Propina propina) async {
    if (_comprando) return;
    _comprando = true;
    _resultado = null;
    notifyListeners();
    try {
      await _tienda.comprar(propina);
    } catch (e) {
      debugPrint('Tip purchase failed to start: $e');
      _alResultado(ResultadoPropina.fallida);
    }
  }

  void _alResultado(ResultadoPropina r) {
    _comprando = false;
    _resultado = r;
    notifyListeners();
  }

  @override
  void dispose() {
    _suscripcion?.cancel();
    _tienda.cerrar();
    super.dispose();
  }
}
