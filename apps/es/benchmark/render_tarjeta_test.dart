// ignore_for_file: depend_on_referenced_packages
// Renders the share card to PNG files using the Spanish app's real fonts, icon
// and a real poem, so the layout can be inspected without a device. Lives in
// the app (not core) so it can read the app's own assets. `flutter test` does
// not load pubspec fonts (text would render as blocks), so they are loaded by
// hand; weight and slant come from each file's own metadata.
//   cd apps/es && flutter test benchmark/render_tarjeta_test.dart
// Output goes to $SALIDA (default: build/tarjeta).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poemario_core/config/app_config.dart';
import 'package:poemario_core/data/poema.dart';
import 'package:poemario_core/theme/poema_colors.dart';
import 'package:poemario_core/theme/poema_theme.dart';
import 'package:poemario_core/utils/compartir_poema.dart';
import 'package:provider/provider.dart';

const _icono = 'assets/icon/gafas_bigote_splash_mini.png';

Future<void> _cargarFuente(String familia, List<String> archivos) async {
  final loader = FontLoader(familia);
  for (final a in archivos) {
    loader.addFont(Future.value(
        ByteData.sublistView(File('assets/fonts/$a').readAsBytesSync())));
  }
  await loader.load();
}

void main() {
  testWidgets('render share card', (tester) async {
    await tester.runAsync(() async {
      await _cargarFuente('PlayfairDisplay', [
        'PlayfairDisplay-Regular.ttf',
        'PlayfairDisplay-SemiBold.ttf',
        'PlayfairDisplay-Bold.ttf',
      ]);
      await _cargarFuente(
          'Lato', ['Lato-Regular.ttf', 'Lato-Italic.ttf', 'Lato-Bold.ttf']);
    });

    const config = AppConfig(
      locale: Locale('es'),
      nombreApp: 'Antología Poética',
      firmaCompartir: 'Poemario · Siglo de Oro',
      assetOrnamento: _icono,
      fuentes: FontPair(display: 'PlayfairDisplay', body: 'Lato'),
      coloresClaro: PoemaColors.claroPorDefecto,
      coloresOscuro: PoemaColors.oscuroPorDefecto,
    );
    final poema = Poema.fromJson({
      'id': 'muestra',
      'autor': 'Quevedo',
      'titulo': 'Soneto amoroso',
      'texto': 'Solo sin vos, y mi dolor presente\n'
          'mi pecho rompo con mortal cuchillo;\n'
          'que es sombra vuestra, y de la luz que os sigue,\n'
          'del sol que os mira y de la luz que os sirve.\n\n'
          'Y así, sin vos, mi vida se despeña\n'
          'por el camino que sin vos me lleva;\n'
          'que es larga la esperanza, y es la nueva\n'
          'razón de amar la que mi mal desdeña.',
    }, index: 0);

    // Invented, not a real poem: only to check that a poem past the card's
    // preview threshold (14 verses) truncates and shows the "…" continuation
    // mark, not to render real long-form content.
    final poemaLargo = Poema.fromJson({
      'id': 'muestra-larga',
      'autor': 'Autor de prueba',
      'titulo': 'Poema de prueba muy largo',
      'texto': List.generate(30, (i) => 'Verso de relleno número ${i + 1}')
          .join('\n'),
    }, index: 0);

    final salida = Directory(Platform.environment['SALIDA'] ?? 'build/tarjeta')
      ..createSync(recursive: true);

    Future<void> renderizar(Poema p, String prefijo) async {
      for (final oscuro in [false, true]) {
        final clave = GlobalKey();
        await tester.pumpWidget(Provider<AppConfig>.value(
          value: config,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: oscuro ? config.temaOscuro : config.temaClaro,
            home: Scaffold(
              body: SingleChildScrollView(
                child: RepaintBoundary(
                  key: clave,
                  child: Material(
                    type: MaterialType.transparency,
                    child:
                        TarjetaCompartir(poema: p, firma: config.firmaCompartir),
                  ),
                ),
              ),
            ),
          ),
        ));
        // Let the icon decode on the real event loop.
        await tester
            .runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
        // MaterialApp animates theme changes; let the switch finish.
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();

        final boundary =
            clave.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final png = await tester.runAsync(() async {
          final img = await boundary.toImage(pixelRatio: 3.0);
          final datos = await img.toByteData(format: ui.ImageByteFormat.png);
          img.dispose();
          return datos!.buffer.asUint8List();
        });
        final nombre = '${prefijo}_${oscuro ? 'oscura' : 'clara'}.png';
        File('${salida.path}/$nombre').writeAsBytesSync(png!);
        // ignore: avoid_print
        print('$nombre  ${boundary.size}  ${png.length ~/ 1024} KiB');
      }
    }

    await renderizar(poema, 'tarjeta');
    await renderizar(poemaLargo, 'tarjeta_larga');
  });
}
