import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AjustesProvider extends ChangeNotifier {
  static const _key = 'autores_seleccionados';

  Set<String>? _autoresSeleccionados; // null = todos activos
  final List<String> todosLosAutores;

  AjustesProvider(this.todosLosAutores) {
    _cargar();
  }

  List<String> get autoresActivos {
    if (_autoresSeleccionados == null || _autoresSeleccionados!.isEmpty) {
      return [];
    }
    return todosLosAutores
        .where((a) => _autoresSeleccionados!.contains(a))
        .toList();
  }

  bool estaActivo(String autor) {
    if (_autoresSeleccionados == null) return true;
    return _autoresSeleccionados!.contains(autor);
  }

  Future<void> toggleAutor(String autor) async {
    _autoresSeleccionados ??= Set.from(todosLosAutores);
    if (_autoresSeleccionados!.contains(autor)) {
      _autoresSeleccionados!.remove(autor);
    } else {
      _autoresSeleccionados!.add(autor);
    }
    notifyListeners();
    await _guardar();
  }

  Future<void> seleccionarTodos() async {
    _autoresSeleccionados = Set.from(todosLosAutores);
    notifyListeners();
    await _guardar();
  }

  Future<void> deseleccionarTodos() async {
    _autoresSeleccionados = {};
    notifyListeners();
    await _guardar();
  }

  Future<void> _cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final guardados = prefs.getStringList(_key);
    if (guardados != null) {
      _autoresSeleccionados = Set.from(guardados);
    }
    notifyListeners();
  }

  Future<void> _guardar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _key, (_autoresSeleccionados ?? <String>{}).toList());
  }
}
