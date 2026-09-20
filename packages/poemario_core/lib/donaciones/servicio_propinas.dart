import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import 'tienda_propinas.dart';

/// [TiendaPropinas] over the `in_app_purchase` plugin.
///
/// Tips are consumable products, so the same amount can be given again.
/// Nothing is unlocked and nothing is persisted: a tip is a thank-you, and
/// there is no purchase state to restore.
class ServicioPropinas implements TiendaPropinas {
  final InAppPurchase? _inyectado;
  final _resultados = StreamController<ResultadoPropina>.broadcast();
  final _detalles = <String, ProductDetails>{};
  StreamSubscription<List<PurchaseDetails>>? _suscripcion;

  ServicioPropinas({InAppPurchase? iap}) : _inyectado = iap;

  // Resolved on use, not in the constructor: on platforms without a billing
  // implementation (web, desktop) touching `instance` throws.
  InAppPurchase get _iap => _inyectado ?? InAppPurchase.instance;

  @override
  Stream<ResultadoPropina> get resultados => _resultados.stream;

  @override
  Future<bool> iniciar() async {
    if (!await _iap.isAvailable()) return false;
    _suscripcion ??= _iap.purchaseStream.listen(
      _alRecibir,
      onError: (_) => _resultados.add(ResultadoPropina.fallida),
    );
    return true;
  }

  @override
  Future<List<Propina>> consultar(Set<String> ids) async {
    final respuesta = await _iap.queryProductDetails(ids);
    if (respuesta.error != null) throw respuesta.error!;
    _detalles
      ..clear()
      ..addEntries(respuesta.productDetails.map((d) => MapEntry(d.id, d)));
    return [
      for (final d in respuesta.productDetails)
        Propina(id: d.id, precio: d.price, valor: d.rawPrice),
    ];
  }

  @override
  Future<void> comprar(Propina propina) async {
    final detalle = _detalles[propina.id];
    if (detalle == null) throw StateError('Unknown product ${propina.id}');
    final iniciada = await _iap.buyConsumable(
      purchaseParam: PurchaseParam(productDetails: detalle),
    );
    if (!iniciada) throw StateError('Purchase did not start');
  }

  Future<void> _alRecibir(List<PurchaseDetails> compras) async {
    for (final compra in compras) {
      switch (compra.status) {
        case PurchaseStatus.pending:
          // The sheet is still open; wait for the final status.
          continue;
        case PurchaseStatus.purchased:
          _resultados.add(ResultadoPropina.completada);
        case PurchaseStatus.canceled:
          _resultados.add(ResultadoPropina.cancelada);
        case PurchaseStatus.error:
          _resultados.add(ResultadoPropina.fallida);
        case PurchaseStatus.restored:
          break;
      }
      // Without this the store never considers the purchase finished: iOS
      // shows it again on every launch and Play refunds it after three days.
      if (compra.pendingCompletePurchase) {
        await _iap.completePurchase(compra);
      }
    }
  }

  @override
  Future<void> cerrar() async {
    await _suscripcion?.cancel();
    _suscripcion = null;
    await _resultados.close();
  }
}
