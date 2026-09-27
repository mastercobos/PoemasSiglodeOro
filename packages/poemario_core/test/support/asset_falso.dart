import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Registers a string as an asset so `rootBundle.loadString` finds it.
///
/// Lets the *real* [PoemaRepository] run under test — parsing, id checks,
/// grouping and sorting all included — instead of hand-building an
/// [Anthology] that could drift from what the app actually loads.
void registrarAsset(String ruta, String contenido) =>
    registrarAssets({ruta: contenido});

/// Several assets at once: a split anthology's index and its text chunks.
void registrarAssets(Map<String, String> contenidos) {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final datos = {
    for (final e in contenidos.entries)
      e.key: ByteData.sublistView(utf8.encode(e.value)),
  };
  // rootBundle is a CachingAssetBundle: without this, the first anthology a
  // test file loads is handed back to every later call, silently ignoring
  // different fixtures.
  rootBundle.clear();
  // rootBundle is a CachingAssetBundle: without this, the first anthology a
  // test file loads is handed back to every later call, silently ignoring
  // different fixtures.
  rootBundle.clear();
  binding.defaultBinaryMessenger.setMockMessageHandler(
    'flutter/assets',
    (mensaje) async {
      final pedida = utf8.decode(mensaje!.buffer.asUint8List());
      return datos[pedida];
    },
  );
  addTearDown(() {
    rootBundle.clear();
    binding.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });
}

String comoJson(Object? valor) => jsonEncode(valor);
