import 'package:flutter/material.dart';

import '../data/preferencias.dart';
import '../notifications/agenda_avisos.dart';
import '../notifications/planificador_avisos.dart';
import 'poema_del_dia_provider.dart';

/// Owns the daily reminder setting and keeps the OS schedule in step with it.
///
/// Anything that changes the plan reschedules: the switch, the hour, the
/// author filter (a different pool means different poems on days 1–14), and
/// the app returning to the foreground, which is what refills the window for
/// a reader who opens the app most days.
class NotificacionesProvider extends ChangeNotifier with WidgetsBindingObserver {
  static const _claveActivo = 'aviso_activo';
  static const _claveHora = 'aviso_hora'; // minutes since midnight

  /// Reminder time offered the first time the user enables notifications,
  /// the same in every app. They can change it afterwards.
  static const horaPorDefecto = TimeOfDay(hour: 9, minute: 0);

  final Preferencias _prefs;
  final AgendaAvisos _servicio;
  final PoemaDelDiaProvider _diario;
  final TextosAviso Function() _textos;

  bool _activo;
  TimeOfDay _hora;
  bool _permisoDenegado = false;

  NotificacionesProvider({
    required Preferencias prefs,
    required AgendaAvisos servicio,
    required PoemaDelDiaProvider diario,
    required TimeOfDay horaPorDefecto,
    required TextosAviso Function() textos,
  })  : _prefs = prefs,
        _servicio = servicio,
        _diario = diario,
        _textos = textos,
        _activo = prefs.leerBool(_claveActivo),
        _hora = _desdeMinutos(prefs.leerEntero(_claveHora), horaPorDefecto) {
    _diario.addListener(_reprogramarSiActivo);
    WidgetsBinding.instance.addObserver(this);
    if (_activo) _reprogramarSiActivo();
  }

  bool get activo => _activo;
  TimeOfDay get hora => _hora;

  /// True when the user wants reminders but the OS won't deliver them —
  /// permission was refused, or revoked in system settings afterwards. The
  /// settings screen shows a "turn it on in Settings" note for this case,
  /// rather than a switch that silently does nothing.
  bool get permisoDenegado => _permisoDenegado;

  /// Returns false if the user declined the system prompt.
  Future<bool> activar() async {
    final estado = await _servicio.pedirPermiso();
    if (estado == EstadoPermisoAviso.denegado) {
      _permisoDenegado = true;
      notifyListeners();
      return false;
    }

    _permisoDenegado = false;
    _activo = true;
    notifyListeners();
    await _prefs.guardarBool(_claveActivo, true);
    await _reprogramar();
    return true;
  }

  Future<void> desactivar() async {
    _activo = false;
    _permisoDenegado = false;
    notifyListeners();
    await _prefs.guardarBool(_claveActivo, false);
    await _servicio.cancelarTodo();
  }

  Future<void> establecerHora(TimeOfDay hora) async {
    if (hora == _hora) return;
    _hora = hora;
    notifyListeners();
    await _prefs.guardarEntero(_claveHora, hora.hour * 60 + hora.minute);
    if (_activo) await _reprogramar();
  }

  Future<void> _reprogramar() async {
    if (!_activo) return;

    // Permission can be revoked from system settings at any time; check on
    // every reschedule so the UI can stop claiming reminders are on.
    if (!await _servicio.permisoConcedido()) {
      _permisoDenegado = true;
      notifyListeners();
      return;
    }
    _permisoDenegado = false;

    await _servicio.reprogramar(
      pool: _diario.pool,
      hora: _hora,
      textos: _textos(),
      autoresRecientes: _diario.historial,
    );
  }

  void _reprogramarSiActivo() {
    if (_activo) _reprogramar();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reprogramarSiActivo();
  }

  @override
  void dispose() {
    _diario.removeListener(_reprogramarSiActivo);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  static TimeOfDay _desdeMinutos(int? minutos, TimeOfDay porDefecto) {
    if (minutos == null || minutos < 0 || minutos >= 24 * 60) return porDefecto;
    return TimeOfDay(hour: minutos ~/ 60, minute: minutos % 60);
  }
}
