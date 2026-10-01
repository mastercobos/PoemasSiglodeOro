import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poemario_core/config/app_config.dart';
import 'package:poemario_core/widgets/ornamento.dart';
import 'package:provider/provider.dart';

import 'support/harness.dart';

Widget _montar(AppConfig config, {bool oscuro = false}) =>
    Provider<AppConfig>.value(
      value: config,
      child: MaterialApp(
        theme: oscuro ? config.temaOscuro : config.temaClaro,
        home: const Scaffold(body: Center(child: Ornamento())),
      ),
    );

void main() {
  final conIcono = AppConfig(
    locale: configPrueba.locale,
    nombreApp: configPrueba.nombreApp,
    firmaCompartir: configPrueba.firmaCompartir,
    coloresClaro: configPrueba.coloresClaro,
    coloresOscuro: configPrueba.coloresOscuro,
    fuentes: configPrueba.fuentes,
    assetOrnamento: 'assets/icon/no_existe.png',
  );

  testWidgets('without an ornament asset it draws the book glyph',
      (tester) async {
    await tester.pumpWidget(_montar(configPrueba));
    expect(find.byIcon(Icons.auto_stories), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('with an ornament asset it draws that image instead',
      (tester) async {
    await tester.pumpWidget(_montar(conIcono));
    final imagen = tester.widget<Image>(find.byType(Image));
    expect((imagen.image as AssetImage).assetName, 'assets/icon/no_existe.png');
  });

  testWidgets('light mode uses the light ornament when there is one',
      (tester) async {
    final dosVersiones = AppConfig(
      locale: configPrueba.locale,
      nombreApp: configPrueba.nombreApp,
      firmaCompartir: configPrueba.firmaCompartir,
      coloresClaro: configPrueba.coloresClaro,
      coloresOscuro: configPrueba.coloresOscuro,
      fuentes: configPrueba.fuentes,
      assetOrnamento: 'assets/icon/oscuro.png',
      assetOrnamentoClaro: 'assets/icon/claro.png',
    );
    String dibujado() =>
        (tester.widget<Image>(find.byType(Image)).image as AssetImage)
            .assetName;

    await tester.pumpWidget(_montar(dosVersiones));
    expect(dibujado(), 'assets/icon/claro.png');
    await tester.pumpWidget(_montar(dosVersiones, oscuro: true));
    await tester.pumpAndSettle(); // the theme change animates
    expect(dibujado(), 'assets/icon/oscuro.png');

    // Without a light version, both modes use the one there is.
    expect(
        conIcono.ornamentoPara(Brightness.light), 'assets/icon/no_existe.png');
    expect(
        conIcono.ornamentoPara(Brightness.dark), 'assets/icon/no_existe.png');
  });

  testWidgets('a missing asset falls back to the book glyph', (tester) async {
    await tester.pumpWidget(_montar(conIcono));
    await tester.pump();
    await tester.pump();
    expect(find.byIcon(Icons.auto_stories), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
