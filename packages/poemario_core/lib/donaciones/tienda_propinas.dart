/// One tip amount offered by the store, already priced for the user's region.
class Propina {
  final String id;

  /// Formatted by the store, e.g. "1,99 €". Never build this ourselves: the
  /// currency and tax treatment differ per country.
  final String precio;

  /// Numeric price, used only to order the options from smallest to largest.
  final double valor;

  const Propina({required this.id, required this.precio, required this.valor});
}

/// How a purchase attempt ended.
enum ResultadoPropina { completada, cancelada, fallida }

/// What [PropinasProvider] needs from the app store.
///
/// Narrow on purpose, like `AgendaAvisos`: the provider holds the policy (what
/// to show, when) and none of the platform, so it is testable without the
/// billing plugin.
abstract interface class TiendaPropinas {
  /// Starts listening for purchase updates and reports whether the store can
  /// be used at all. Must be called early: a purchase interrupted in a
  /// previous session is delivered on this stream when the app restarts.
  Future<bool> iniciar();

  /// Looks up [ids]. Ids the store doesn't know are simply absent from the
  /// result, so a product that isn't set up yet hides itself.
  Future<List<Propina>> consultar(Set<String> ids);

  /// Opens the store's payment sheet. The outcome arrives on [resultados].
  Future<void> comprar(Propina propina);

  Stream<ResultadoPropina> get resultados;

  Future<void> cerrar();
}
