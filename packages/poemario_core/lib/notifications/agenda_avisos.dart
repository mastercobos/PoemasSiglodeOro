import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;

import '../data/poema.dart';
import 'planificador_avisos.dart';

/// Poem id requested by a notification tap, including the tap that cold-started
/// the app.
///
/// A separate object rather than a field on the platform service, so the shell
/// can depend on *this* — which a test can create in one line — instead of on
/// the notification plugin.
class SolicitudDePoema extends ValueNotifier<String?> {
  SolicitudDePoema() : super(null);

  void pedir(String id) => value = id;

  /// Reads and clears in one step, so a rebuild can't handle the same tap
  /// twice.
  String? tomar() {
    final id = value;
    if (id != null) value = null;
    return id;
  }
}

/// What [NotificacionesProvider] needs from the OS.
///
/// Narrow on purpose: the provider holds all the policy (when to reschedule,
/// what to do about a revoked permission) and none of the platform, so the
/// policy is testable without a plugin.
abstract interface class AgendaAvisos {
  Future<bool> permisoConcedido();

  Future<EstadoPermisoAviso> pedirPermiso();

  Future<void> reprogramar({
    required List<Poema> pool,
    required TimeOfDay hora,
    required TextosAviso textos,
    List<String> autoresRecientes,
  });

  Future<void> cancelarTodo();
}

/// Result of asking the OS for permission.
enum EstadoPermisoAviso { concedido, denegado, noSoportado }
