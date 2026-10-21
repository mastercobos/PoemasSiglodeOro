// The day's two poems, posted to the app's Tumblr blog:
//   cd apps/es && flutter test publicacion/
// Without credentials it only writes the posts to build/publicaciones.
// See publicador_diario.
import 'package:app_es/main.dart';
import 'package:publicador_diario/publicador_diario.dart';

void main() {
  publicarPoemasDelDia(const GuionPublicacion(
    config: configApp,
    etiquetas: [
      'poesía',
      'spanish poetry',
      'Siglo de Oro',
      'poesía española',
      'literatura española',
      'poema del día',
    ],
    invitacion: 'Dos poemas del Siglo de Oro cada día en la aplicación '
        'Poemario - Siglo de Oro',
    enlaceTienda:
        'https://play.google.com/store/apps/details?id=com.manucobos.poemario',
    horas: [9, 15],
  ));
}
