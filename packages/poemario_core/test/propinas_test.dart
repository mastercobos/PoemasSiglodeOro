import 'package:flutter_test/flutter_test.dart';
import 'package:poemario_core/donaciones/tienda_propinas.dart';
import 'package:poemario_core/providers/propinas_provider.dart';

import 'support/harness.dart';

void main() {
  const cafe1 = Propina(id: 'c1', precio: '1,00 €', valor: 1);
  const cafe3 = Propina(id: 'c3', precio: '3,00 €', valor: 3);
  const cafe5 = Propina(id: 'c5', precio: '5,00 €', valor: 5);

  PropinasProvider crear(TiendaFalsa tienda, [Set<String>? ids]) =>
      PropinasProvider(tienda: tienda, ids: ids ?? {'c1', 'c3', 'c5'});

  test('no configured ids: unavailable, store never asked', () async {
    final tienda = TiendaFalsa([cafe1]);
    final p = crear(tienda, {});
    await p.iniciar();
    expect(p.estado, EstadoPropinas.noDisponible);
  });

  test('lists amounts smallest first', () async {
    final p = crear(TiendaFalsa([cafe5, cafe1, cafe3]));
    await p.iniciar();
    expect(p.estado, EstadoPropinas.lista);
    expect(p.propinas.map((x) => x.id), ['c1', 'c3', 'c5']);
  });

  test('products the store does not know are skipped', () async {
    final p = crear(TiendaFalsa([cafe1]));
    await p.iniciar();
    expect(p.propinas.map((x) => x.id), ['c1']);
  });

  test('none found: unavailable', () async {
    final p = crear(TiendaFalsa([]));
    await p.iniciar();
    expect(p.estado, EstadoPropinas.noDisponible);
  });

  test('store unavailable: unavailable', () async {
    final p = crear(TiendaFalsa([cafe1])..disponible = false);
    await p.iniciar();
    expect(p.estado, EstadoPropinas.noDisponible);
  });

  test('query failure: unavailable, no throw', () async {
    final p = crear(TiendaFalsa([cafe1])..fallaAlConsultar = true);
    await p.iniciar();
    expect(p.estado, EstadoPropinas.noDisponible);
  });

  test('buying blocks a second purchase until an outcome arrives', () async {
    final tienda = TiendaFalsa([cafe1, cafe3]);
    final p = crear(tienda);
    await p.iniciar();

    await p.comprar(cafe1);
    expect(p.comprando, isTrue);
    await p.comprar(cafe3);
    expect(tienda.compradas, ['c1']);

    tienda.emitir(ResultadoPropina.completada);
    await Future<void>.delayed(Duration.zero);
    expect(p.comprando, isFalse);
    expect(p.resultado, ResultadoPropina.completada);
  });

  test('a new attempt clears the previous result', () async {
    final tienda = TiendaFalsa([cafe1]);
    final p = crear(tienda);
    await p.iniciar();
    await p.comprar(cafe1);
    tienda.emitir(ResultadoPropina.fallida);
    await Future<void>.delayed(Duration.zero);
    expect(p.resultado, ResultadoPropina.fallida);

    await p.comprar(cafe1);
    expect(p.resultado, isNull);
  });

  test('purchase that fails to start reports failure and unblocks', () async {
    final tienda = TiendaFalsa([cafe1])..fallaAlComprar = true;
    final p = crear(tienda);
    await p.iniciar();
    await p.comprar(cafe1);
    expect(p.comprando, isFalse);
    expect(p.resultado, ResultadoPropina.fallida);
  });
}
