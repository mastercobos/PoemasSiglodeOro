import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/seleccion_diaria.dart';
import 'poema_repository.dart';

/// Thin wrapper over [SharedPreferences].
///
/// Exists for three reasons: the instance is resolved once instead of on every
/// save; reads never throw, so a corrupt value can't crash startup from inside
/// an unawaited constructor call (`int.parse` on a bad string used to do
/// exactly that); and it owns the schema migrations.
class Preferencias {
  final SharedPreferences _prefs;
  final String _prefijo;

  Preferencias._(this._prefs, this._prefijo);

  static Future<Preferencias> abrir({String prefijo = ''}) async {
    final prefs = await SharedPreferences.getInstance();
    return Preferencias._(prefs, prefijo);
  }

  String _k(String clave) => '$_prefijo$clave';

  List<String> leerLista(String clave) {
    try {
      return _prefs.getStringList(_k(clave)) ?? const [];
    } catch (e) {
      debugPrint('Preferencias: lista ilegible en $clave ($e)');
      return const [];
    }
  }

  Future<void> guardarLista(String clave, Iterable<String> valores) =>
      _prefs.setStringList(_k(clave), valores.toList());

  String? leerTexto(String clave) {
    try {
      return _prefs.getString(_k(clave));
    } catch (_) {
      return null;
    }
  }

  Future<void> guardarTexto(String clave, String valor) =>
      _prefs.setString(_k(clave), valor);

  bool leerBool(String clave, {bool porDefecto = false}) {
    try {
      return _prefs.getBool(_k(clave)) ?? porDefecto;
    } catch (_) {
      return porDefecto;
    }
  }

  Future<void> guardarBool(String clave, bool valor) =>
      _prefs.setBool(_k(clave), valor);

  int? leerEntero(String clave) {
    try {
      return _prefs.getInt(_k(clave));
    } catch (_) {
      return null;
    }
  }

  Future<void> guardarEntero(String clave, int valor) =>
      _prefs.setInt(_k(clave), valor);

  Future<void> borrar(String clave) => _prefs.remove(_k(clave));

  // ── Schema migrations ──────────────────────────────────────────────────

  /// Version of the on-disk schema. Bump when a migration is added.
  static const _esquemaActual = 3;
  static const _claveEsquema = 'esquema_prefs';

  /// Runs once per upgrade, before any provider reads.
  ///
  /// v1 → v2: favourites were stored as the poem's *index in poemas.json*.
  /// [anthology] still carries `indiceOriginal`, so we can translate the old
  /// integers into stable ids exactly once — while the file order still
  /// matches the one those integers were written against. Ship this migration
  /// before you ever reorder the JSON.
  Future<void> migrar(Anthology anthology) async {
    final version = leerEntero(_claveEsquema) ?? 1;
    if (version >= _esquemaActual) return;

    if (version < 2) {
      final antiguos = leerLista('favoritos');
      if (antiguos.isNotEmpty) {
        final porIndice = {
          for (final p in anthology.poemas) p.indiceOriginal: p,
        };
        final ids = <String>[
          for (final s in antiguos)
            if (porIndice[int.tryParse(s) ?? -1] case final p?) p.id,
        ];
        await guardarLista('favoritos_v2', ids);
        debugPrint('Migrados ${ids.length}/${antiguos.length} favoritos a ids '
            'estables.');
      }
      await borrar('favoritos');

      // v1 stored the *selected* authors, which meant an author added in a
      // later release was invisible to every existing user. v2 stores the
      // excluded ones instead, so new authors default to active.
      final seleccionados = leerLista('autores_seleccionados');
      if (seleccionados.isNotEmpty) {
        final excluidos = anthology.autores
            .where((a) => !seleccionados.contains(a))
            .toList();
        await guardarLista('autores_excluidos', excluidos);
      }
      await borrar('autores_seleccionados');
    }

    if (version < 3) {
      // v2 (1.1.0) stored the history *after* the last day seen: that day's
      // authors first, then the older ones. v3 stores it *before* that day,
      // so reschedules later the same day no longer avoid today's own
      // authors. Dropping the leading day recovers exactly what v2 used for
      // it; the date is unchanged.
      final antiguo = leerLista('historial_autores');
      final fecha = leerTexto('historial_fecha');
      if (fecha != null) {
        await guardarLista('historial_base',
            antiguo.skip(SeleccionDiariaService.poemasPorDia));
        await guardarTexto('historial_base_fecha', fecha);
      }
      await borrar('historial_autores');
      await borrar('historial_fecha');
    }

    await guardarEntero(_claveEsquema, _esquemaActual);
  }
}
