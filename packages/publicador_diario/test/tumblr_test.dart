import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:publicador_diario/publicador_diario.dart';

class _RedReal extends HttpOverrides {}

void main() {
  test('signs as RFC 5849 does (Twitter\'s published worked example)', () {
    final firma = firmaOAuth1(
      metodo: 'POST',
      url: Uri.parse(
          'https://api.twitter.com/1.1/statuses/update.json?include_entities=true'),
      parametros: {
        'status': 'Hello Ladies + Gentlemen, a signed OAuth request!',
        'oauth_consumer_key': 'xvz1evFS4wEEPTGEFPHBog',
        'oauth_nonce': 'kYjzVBB8Y0ZFabxSWbWovY3uYSQ2pTgmZeNu2VS4cg',
        'oauth_signature_method': 'HMAC-SHA1',
        'oauth_timestamp': '1318622958',
        'oauth_token': '370773112-GmHxMAgYyLbNEtIKZeRNFsMKPR9EyMZeS9weJAEb',
        'oauth_version': '1.0',
      },
      consumerSecret: 'kAcSOqF21Fu85e7zjz7ZN2U4ZRhfV3WpwPAoE3Z7kBw',
      tokenSecret: 'LswwdoUaIvS8ltyTt5jkRh4J50vUPVVHtR2YPi5kE',
    );
    expect(firma, 'hCtSmYh+iHYCEqBWrE7C7hYmtUk=');
  });

  test('percent-encodes the characters Uri.encodeComponent leaves alone', () {
    expect(codificarOAuth("a b!*'()~-._ñ"), 'a%20b%21%2A%27%28%29~-._%C3%B1');
  });

  test('credentials need all five variables', () {
    final todas = {
      'TUMBLR_BLOG': 'b',
      'TUMBLR_CONSUMER_KEY': 'k',
      'TUMBLR_CONSUMER_SECRET': 's',
      'TUMBLR_TOKEN': 't',
      'TUMBLR_TOKEN_SECRET': 'ts',
    };
    expect(CredencialesTumblr.delEntorno(todas)?.blog, 'b');
    expect(
        CredencialesTumblr.delEntorno({...todas, 'TUMBLR_TOKEN': ' '}), isNull);
  });

  test('posts the card and the NPF blocks, signed', () async {
    final servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    late String ruta, autorizacion, tipo;
    late Uint8List cuerpo;
    servidor.listen((peticion) async {
      ruta = peticion.uri.path;
      autorizacion = peticion.headers.value('authorization')!;
      tipo = peticion.headers.contentType!.mimeType;
      cuerpo = Uint8List.fromList(
          await peticion.fold<List<int>>([], (a, b) => a..addAll(b)));
      peticion.response
        ..statusCode = 201
        ..write(jsonEncode({
          'meta': {'status': 201},
          'response': {'id': '7654321'},
        }));
      await peticion.response.close();
    });
    addTearDown(servidor.close);

    final png = Uint8List.fromList([137, 80, 78, 71, 1, 2, 3]);
    final id = await HttpOverrides.runWithHttpOverrides(
      () => publicarEnTumblr(
        const CredencialesTumblr(
          blog: 'poemario-prueba',
          consumerKey: 'clave',
          consumerSecret: 'secreto',
          token: 'token',
          tokenSecret: 'secreto-token',
        ),
        PublicacionTumblr(
          png: png,
          ancho: 1600,
          alto: 2000,
          textoAlternativo: 'Soneto. Quevedo.',
          titulo: 'Soneto',
          autor: 'Quevedo',
          invitacion: 'Un poema cada día',
          enlace: 'https://example.com/app',
          etiquetas: const ['Soneto', 'Quevedo', 'poesía'],
        ),
        api: Uri.parse('http://127.0.0.1:${servidor.port}'),
      ),
      _RedReal(),
    );

    expect(id, '7654321');
    expect(ruta, '/v2/blog/poemario-prueba/posts');
    expect(tipo, 'multipart/form-data');
    expect(autorizacion, startsWith('OAuth '));
    for (final p in [
      'oauth_consumer_key="clave"',
      'oauth_token="token"',
      'oauth_signature_method="HMAC-SHA1"',
      'oauth_signature='
    ]) {
      expect(autorizacion, contains(p));
    }

    final texto = latin1.decode(cuerpo);
    final json = jsonDecode(utf8.decode(latin1.encode(RegExp(
            r'name="json"\r\nContent-Type: [^\r]+\r\n\r\n(.*?)\r\n--',
            dotAll: true)
        .firstMatch(texto)!
        .group(1)!))) as Map<String, Object?>;
    expect(json['tags'], 'Soneto,Quevedo,poesía');
    final bloques = json['content']! as List;
    expect(bloques.map((b) => (b as Map)['type']),
        ['image', 'text', 'text', 'text']);
    expect((bloques.last as Map)['formatting'], [
      {'start': 0, 'end': 17, 'type': 'link', 'url': 'https://example.com/app'}
    ]);
    expect(texto, contains('name="tarjeta"; filename="tarjeta.png"'));
    expect(texto, contains(latin1.decode(png)));
  });

  test('without a store link the closing line is left out', () {
    final npf = PublicacionTumblr(
      png: Uint8List(0),
      ancho: 1,
      alto: 1,
      textoAlternativo: '',
      titulo: 'T',
      autor: 'A',
      invitacion: 'Un poema cada día',
      etiquetas: const [],
    ).npf;
    expect((npf['content']! as List).length, 3);
    expect(npf.containsKey('state'), isFalse);
  });

  test('a scheduled post is queued for its time, in UTC', () {
    final npf = PublicacionTumblr(
      png: Uint8List(0),
      ancho: 1,
      alto: 1,
      textoAlternativo: '',
      titulo: 'T',
      autor: 'A',
      etiquetas: const [],
      programada: DateTime.utc(2026, 10, 22, 7),
    ).npf;
    expect(npf['state'], 'queue');
    expect(npf['publish_on'], '2026-10-22T07:00:00Z');
  });
}
