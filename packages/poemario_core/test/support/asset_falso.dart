import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Registers a string as an asset so `rootBundle.loadString` finds it.
///
/// Lets the *real* [PoemaRepository] run under test — parsing, id checks,
/// grouping and sorting all included — instead of hand-building an
/// [Anthology] that could drift from what the app actually loads.
void registrarAsset(String ruta, String contenido) {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final datos = ByteData.sublistView(utf8.encode(contenido));
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
      return pedida == ruta ? datos : null;
    },
  );
  addTearDown(() {
    rootBundle.clear();
    binding.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });
}

String comoJson(Object? valor) => jsonEncode(valor);
