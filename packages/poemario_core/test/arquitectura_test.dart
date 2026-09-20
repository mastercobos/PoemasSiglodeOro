import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the white-label split by reading the source.
///
/// The whole multi-app arrangement rests on one rule: nothing in
/// `poemario_core` may know which anthology it is rendering. That rule is easy
/// to state and easy to break in a hurry — one `const Color(0xFF8B6914)` in a
/// new widget and the English app quietly ships a gold divider.
///
/// A unit test can't catch that, so this one greps instead. If it fails, the
/// fix is never to add an exception here: it is to move the value into
/// [AppConfig], the theme extension, or an `.arb` file.
void main() {
  final lib = Directory('lib');

  List<File> archivos(String subruta) => Directory('${lib.path}/$subruta')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  final ui = <File>[
    ...archivos('screens'),
    ...archivos('widgets'),
  ];

  test('no hardcoded colours in screens or widgets', () {
    // Colours belong in PoemaColors so each app can supply its own.
    final patron = RegExp(r'Color\(0x[0-9a-fA-F]{8}\)');
    final infractores = <String>[];

    for (final f in ui) {
      final lineas = f.readAsLinesSync();
      for (var i = 0; i < lineas.length; i++) {
        if (patron.hasMatch(lineas[i])) {
          infractores.add('${f.path}:${i + 1}  ${lineas[i].trim()}');
        }
      }
    }

    expect(infractores, isEmpty,
        reason: 'Usa context.colores (PoemaColors) en vez de literales:\n'
            '${infractores.join('\n')}');
  });

  test('no Colors.* constants outside transparent/white/black', () {
    final patron = RegExp(r'\bColors\.(?!transparent\b)(\w+)');
    final permitidos = {'transparent'};
    final infractores = <String>[];

    for (final f in ui) {
      final lineas = f.readAsLinesSync();
      for (var i = 0; i < lineas.length; i++) {
        for (final m in patron.allMatches(lineas[i])) {
          if (!permitidos.contains(m.group(1))) {
            infractores.add('${f.path}:${i + 1}  ${lineas[i].trim()}');
          }
        }
      }
    }

    expect(infractores, isEmpty,
        reason: 'Material palette colours are app-agnostic by accident, not by '
            'design. Add the colour to PoemaColors:\n'
            '${infractores.join('\n')}');
  });

  test('no font families named outside the theme', () {
    // Font families come from AppConfig.fuentes; naming one in a widget ties
    // core to a single app's typography.
    final patron = RegExp(r"fontFamily\s*:\s*'");
    final infractores = [
      for (final f in ui)
        if (patron.hasMatch(f.readAsStringSync())) f.path,
    ];

    expect(infractores, isEmpty,
        reason: 'Usa context.tipos:\n${infractores.join('\n')}');
  });

  test('google_fonts is gone', () {
    // It fetched fonts over the network on first launch. Fonts are bundled by
    // each app now.
    final infractores = [
      for (final f in lib.listSync(recursive: true).whereType<File>())
        if (f.path.endsWith('.dart') &&
            RegExp(r"import 'package:google_fonts")
                .hasMatch(f.readAsStringSync()))
          f.path,
    ];
    expect(infractores, isEmpty);
  });

  test('no user-visible Spanish strings in screens or widgets', () {
    // Every string the reader sees comes from an .arb file. This catches the
    // common ones rather than trying to detect language.
    final sospechosas = RegExp(
      r"'[^']*\b(poema|poemas|autor|autores|buscar|favoritos|ajustes|"
      r"guardado|aviso|día)\b[^']*'",
      caseSensitive: false,
    );
    final infractores = <String>[];

    for (final f in ui) {
      final lineas = f.readAsLinesSync();
      for (var i = 0; i < lineas.length; i++) {
        final linea = lineas[i];
        // Comments, imports and l10n keys are fine.
        if (linea.trimLeft().startsWith('//') ||
            linea.trimLeft().startsWith('///') ||
            linea.contains('import ') ||
            linea.contains('l10n.')) {
          continue;
        }
        // Strip interpolations first: '«${poema.primerVerso}»' is data being
        // formatted, not a hardcoded Spanish string.
        final sinInterpolacion =
            linea.replaceAll(RegExp(r'\$\{[^}]*\}'), '');
        if (sospechosas.hasMatch(sinInterpolacion)) {
          infractores.add('${f.path}:${i + 1}  ${linea.trim()}');
        }
      }
    }

    expect(infractores, isEmpty,
        reason: 'Mueve el texto a lib/l10n/app_*.arb:\n'
            '${infractores.join('\n')}');
  });

  test('core never imports an app package', () {
    final infractores = [
      for (final f in lib.listSync(recursive: true).whereType<File>())
        if (f.path.endsWith('.dart') &&
            RegExp(r"import 'package:app_").hasMatch(f.readAsStringSync()))
          f.path,
    ];
    expect(infractores, isEmpty,
        reason: 'La dependencia va en un solo sentido: apps → core.');
  });

  test('every string in app_es.arb exists in app_en.arb', () {
    // Top-level keys only. A regex over the raw text also picks up the keys
    // nested in each "@message" metadata block (description, placeholders,
    // type, placeholder names), which are not strings to translate.
    Map<String, dynamic> leer(String ruta) =>
        jsonDecode(File(ruta).readAsStringSync()) as Map<String, dynamic>;
    final es = leer('lib/l10n/app_es.arb');
    final en = leer('lib/l10n/app_en.arb');

    final faltan = [
      for (final k in es.keys)
        if (!k.startsWith('@') && !en.containsKey(k)) k,
    ];

    expect(faltan, isEmpty,
        reason: 'Sin traducir en app_en.arb: ${faltan.join(', ')}');
  });
}
