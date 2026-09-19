import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;

import '../data/poema.dart';
import '../domain/seleccion_diaria.dart';

/// One notification to be handed to the OS.
@immutable
class AvisoProgramado {
  /// Stable slot number. Rescheduling reuses the same ids, so the OS replaces
  /// rather than accumulates.
  final int id;

  final DateTime cuando;
  final String titulo;
  final String cuerpo;

  /// Poem id, used to deep-link straight into the poem when tapped. Null for
  /// the generic fallback.
  final String? payload;

  /// True for the single repeating reminder that covers the period after the
  /// precomputed window runs out.
  final bool repiteADiario;

  const AvisoProgramado({
    required this.id,
    required this.cuando,
    required this.titulo,
    required this.cuerpo,
    this.payload,
    this.repiteADiario = false,
  });

  @override
  String toString() =>
      'AvisoProgramado($id, $cuando, "$cuerpo", payload: $payload)';
}

/// The localised strings a schedule needs. Passed in rather than looked up,
/// because planning must work without a [BuildContext].
@immutable
class TextosAviso {
  final String titulo;
  final String Function(Poema) cuerpo;
  final String cuerpoGenerico;

  const TextosAviso({
    required this.titulo,
    required this.cuerpo,
    required this.cuerpoGenerico,
  });
}

/// Builds the schedule.
///
/// The interesting property: because [SeleccionDiariaService] is deterministic,
/// we can name tomorrow's poem in tomorrow's notification — and the app will
/// show that same poem when the reader opens it. A generic "new poems today"
/// reminder gets swiped away within a week; "Volverán las oscuras golondrinas
/// — Bécquer" is an invitation.
abstract final class PlanificadorAvisos {
  /// Days named individually. iOS caps pending notifications at 64, and the
  /// plan is rebuilt on every resume, so a fortnight is comfortable.
  static const diasConTitulo = 14;

  /// Slot ids. Kept apart from any other notification the app might add later.
  static const primerId = 1000;
  static const idGenerico = 999;

  static List<AvisoProgramado> construir({
    required List<Poema> pool,
    required DateTime desde,
    required TimeOfDay hora,
    required TextosAviso textos,
    List<String> autoresRecientes = const [],
  }) {
    if (pool.isEmpty) return const [];

    final serie = SeleccionDiariaService.serie(
      pool: pool,
      desde: desde,
      dias: diasConTitulo,
      autoresRecientes: autoresRecientes,
    );

    final avisos = <AvisoProgramado>[];
    for (var i = 0; i < serie.length; i++) {
      final dia = serie[i];
      if (dia.poemas.isEmpty) continue;

      final cuando = _aLaHora(dia.fecha, hora);
      // Today's slot has already passed if the reader is up after the reminder
      // time; skip it rather than firing immediately.
      if (!cuando.isAfter(desde)) continue;

      final poema = dia.poemas.first;
      avisos.add(AvisoProgramado(
        id: primerId + i,
        cuando: cuando,
        titulo: textos.titulo,
        cuerpo: textos.cuerpo(poema),
        payload: poema.id,
      ));
    }

    // Backstop: if the reader doesn't open the app for a fortnight the named
    // window runs dry, so one repeating generic reminder takes over from the
    // day after it ends.
    avisos.add(AvisoProgramado(
      id: idGenerico,
      cuando: _aLaHora(
        _soloFecha(desde).add(const Duration(days: diasConTitulo)),
        hora,
      ),
      titulo: textos.titulo,
      cuerpo: textos.cuerpoGenerico,
      repiteADiario: true,
    ));

    return avisos;
  }

  static DateTime _aLaHora(DateTime fecha, TimeOfDay hora) =>
      DateTime(fecha.year, fecha.month, fecha.day, hora.hour, hora.minute);

  static DateTime _soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);
}
