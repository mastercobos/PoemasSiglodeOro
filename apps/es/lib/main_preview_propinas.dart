// Throwaway: shows the tip jar without a store. Run with
//   flutter run -d chrome -t lib/main_preview_propinas.dart
import 'package:flutter/material.dart';
import 'package:poemario_core/bootstrap.dart';
import 'package:poemario_core/config/app_config.dart';
import 'package:poemario_core/domain/orden_titulos.dart';
import 'package:poemario_core/donaciones/tienda_propinas.dart';
import 'package:poemario_core/screens/ajustes_screen.dart';
import 'package:poemario_core/theme/poema_colors.dart';
import 'package:poemario_core/theme/poema_theme.dart';

class _TiendaDemo implements TiendaPropinas {
  final _s = Stream<ResultadoPropina>.empty();
  @override
  Future<bool> iniciar() async => true;
  @override
  Future<List<Propina>> consultar(Set<String> ids) async => const [
        Propina(id: 'a', precio: '1,00 €', valor: 1),
        Propina(id: 'b', precio: '3,00 €', valor: 3),
        Propina(id: 'c', precio: '5,00 €', valor: 5),
      ];
  @override
  Future<void> comprar(Propina p) async {}
  @override
  Stream<ResultadoPropina> get resultados => _s;
  @override
  Future<void> cerrar() async {}
}

void main() {
  bootstrap(
    const AppConfig(
      locale: Locale('es'),
      nombreApp: 'Antología Poética',
      firmaCompartir: 'Poemario · Siglo de Oro',
      ordenTitulos: EstrategiaOrden.romanosPrimero,
      fuentes: FontPair(display: 'PlayfairDisplay', body: 'Lato'),
      coloresClaro: PoemaColors.claroPorDefecto,
      coloresOscuro: PoemaColors.oscuroPorDefecto,
      idsPropinas: {'a', 'b', 'c'},
    ),
    tiendaPropinas: _TiendaDemo(),
    home: (_) => const AjustesScreen(),
  );
}
