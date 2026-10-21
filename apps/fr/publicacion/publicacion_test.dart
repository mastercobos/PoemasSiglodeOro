// The day's two poems, posted to the app's Tumblr blog:
//   cd apps/fr && flutter test publicacion/
// Without credentials it only writes the posts to build/publicaciones.
// See publicador_diario.
import 'package:app_fr/main.dart';
import 'package:publicador_diario/publicador_diario.dart';

void main() {
  publicarPoemasDelDia(const GuionPublicacion(
    config: configApp,
    etiquetas: [
      'poésie',
      'poème du jour',
      'poésie française',
      'littérature française',
      'french poetry',
    ],
    invitacion: 'Deux poèmes par jour dans l’application Poésie française',
    // Not on the stores yet.
    enlaceTienda: null,
  ));
}
