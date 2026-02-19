import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/poema.dart';

class FavoritosProvider extends ChangeNotifier {
  static const _key = 'favoritos';

  final List<Poema> _todosLosPoemas;
  final Set<int> _idsFavoritos = {};

  FavoritosProvider(this._todosLosPoemas) {
    _cargar();
  }

  List<Poema> get favoritos => _todosLosPoemas
      .where((p) => _idsFavoritos.contains(p.id))
      .toList();

  bool esFavorito(Poema poema) => _idsFavoritos.contains(poema.id);

  Future<void> toggleFavorito(Poema poema) async {
    if (_idsFavoritos.contains(poema.id)) {
      _idsFavoritos.remove(poema.id);
    } else {
      _idsFavoritos.add(poema.id);
    }
    notifyListeners();
    await _guardar();
  }

  Future<void> _cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final guardados = prefs.getStringList(_key) ?? [];
    _idsFavoritos.addAll(guardados.map(int.parse));
    notifyListeners();
  }

  Future<void> _guardar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _key, _idsFavoritos.map((id) => id.toString()).toList());
  }
}
