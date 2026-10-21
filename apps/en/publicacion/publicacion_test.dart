// The day's two poems, posted to the app's Tumblr blog:
//   cd apps/en && flutter test publicacion/
// Without credentials it only writes the posts to build/publicaciones.
// See publicador_diario.
import 'package:app_en/main.dart';
import 'package:publicador_diario/publicador_diario.dart';

void main() {
  publicarPoemasDelDia(const GuionPublicacion(
    config: configApp,
    etiquetas: [
      'poetry',
      'poem of the day',
      'classic poetry',
      'english poetry',
      'literature',
    ],
    invitacion: 'Two poems a day in the English Verse app',
    // Not on the stores yet.
    enlaceTienda: null,
  ));
}
