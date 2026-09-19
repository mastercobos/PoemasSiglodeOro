import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:poemario_core/data/poema.dart';
import 'package:poemario_core/domain/seleccion_diaria.dart';
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
  titulo: 'Poema del día',
  cuerpo: _cuerpo,
  cuerpoGenerico: 'Hay poemas nuevos',
);

String _cuerpo(Poema p) => '${p.etiqueta} — ${p.autor}';

void main() {
  const hora = TimeOfDay(hour: 9, minute: 0);

  test('names a poem on each of the next fourteen days', () {
    final plan = PlanificadorAvisos.construir(
      pool: pool(),
      desde: DateTime(2026, 9, 19, 7),
      hora: hora,
      textos: textos,
    );
    final conTitulo = plan.where((a) => a.payload != null).toList();
    expect(conTitulo.length, PlanificadorAvisos.diasConTitulo);
    expect(conTitulo.every((a) => a.cuerpo.contains('—')), isTrue);
  });

  test('skips today when the reminder time has already passed', () {
    final plan = PlanificadorAvisos.construir(
      pool: pool(),
      desde: DateTime(2026, 9, 19, 21, 30), // 21:30, reminder is 09:00
      hora: hora,
      textos: textos,
    );
    final primero = plan.firstWhere((a) => a.payload != null);
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

  test('the notification names the poem the app will actually show', () {
    final p = pool();
    final manana = DateTime(2026, 9, 20);
    final plan = PlanificadorAvisos.construir(
      pool: p,
      desde: DateTime(2026, 9, 19, 7),
      hora: hora,
      textos: textos,
    );
    final avisoManana =
        plan.firstWhere((a) => a.payload != null && a.cuando.day == 20);
    final loQueVeraLaApp = SeleccionDiariaService.paraFecha(
      pool: p,
      fecha: manana,
      // The app will have recorded today's authors by then; the plan carries
      // the same history forward, which is why the two agree.
      autoresRecientes: SeleccionDiariaService.paraFecha(
              pool: p, fecha: DateTime(2026, 9, 19))
          .autores,
    );
    expect(avisoManana.payload, loQueVeraLaApp.poemas.first.id);
  });

  test('adds one repeating fallback beyond the named window', () {
    final plan = PlanificadorAvisos.construir(
        pool: pool(), desde: DateTime(2026, 9, 19, 7), hora: hora, textos: textos);
    final genericos = plan.where((a) => a.repiteADiario).toList();
    expect(genericos.length, 1);
    expect(genericos.single.payload, isNull);
    expect(genericos.single.cuando.difference(DateTime(2026, 9, 19)).inDays,
        greaterThanOrEqualTo(PlanificadorAvisos.diasConTitulo));
  });

  test('an empty pool schedules nothing at all', () {
    final plan = PlanificadorAvisos.construir(
        pool: const [], desde: DateTime(2026, 9, 19), hora: hora, textos: textos);
    expect(plan, isEmpty);
  });
}
