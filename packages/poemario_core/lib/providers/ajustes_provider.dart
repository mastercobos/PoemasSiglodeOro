import 'package:flutter/foundation.dart';

import '../data/preferencias.dart';

/// Which authors take part in "poems of the day".
///
/// Stores the **excluded** authors, not the selected ones. The original stored
/// selections, which had two consequences:
///
/// * an author added in a later release was missing from every existing user's
///   rotation, with nothing in the UI to explain it;
/// * names of authors removed from the data accumulated in preferences forever.
///
/// Inverting the set fixes both: unknown authors are active by default, and
/// exclusions are filtered against the current anthology on load.
///
/// The constructor race is gone too. The old one set "everything selected",
/// then let an unawaited `_cargar()` overwrite whatever the user toggled in
/// the meantime.
class AjustesProvider extends ChangeNotifier {
  static const _clave = 'autores_excluidos';

  final List<String> todosLosAutores;
  final Preferencias _prefs;
  final Set<String> _excluidos;

  AjustesProvider({
    required this.todosLosAutores,
    required Preferencias prefs,
  })  : _prefs = prefs,
        _excluidos = prefs
            .leerLista(_clave)
            .where(todosLosAutores.contains)
            .toSet();

  /// A [Set], because the home screen tests membership once per poem. The old
  /// getter rebuilt a `List` inside the loop and did a linear `contains` on it
  /// — O(n·m) allocations on every frame of the home tab.
  Set<String> get autoresActivos =>
      {for (final a in todosLosAutores) if (!_excluidos.contains(a)) a};

  bool estaActivo(String autor) => !_excluidos.contains(autor);

  int get totalActivos => todosLosAutores.length - _excluidos.length;

  bool get todosSeleccionados => _excluidos.isEmpty;

  bool get ningunoSeleccionado => totalActivos == 0;

  Future<void> alternarAutor(String autor) async {
    if (!_excluidos.remove(autor)) _excluidos.add(autor);
    notifyListeners();
    await _guardar();
  }

  Future<void> seleccionarTodos() async {
    if (_excluidos.isEmpty) return;
    _excluidos.clear();
    notifyListeners();
    await _guardar();
  }

  Future<void> deseleccionarTodos() async {
    if (_excluidos.length == todosLosAutores.length) return;
    _excluidos
      ..clear()
      ..addAll(todosLosAutores);
    notifyListeners();
    await _guardar();
  }

  Future<void> _guardar() => _prefs.guardarLista(_clave, _excluidos);
}
