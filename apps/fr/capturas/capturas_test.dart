// App Store screenshots, rendered without a device:
//   cd apps/fr && flutter test capturas/
// Output goes to $SALIDA (default: build/capturas). See capturas_tienda.
import 'package:app_fr/main.dart';
import 'package:capturas_tienda/capturas_tienda.dart';

void main() {
  generarCapturas(const GuionCapturas(
    config: configApp,
    primero: PoemaBuscado('Victor Hugo', 'Demain, dès l’aube'),
    segundo: PoemaBuscado('Charles Baudelaire', 'Souvent, pour s’amuser'),
    favoritos: [
      PoemaBuscado('Pierre de Ronsard', 'Mignonne, allons voir'),
      PoemaBuscado('Paul Verlaine', 'Les sanglots longs'),
      PoemaBuscado('Arthur Rimbaud', 'C’est un trou de verdure'),
      PoemaBuscado('Joachim du Bellay', 'Heureux qui, comme Ulysse'),
      PoemaBuscado('Gérard de Nerval', 'Je suis le ténébreux'),
    ],
    autor: 'Victor Hugo',
    busqueda: 'rossignol',
  ));
}
