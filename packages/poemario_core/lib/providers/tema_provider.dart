import 'package:flutter/material.dart';

import '../data/preferencias.dart';

/// Light / dark / follow-the-system.
///
/// Same behaviour as before, minus the async constructor: the stored value is
/// read synchronously at construction, so the app never renders one frame in
/// the wrong theme before correcting itself.
class TemaProvider extends ChangeNotifier {
  static const _clave = 'tema';

  final Preferencias _prefs;
  ThemeMode _modo;

  TemaProvider(this._prefs) : _modo = _desdeTexto(_prefs.leerTexto(_clave));

  ThemeMode get modo => _modo;

  Future<void> establecer(ThemeMode modo) async {
    if (modo == _modo) return;
    _modo = modo;
    notifyListeners();
    await _prefs.guardarTexto(_clave, _aTexto(modo));
  }

  static ThemeMode _desdeTexto(String? s) => switch (s) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  static String _aTexto(ThemeMode m) => switch (m) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
}
