import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/poema.dart';
import 'agenda_avisos.dart';
import 'planificador_avisos.dart';

export 'agenda_avisos.dart' show EstadoPermisoAviso, SolicitudDePoema;

/// Talks to the platform. Everything decidable without the OS lives in
/// [PlanificadorAvisos]; this class only dispatches.
class ServicioAvisos implements AgendaAvisos {
  /// Android notification channel id, the same in every app (channels are
  /// per-install, so apps cannot collide). Must never change: doing so orphans
  /// the user's per-channel settings.
  static const canalId = 'poema_diario';

  ServicioAvisos({
    required this.canalNombre,
    required this.canalDescripcion,
    required this.solicitudes,
  });

  final String canalNombre;
  final String canalDescripcion;

  /// Where notification taps are published.
  final SolicitudDePoema solicitudes;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _iniciado = false;

  Future<void> iniciar() async {
    if (_iniciado) return;

    // `zonedSchedule` needs a real time zone, not a UTC offset: without this,
    // a reminder set for 09:00 drifts by an hour across a DST boundary.
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation(await FlutterTimezone.getLocalTimezone()));
    } catch (e) {
      debugPrint('ServicioAvisos: zona horaria desconocida ($e), usando UTC');
    }

    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(
          // Asked for explicitly later, from the settings screen, so the
          // system prompt arrives with context instead of on first launch.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: _alTocar,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(AndroidNotificationChannel(
          canalId,
          canalNombre,
          description: canalDescripcion,
          importance: Importance.defaultImportance,
        ));

    // A tap that cold-started the app doesn't go through the callback above.
    final lanzamiento = await _plugin.getNotificationAppLaunchDetails();
    if (lanzamiento?.didNotificationLaunchApp ?? false) {
      final payload = lanzamiento!.notificationResponse?.payload;
      if (payload != null && payload.isNotEmpty) solicitudes.pedir(payload);
    }

    _iniciado = true;
  }

  void _alTocar(NotificationResponse respuesta) {
    final payload = respuesta.payload;
    if (payload != null && payload.isNotEmpty) solicitudes.pedir(payload);
  }

  /// Whether the user has already granted notification permission.
  @override
  Future<bool> permisoConcedido() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.areNotificationsEnabled() ?? false;
    }
    // iOS gives no cheap way to read the current state without prompting, so
    // the provider tracks its own "asked and granted" flag instead.
    return true;
  }

  /// Asks for permission. Call this from a deliberate user action — a settings
  /// toggle — not on first launch: the prompt is one-shot on Android 13+, and
  /// a denial there is expensive to recover from.
  @override
  Future<EstadoPermisoAviso> pedirPermiso() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final ok = await android.requestNotificationsPermission() ?? false;
      return ok ? EstadoPermisoAviso.concedido : EstadoPermisoAviso.denegado;
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final ok = await ios.requestPermissions(alert: true, badge: true, sound: true);
      return (ok ?? false)
          ? EstadoPermisoAviso.concedido
          : EstadoPermisoAviso.denegado;
    }

    return EstadoPermisoAviso.noSoportado;
  }

  /// Replaces the whole schedule.
  ///
  /// Called whenever anything the plan depends on changes: the reminder time,
  /// the author filter, the history, or simply the app coming back to the
  /// foreground (which is what keeps the 14-day window topped up).
  @override
  Future<void> reprogramar({
    required List<Poema> pool,
    required TimeOfDay hora,
    required TextosAviso textos,
    List<String> autoresRecientes = const [],
  }) async {
    await cancelarTodo();

    final avisos = PlanificadorAvisos.construir(
      pool: pool,
      desde: DateTime.now(),
      hora: hora,
      textos: textos,
      autoresRecientes: autoresRecientes,
    );

    for (final aviso in avisos) {
      try {
        await _plugin.zonedSchedule(
          aviso.id,
          aviso.titulo,
          aviso.cuerpo,
          tz.TZDateTime.from(aviso.cuando, tz.local),
          _detalles(aviso.cuerpo),
          payload: aviso.payload,
          // Inexact on purpose. Exact alarms need SCHEDULE_EXACT_ALARM, which
          // Google requires a justification form for and rejects for anything
          // that isn't an alarm clock or a calendar. A poem reminder arriving
          // within ~15 minutes of nine o'clock is fine.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents:
              aviso.repiteADiario ? DateTimeComponents.time : null,
        );
      } catch (e) {
        debugPrint('ServicioAvisos: no se pudo programar $aviso ($e)');
      }
    }
  }

  @override
  Future<void> cancelarTodo() async {
    for (var i = 0; i < PlanificadorAvisos.diasConTitulo; i++) {
      await _plugin.cancel(PlanificadorAvisos.primerId + i);
    }
    await _plugin.cancel(PlanificadorAvisos.idGenerico);
  }

  /// Debug helper: what the OS currently has queued.
  Future<List<PendingNotificationRequest>> pendientes() =>
      _plugin.pendingNotificationRequests();

  NotificationDetails _detalles(String cuerpo) => NotificationDetails(
        android: AndroidNotificationDetails(
          canalId,
          canalNombre,
          channelDescription: canalDescripcion,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          // A poem title plus author often exceeds one line on a phone.
          styleInformation: BigTextStyleInformation(cuerpo),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: true,
        ),
      );
}
