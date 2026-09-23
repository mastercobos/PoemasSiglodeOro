import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;

import '../data/poema.dart';
import '../domain/seleccion_diaria.dart';
import 'agenda_avisos.dart';

/// One notification to be handed to the OS.
@immutable
class AvisoProgramado {
  /// Stable slot number. Rescheduling reuses the same ids, so the OS replaces
  /// rather than accumulates.
  final int id;

  final DateTime cuando;
  final String titulo;
  final String cuerpo;

  /// What a tap opens. Always [SolicitudDePoema.inicio]: the notification
  /// names both poems of the day, so it opens the screen that shows both.
  final String payload;

  const AvisoProgramado({
    required this.id,
    required this.cuando,
    required this.titulo,
    required this.cuerpo,
    this.payload = SolicitudDePoema.inicio,
  });

  @override
  String toString() => 'AvisoProgramado($id, $cuando, "$cuerpo")';
}

/// The localised strings a schedule needs. Passed in rather than looked up,
/// because planning must work without a [BuildContext].
@immutable
class TextosAviso {
  final String titulo;

  /// One line of the body per poem of the day: title, author, opening verse.
  final String Function(Poema) linea;

  /// Body of the reminders past the named window, whose poems aren't worked
  /// out in advance.
  final String cuerpoGenerico;

  const TextosAviso({
    required this.titulo,
    required this.linea,
    required this.cuerpoGenerico,
  });
}

/// Builds the schedule: **one notification a day**, at the reader's hour.
///
/// Because [SeleccionDiariaService] is deterministic, the notification can
/// name that morning's poems in advance — one line each — and the app will
/// show those same poems when the reader taps through to the home screen. A
/// generic "new poems today" gets swiped away within a week; "Volverán las
/// oscuras golondrinas — Bécquer" is an invitation.
///
/// 1.1.0 also scheduled a generic reminder repeating daily "from day 15".
/// The plugin's daily repeat ignores the start date and fires from the next
/// occurrence of the time, so from the first day readers got it *alongside*
/// the named one: two notifications every morning. Days past the named window
/// are now one-shot generic reminders instead, and the old repeating slot is
/// still cancelled on every reschedule so upgraded installs lose it.
abstract final class PlanificadorAvisos {
  /// Days whose poems are named. iOS caps pending notifications at 64, and
  /// the plan is rebuilt on every resume, so a fortnight is comfortable.
  static const diasConTitulo = 14;

  /// One-shot generic reminders after the named window, for a reader who
  /// doesn't open the app for a while. Cheaper to plan than named days: no
  /// selection to compute.
  static const diasGenericos = 16;

  /// Slot ids: `primerId + day`, for every named and generic day. Kept apart
  /// from any other notification the app might add later.
  static const primerId = 1000;

  /// The 1.1.0 repeating reminder. Never scheduled again; only cancelled.
  static const idRepetidoAntiguo = 999;

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
    for (var d = 0; d < diasConTitulo + diasGenericos; d++) {
      // Date parts, not `add(Duration(days: d))`: see the note on
      // `SeleccionDiariaService._diaMas` about the day the clocks go back.
      final cuando = _aLaHora(
          DateTime(desde.year, desde.month, desde.day + d), hora);
      // Today's slot has already passed if the reader is up after the reminder
      // time; skip it rather than firing immediately.
      if (!cuando.isAfter(desde)) continue;

      final String cuerpo;
      if (d < serie.length) {
        final poemas = serie[d].poemas;
        if (poemas.isEmpty) continue;
        cuerpo = poemas.map(textos.linea).join('\n');
      } else {
        cuerpo = textos.cuerpoGenerico;
      }
      avisos.add(AvisoProgramado(
        id: primerId + d,
        cuando: cuando,
        titulo: textos.titulo,
        cuerpo: cuerpo,
      ));
    }
    return avisos;
  }

  static DateTime _aLaHora(DateTime fecha, TimeOfDay hora) =>
      DateTime(fecha.year, fecha.month, fecha.day, hora.hour, hora.minute);
}
