import 'package:flutter/foundation.dart';

import '../data/poema.dart';

/// The poems chosen for one calendar day.
@immutable
class SeleccionDiaria {
  final DateTime fecha;
  final List<Poema> poemas;

  const SeleccionDiaria(this.fecha, this.poemas);

  List<String> get autores => [for (final p in poemas) p.autor];
}

/// Picks the poems of the day.
///
/// Pulled out of `_InicioScreenState` because the notification scheduler needs
/// it too, and needs it without a `BuildContext`, without Flutter running, and
/// for *future* dates. Everything here is pure: same inputs, same output, on
/// any device, forever. That property is what lets us schedule a notification
/// two weeks ahead that names the poem the app will actually show that morning.
///
/// It also fixes a real bug in the original. To avoid repeating an author, the
/// old code re-derived *yesterday's* pick from *today's* pool. If the user
/// changed their author filter overnight, it was comparing against a poem that
/// was never shown. History is now an explicit input, carried forward by
/// [serie] and persisted by the provider.
abstract final class SeleccionDiariaService {
  /// How many recent days of authors to avoid repeating.
  static const ventanaHistorial = 2;

  /// Poems shown per day.
  static const poemasPorDia = 2;

  /// One day.
  ///
  /// [autoresRecientes] are the authors shown on the previous days, most
  /// recent first. Poems by those authors are avoided when the pool is big
  /// enough to allow it.
  static SeleccionDiaria paraFecha({
    required List<Poema> pool,
    required DateTime fecha,
    List<String> autoresRecientes = const [],
  }) {
    if (pool.isEmpty) return SeleccionDiaria(_dia(fecha), const []);

    // Sort by id so the result never depends on the order the caller happened
    // to build the pool in. Without this, filtering by author could reshuffle
    // the list and change the day's poem.
    final ordenado = [...pool]..sort((a, b) => a.id.compareTo(b.id));

    final evitar = autoresRecientes.take(ventanaHistorial).toSet();
    var semilla = _semilla(fecha);

    final elegidos = <Poema>[];
    final autoresUsados = <String>{};

    for (var n = 0; n < poemasPorDia; n++) {
      semilla = _siguiente(semilla);

      // Preference order: not shown recently and not already used today →
      // just not used today → anything not already picked. Each fallback only
      // kicks in for small anthologies or a heavily filtered pool.
      final candidatos = _primerNoVacio([
        () => ordenado
            .where((p) =>
                !evitar.contains(p.autor) && !autoresUsados.contains(p.autor))
            .toList(),
        () => ordenado
            .where((p) => !autoresUsados.contains(p.autor))
            .toList(),
        () => ordenado.where((p) => !elegidos.contains(p)).toList(),
      ]);

      if (candidatos.isEmpty) break;
      final elegido = candidatos[semilla % candidatos.length];
      elegidos.add(elegido);
      autoresUsados.add(elegido.autor);
    }

    return SeleccionDiaria(_dia(fecha), List.unmodifiable(elegidos));
  }

  /// A run of consecutive days, each one avoiding the authors of the days
  /// before it. This is what the notification scheduler calls to fill its
  /// two-week window in one pass.
  static List<SeleccionDiaria> serie({
    required List<Poema> pool,
    required DateTime desde,
    required int dias,
    List<String> autoresRecientes = const [],
  }) {
    final resultado = <SeleccionDiaria>[];
    var historial = [...autoresRecientes];

    for (var d = 0; d < dias; d++) {
      final seleccion = paraFecha(
        pool: pool,
        fecha: _diaMas(desde, d),
        autoresRecientes: historial,
      );
      resultado.add(seleccion);
      historial = _avanzar(historial, seleccion);
    }
    return resultado;
  }

  /// The history in force on [fecha], given the history that was in force on
  /// an earlier day [desde].
  ///
  /// Every day in between counts as shown, whether or not the reader opened
  /// the app. That is what the notification schedule assumes when it names
  /// days 2–14 in advance, so the app has to assume it too: if a skipped day
  /// were left out of the history, the next morning's pick would avoid a
  /// different set of authors from the one its notification was planned
  /// against, and the two would name different poems.
  ///
  /// Gaps longer than [maxDias] return [historialDesde] unchanged. Nothing
  /// named that far ahead is still pending, so any consistent answer will do,
  /// and it keeps a reader returning after a year from replaying the year.
  static List<String> historialPara({
    required List<Poema> pool,
    required DateTime desde,
    required List<String> historialDesde,
    required DateTime fecha,
    int maxDias = 31,
  }) {
    final dias = _diasEntre(desde, fecha);
    if (dias <= 0 || dias > maxDias) return historialDesde;
    var historial = [...historialDesde];
    for (final dia in serie(
        pool: pool,
        desde: desde,
        dias: dias,
        autoresRecientes: historialDesde)) {
      historial = _avanzar(historial, dia);
    }
    return historial;
  }

  /// The history after [seleccion] has been shown: its authors first, then
  /// the older ones, trimmed to what the rule can ever consult.
  static List<String> _avanzar(
          List<String> historial, SeleccionDiaria seleccion) =>
      [...seleccion.autores, ...historial]
          .take(ventanaHistorial * poemasPorDia)
          .toList();

  /// [d] plus [n] calendar days. Built from the date parts rather than by
  /// adding `Duration(days: n)`: local midnight plus 24 hours lands on the
  /// same date again on the 25-hour day the clocks go back, which used to
  /// repeat that day and shift every notification after it by one.
  static DateTime _diaMas(DateTime d, int n) =>
      DateTime(d.year, d.month, d.day + n);

  /// Whole calendar days from [a] to [b], immune to DST for the same reason.
  static int _diasEntre(DateTime a, DateTime b) =>
      DateTime.utc(b.year, b.month, b.day)
          .difference(DateTime.utc(a.year, a.month, a.day))
          .inDays;

  /// Date-only, so a pick never changes as the clock advances through the day.
  static DateTime _dia(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Deterministic per calendar date.
  static int _semilla(DateTime fecha) =>
      fecha.year * 10000 + fecha.month * 100 + fecha.day;

  /// Numerical Recipes LCG, masked to 31 bits so it behaves identically on the
  /// VM and on the web (where ints are doubles).
  static int _siguiente(int s) => (s * 1664525 + 1013904223) & 0x7FFFFFFF;

  static List<Poema> _primerNoVacio(List<List<Poema> Function()> intentos) {
    for (final intento in intentos) {
      final r = intento();
      if (r.isNotEmpty) return r;
    }
    return const [];
  }
}
