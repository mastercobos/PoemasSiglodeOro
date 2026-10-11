// App Store screenshots, rendered without a device:
//   cd apps/en && flutter test capturas/
// Output goes to $SALIDA (default: build/capturas). See capturas_tienda.
import 'package:app_en/main.dart';
import 'package:capturas_tienda/capturas_tienda.dart';

void main() {
  generarCapturas(const GuionCapturas(
    config: configApp,
    primero: PoemaBuscado('William Shakespeare', 'Shall I compare thee'),
    segundo: PoemaBuscado('William Wordsworth', 'I wandered lonely'),
    favoritos: [
      PoemaBuscado('Percy Bysshe Shelley', 'I met a traveller'),
      PoemaBuscado('Lord Byron', 'She walks in Beauty'),
      PoemaBuscado('John Keats', "Thou still unravish'd"),
      PoemaBuscado('Emily Dickinson', 'Hope is the thing'),
      PoemaBuscado('Edgar Allan Poe', 'It was many and many'),
    ],
    autor: 'William Shakespeare',
    busqueda: 'nightingale',
  ));
}
