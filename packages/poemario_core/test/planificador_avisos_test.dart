import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:poemario_core/data/poema.dart';
import 'package:poemario_core/domain/seleccion_diaria.dart';
import 'package:poemario_core/notifications/agenda_avisos.dart';
import 'package:poemario_core/notifications/planificador_avisos.dart';

List<Poema> pool({int autores = 8}) => [
      for (var a = 0; a < autores; a++)
        for (var p = 0; p < 3; p++)
          Poema.fromJson({
            'id': 'a$a-p$p',
            'autor': 'Autor $a',
            'titulo': 'Poema $p',
            'texto': 'verso',
          }, index: a * 3 + p),
    ];

const textos = TextosAviso(
  titulo: 'Hoy hay poemas nuevos',
  linea: _linea,
  cuerpoGenerico: 'Hay poemas nuevos',
);

String _linea(Poema p) => '${p.etiqueta} — ${p.autor}';

void main() {
  const hora = TimeOfDay(hour: 9, minute: 0);

  List<AvisoProgramado> nombrados(List<AvisoProgramado> plan) =>
      plan.where((a) => a.cuerpo != textos.cuerpoGenerico).toList();

  test('one notification a day, naming both poems of the day', () {
    final plan = PlanificadorAvisos.construir(
      pool: pool(),
      desde: DateTime(2026, 9, 19, 7),
      hora: hora,
      textos: textos,
    );
    final conTitulo = nombrados(plan);
    expect(conTitulo.length, PlanificadorAvisos.diasConTitulo);
    for (final a in conTitulo) {
      expect(a.cuerpo.split('\n').length, SeleccionDiariaService.poemasPorDia);
    }
    // The 1.1.0 bug: a second, generic notification every morning.
    final dias = plan.map((a) => DateTime(a.cuando.year, a.cuando.month, a.cuando.day));
    expect(dias.toSet().length, plan.length);
  });

  test('every notification opens the home screen', () {
    final plan = PlanificadorAvisos.construir(
        pool: pool(), desde: DateTime(2026, 9, 19, 7), hora: hora, textos: textos);
    expect(plan.every((a) => a.payload == SolicitudDePoema.inicio), isTrue);
  });

  test('skips today when the reminder time has already passed', () {
    final plan = PlanificadorAvisos.construir(
      pool: pool(),
      desde: DateTime(2026, 9, 19, 21, 30), // 21:30, reminder is 09:00
      hora: hora,
      textos: textos,
    );
    final primero = plan.first;
    // The first named reminder is tomorrow, not an immediate buzz.
    expect(primero.cuando.day, 20);
  });

  test('every scheduled time is in the future', () {
    final ahora = DateTime(2026, 9, 19, 7);
    final plan = PlanificadorAvisos.construir(
        pool: pool(), desde: ahora, hora: hora, textos: textos);
    expect(plan.every((a) => a.cuando.isAfter(ahora)), isTrue);
  });

  test('ids are stable across reschedules, so nothing accumulates', () {
    final a = PlanificadorAvisos.construir(
        pool: pool(), desde: DateTime(2026, 9, 19, 7), hora: hora, textos: textos);
    final b = PlanificadorAvisos.construir(
        pool: pool(), desde: DateTime(2026, 9, 19, 8), hora: hora, textos: textos);
    expect(a.map((x) => x.id), b.map((x) => x.id));
  });

  test('the notification names the poems the app will actually show', () {
    final p = pool();
    final plan = PlanificadorAvisos.construir(
      pool: p,
      desde: DateTime(2026, 9, 19, 7),
      hora: hora,
      textos: textos,
    );
    final avisoManana = plan.firstWhere((a) => a.cuando.day == 20);
    final loQueVeraLaApp = SeleccionDiariaService.paraFecha(
      pool: p,
      fecha: DateTime(2026, 9, 20),
      // The history in force tomorrow is today's authors on top of today's;
      // the provider replays exactly this (see historialPara).
      autoresRecientes: SeleccionDiariaService.historialPara(
        pool: p,
        desde: DateTime(2026, 9, 19),
        historialDesde: const [],
        fecha: DateTime(2026, 9, 20),
      ),
    );
    expect(avisoManana.cuerpo, loQueVeraLaApp.poemas.map(_linea).join('\n'));
  });

  test('generic one-shot reminders follow the named window', () {
    final plan = PlanificadorAvisos.construir(
        pool: pool(), desde: DateTime(2026, 9, 19, 7), hora: hora, textos: textos);
    final genericos =
        plan.where((a) => a.cuerpo == textos.cuerpoGenerico).toList();
    expect(genericos.length, PlanificadorAvisos.diasGenericos);
    expect(genericos.first.cuando,
        DateTime(2026, 9, 19 + PlanificadorAvisos.diasConTitulo, 9));
    expect(plan.map((a) => a.id).toSet().length, plan.length);
    expect(plan.map((a) => a.id),
        isNot(contains(PlanificadorAvisos.idRepetidoAntiguo)));
  });

  test('an empty pool schedules nothing at all', () {
    final plan = PlanificadorAvisos.construir(
        pool: const [], desde: DateTime(2026, 9, 19), hora: hora, textos: textos);
    expect(plan, isEmpty);
  });
}
