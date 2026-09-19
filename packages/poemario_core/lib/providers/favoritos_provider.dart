import 'package:flutter/foundation.dart';

import '../data/poema.dart';
import '../data/poema_repository.dart';
import '../data/preferencias.dart';

/// Saved poems.
///
/// Two structural changes from the original:
///
/// * ids are stable strings, so the set survives an edit to `poemas.json`;
/// * nothing async happens in the constructor. The old version kicked off an
///   unawaited `_cargar()` there, so a parse error surfaced as an unhandled
///   async exception and the user's favourites silently vanished. Loading is
///   now synchronous, from a [Preferencias] that `bootstrap` already opened.
class FavoritosProvider extends ChangeNotifier {
  static const _clave = 'favoritos_v2';

  final Anthology _anthology;
  final Preferencias _prefs;
  final Set<String> _ids;

  FavoritosProvider({
    required Anthology anthology,
    required Preferencias prefs,
  })  : _anthology = anthology,
        _prefs = prefs,
        // Ids that no longer resolve are dropped here rather than producing
        // nulls downstream — normal after a poem is removed from the data.
        _ids = prefs
            .leerLista(_clave)
            .where((id) => anthology.porId(id) != null)
            .toSet();

  /// Saved poems in anthology order.
  List<Poema> get favoritos =>
      [for (final p in _anthology.poemas) if (_ids.contains(p.id)) p];

  int get total => _ids.length;

  bool esFavorito(Poema poema) => _ids.contains(poema.id);

  /// Returns the new state, so the caller can word its snackbar without
  /// re-reading the provider (the old screen read the *pre-toggle* value and
  /// showed the opposite message when the write raced the rebuild).
  Future<bool> alternar(Poema poema) async {
    final ahoraEsFavorito = !_ids.contains(poema.id);
    if (ahoraEsFavorito) {
      _ids.add(poema.id);
    } else {
      _ids.remove(poema.id);
    }
    notifyListeners();
    await _guardar();
    return ahoraEsFavorito;
  }

  Future<void> _guardar() => _prefs.guardarLista(_clave, _ids);
}
