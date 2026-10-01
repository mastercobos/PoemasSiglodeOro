import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SelectedContent;
import 'package:flutter_test/flutter_test.dart';
import 'package:poemario_core/widgets/versos_ajustados.dart';

import 'support/harness.dart';

/// The test font (Ahem) draws every glyph as a square as wide as the font
/// size, so at 10 px a verse of n characters is 10·n wide. The widget leaves
/// one pixel of slack, so at a width of 200 it has 199. Ahem rounds line
/// heights to whole pixels, hence the 1 px tolerance on heights.
// No letter spacing, which the theme's default text style would add.
const _estilo = TextStyle(fontSize: 10, height: 2, letterSpacing: 0);

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
            child: VersosAjustados(
                estrofas: estrofas, estilo: _estilo, seleccionable: true),
          ),
        ),
      ),
    ),
  ));
}

double _tamano(WidgetTester tester, String texto) =>
    tester.widget<Text>(find.text(texto)).style!.fontSize!;

void main() {
  testWidgets('a poem that fits keeps its size', (tester) async {
    await _pintar(tester, [
      ['corto', 'otro verso corto'],
    ]);
    expect(_tamano(tester, 'corto'), 10);
    expect(_tamano(tester, 'otro verso corto'), 10);
  });

  testWidgets('the whole poem shrinks just enough for its longest verse',
      (tester) async {
    // 22 characters = 220 px in 199: factor 199/220 ≈ 0.905.
    await _pintar(tester, [
      ['aaaa bbbb cccc dddd ee', 'corto'],
      ['otra'],
    ]);
    expect(_tamano(tester, 'aaaa bbbb cccc dddd ee'), closeTo(9.045, .01));
    expect(_tamano(tester, 'corto'), _tamano(tester, 'otra'));
    expect(_tamano(tester, 'corto'), _tamano(tester, 'aaaa bbbb cccc dddd ee'));
    // One line: height = size × line height.
    expect(tester.getSize(find.text('aaaa bbbb cccc dddd ee')).height,
        closeTo(9.045 * 2, 1));
  });

  testWidgets('never below 80%: past that long verses wrap, held together',
      (tester) async {
    // 30 characters would need 0.66: stays at 8 px and wraps.
    await _pintar(tester, [
      ['aaaa bbbb cccc dddd eeee ffff', 'corto'],
    ]);
    expect(_tamano(tester, 'corto'), 8);
    final largo = tester.getSize(find.text('aaaa bbbb cccc dddd eeee ffff'));
    final corto = tester.getSize(find.text('corto'));
    // Two lines at the tighter height inside the verse...
    expect(largo.height, closeTo(2 * 8 * VersosAjustados.alturaPartida, 1));
    expect(corto.height, closeTo(8 * VersosAjustados.alturaPartida, 1));
    // ...and the rest of the line height added between verses, so the gap
    // between two verses is larger than between a verse's own lines.
    final hueco = tester.getTopLeft(find.text('corto')).dy -
        tester.getBottomLeft(find.text('aaaa bbbb cccc dddd eeee ffff')).dy;
    expect(hueco, closeTo(8 * (2 - VersosAjustados.alturaPartida), 1));
  });

  testWidgets('a wider screen does not shrink', (tester) async {
    await _pintar(tester, [
      ['aaaa bbbb cccc dddd eeee ffff'],
    ], ancho: 400);
    expect(_tamano(tester, 'aaaa bbbb cccc dddd eeee ffff'), 10);
  });

  testWidgets('a lone numeral stanza is a heading and does not set the size',
      (tester) async {
    await _pintar(tester, [
      ['. . . . . . . . . . . . . . . . . . . . . . . . . . . . .'],
      ['II'],
      ['uno dos tres'],
    ]);
    expect(_tamano(tester, 'uno dos tres'), 10);
    final marca = tester.widget<Text>(find.text('II'));
    expect(marca.textAlign, TextAlign.center);
    expect(marca.style!.fontSize, closeTo(8.5, .01));
    expect(esMarcaDeSeccion(['II.']), isTrue);
    expect(esMarcaDeSeccion(['⁂']), isTrue);
    expect(esMarcaDeSeccion(['Il pleure']), isFalse);
    expect(esMarcaDeSeccion(['I', 'verso']), isFalse);
    // The name of who speaks next in a dialogue poem.
    expect(esMarcaDeSeccion(['LA SŒUR.']), isTrue);
    expect(esMarcaDeSeccion(['LE CHŒUR DE FEMMES.']), isTrue);
    expect(esMarcaDeSeccion(['Ô Muses !']), isFalse);
    expect(esMarcaDeSeccion(['Ô !']), isFalse);
  });

  testWidgets('copying gives back the poem text', (tester) async {
    SelectedContent? copiado;
    await _pintar(tester, [
      ['aaaa bbbb cccc dddd eeee ffff', 'corto'],
      ['II'],
      ['otra estrofa'],
    ], alSeleccionar: (c) => copiado = c);
    await tester.pump(); // selection containers register after a frame
    tester
        .state<SelectableRegionState>(find.byType(SelectableRegion))
        .selectAll(SelectionChangedCause.keyboard);
    await tester.pumpAndSettle();
    expect(copiado?.plainText,
        'aaaa bbbb cccc dddd eeee ffff\ncorto\n\nII\n\notra estrofa');
  });
}
