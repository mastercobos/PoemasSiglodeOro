import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poemario_core/config/app_config.dart';
import 'package:poemario_core/widgets/ornamento.dart';
import 'package:provider/provider.dart';

import 'support/harness.dart';

Widget _montar(AppConfig config) => Provider<AppConfig>.value(
      value: config,
      child: MaterialApp(
        theme: config.temaClaro,
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

  testWidgets('a missing asset falls back to the book glyph', (tester) async {
    await tester.pumpWidget(_montar(conIcono));
    await tester.pump();
    await tester.pump();
    expect(find.byIcon(Icons.auto_stories), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
