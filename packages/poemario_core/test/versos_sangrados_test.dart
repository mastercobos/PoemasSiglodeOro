import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SelectedContent;
import 'package:flutter_test/flutter_test.dart';
import 'package:poemario_core/widgets/versos_sangrados.dart';

import 'support/harness.dart';

/// The test font (Ahem) draws every glyph as a square as wide as the font
/// size, so at 10 px a verse of n characters is 10·n wide.
const _estilo = TextStyle(fontSize: 10, height: 1.5);

Future<void> _pintar(WidgetTester tester, List<List<String>> estrofas,
    {double ancho = 200, ValueChanged<SelectedContent?>? alSeleccionar}) async {
  await tester.pumpWidget(MaterialApp(
    theme: configPrueba.temaClaro,
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: ancho,
          child: SelectionArea(
            onSelectionChanged: alSeleccionar,
            child: VersosSangrados(
                estrofas: estrofas, estilo: _estilo, seleccionable: true),
          ),
        ),
      ),
    ),
  ));
}

List<String> _textos(WidgetTester tester) => [
      for (final t in tester.widgetList<Text>(find.byType(Text))) t.data!,
    ];

void main() {
  testWidgets('a verse that fits stays whole', (tester) async {
    await _pintar(tester, [
      ['corto', 'otro verso corto'],
    ]);
    expect(_textos(tester), ['corto', 'otro verso corto']);
  });

  testWidgets('a verse too long for the width continues indented',
      (tester) async {
    // 20 columns fit; the verse has 29 characters.
    await _pintar(tester, [
      ['aaaa bbbb cccc dddd eeee ffff', 'corto'],
    ]);
    expect(_textos(tester), ['aaaa bbbb cccc dddd', 'eeee ffff', 'corto']);
    final primera = tester.getTopLeft(find.text('aaaa bbbb cccc dddd'));
    final resto = tester.getTopLeft(find.text('eeee ffff'));
    final siguiente = tester.getTopLeft(find.text('corto'));
    expect(resto.dx - primera.dx, 15); // 1.5 × font size
    expect(siguiente.dx, primera.dx);
  });

  testWidgets('breaks follow the width: a wider screen does not break',
      (tester) async {
    await _pintar(tester, [
      ['aaaa bbbb cccc dddd eeee ffff'],
    ], ancho: 400);
    expect(_textos(tester), ['aaaa bbbb cccc dddd eeee ffff']);
  });

  testWidgets('a lone numeral stanza is a heading, centred over the block',
      (tester) async {
    await _pintar(tester, [
      ['II'],
      ['uno dos tres'],
    ]);
    final marca = tester.widget<Text>(find.text('II'));
    expect(marca.textAlign, TextAlign.center);
    expect(marca.style!.fontSize, closeTo(8.5, .01));
    expect(esMarcaDeSeccion(['II.']), isTrue);
    expect(esMarcaDeSeccion(['⁂']), isTrue);
    expect(esMarcaDeSeccion(['. . . . . . .']), isTrue);
    expect(esMarcaDeSeccion(['Il pleure']), isFalse);
    expect(esMarcaDeSeccion(['I', 'verso']), isFalse);
  });

  testWidgets('copying gives back the poem text, not the screen lines',
      (tester) async {
    SelectedContent? copiado;
    await _pintar(tester, [
      ['aaaa bbbb cccc dddd eeee ffff', 'corto'],
      ['otra estrofa'],
    ], alSeleccionar: (c) => copiado = c);
    expect(_textos(tester).length, 4); // the long verse is on two lines
    await tester.pump(); // selection containers register after a frame
    tester
        .state<SelectableRegionState>(find.byType(SelectableRegion))
        .selectAll(SelectionChangedCause.keyboard);
    await tester.pumpAndSettle();
    expect(copiado?.plainText,
        'aaaa bbbb cccc dddd eeee ffff\ncorto\n\notra estrofa');
  });
}
