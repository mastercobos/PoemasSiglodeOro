// App Store screenshots, rendered without a device:
//   cd apps/es && flutter test capturas/
// Output goes to $SALIDA (default: build/capturas). See capturas_tienda.
import 'package:app_es/main.dart';
import 'package:capturas_tienda/capturas_tienda.dart';

void main() {
  generarCapturas(const GuionCapturas(
    config: configApp,
    primero: PoemaBuscado('Quevedo', 'Cerrar podrá mis ojos'),
    segundo: PoemaBuscado('Gongora', 'Mientras por competir'),
    favoritos: [
      PoemaBuscado('Quevedo', 'Es hielo abrasador'),
      PoemaBuscado('Quevedo', 'Érase un hombre a una nariz pegado'),
      PoemaBuscado('Garcilaso de La Vega', 'En tanto que de rosa'),
      PoemaBuscado('Lope de Vega', 'Desmayarse, atreverse'),
      PoemaBuscado('Lope de Vega', 'Ir y quedarse'),
    ],
    autor: 'Quevedo',
    busqueda: 'ruiseñor',
  ));
}
