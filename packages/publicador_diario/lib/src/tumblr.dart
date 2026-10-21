import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// A blog's OAuth 1.0a credentials.
///
/// OAuth 1.0a rather than OAuth 2: its tokens never expire, so a bot on a
/// server needs no refresh dance and no state. Tumblr's API console
/// (https://api.tumblr.com/console) hands out the token and its secret for
/// an app registered at https://www.tumblr.com/oauth/apps.
class CredencialesTumblr {
  /// The blog posted to: its name (`poemario-siglodeoro`) or host name.
  final String blog;
  final String consumerKey;
  final String consumerSecret;
  final String token;
  final String tokenSecret;

  const CredencialesTumblr({
    required this.blog,
    required this.consumerKey,
    required this.consumerSecret,
    required this.token,
    required this.tokenSecret,
  });

  /// From `TUMBLR_BLOG`, `TUMBLR_CONSUMER_KEY`, `TUMBLR_CONSUMER_SECRET`,
  /// `TUMBLR_TOKEN` and `TUMBLR_TOKEN_SECRET`; null unless all are set.
  static CredencialesTumblr? delEntorno(Map<String, String> entorno) {
    String? leer(String clave) {
      final valor = entorno[clave]?.trim();
      return valor == null || valor.isEmpty ? null : valor;
    }

    final blog = leer('TUMBLR_BLOG');
    final consumerKey = leer('TUMBLR_CONSUMER_KEY');
    final consumerSecret = leer('TUMBLR_CONSUMER_SECRET');
    final token = leer('TUMBLR_TOKEN');
    final tokenSecret = leer('TUMBLR_TOKEN_SECRET');
    if (blog == null ||
        consumerKey == null ||
        consumerSecret == null ||
        token == null ||
        tokenSecret == null) {
      return null;
    }
    return CredencialesTumblr(
      blog: blog,
      consumerKey: consumerKey,
      consumerSecret: consumerSecret,
      token: token,
      tokenSecret: tokenSecret,
    );
  }
}

/// One post: the card, then the poem's title, its author and, once the app
/// is out, a line linking to its store page.
class PublicacionTumblr {
  final Uint8List png;
  final int ancho;
  final int alto;

  /// The card's alt text: the poem itself, for screen readers and search.
  final String textoAlternativo;

  final String titulo;
  final String autor;

  /// The closing line, linked to [enlace]. Left out when either is null.
  final String? invitacion;
  final String? enlace;

  final List<String> etiquetas;

  /// When Tumblr should publish the post; null publishes it at once.
  final DateTime? programada;

  const PublicacionTumblr({
    required this.png,
    required this.ancho,
    required this.alto,
    required this.textoAlternativo,
    required this.titulo,
    required this.autor,
    required this.etiquetas,
    this.invitacion,
    this.enlace,
    this.programada,
  });

  /// The post in Tumblr's Neue Post Format, the card sent alongside as the
  /// multipart part named `tarjeta`.
  Map<String, Object?> get npf {
    final invitacion = this.invitacion;
    final enlace = this.enlace;
    final programada = this.programada;
    return {
      'content': [
        {
          'type': 'image',
          'media': [
            {
              'type': 'image/png',
              'identifier': 'tarjeta',
              'width': ancho,
              'height': alto,
            },
          ],
          'alt_text': textoAlternativo,
        },
        {'type': 'text', 'subtype': 'heading2', 'text': titulo},
        {
          'type': 'text',
          'text': autor,
          'formatting': [
            {'start': 0, 'end': autor.runes.length, 'type': 'italic'},
          ],
        },
        if (invitacion != null && enlace != null)
          {
            'type': 'text',
            'text': invitacion,
            'formatting': [
              {
                'start': 0,
                'end': invitacion.runes.length,
                'type': 'link',
                'url': enlace,
              },
            ],
          },
      ],
      // Tumblr takes them comma-separated, so none may contain a comma.
      'tags': etiquetas.join(','),
      if (programada != null) ...{
        'state': 'queue',
        'publish_on': _iso(programada),
      },
    };
  }
}

/// [fecha] in UTC, to the second: `2026-10-22T07:00:00Z`.
String _iso(DateTime fecha) =>
    '${fecha.toUtc().toIso8601String().split('.').first.replaceAll('Z', '')}Z';

/// Posts [publicacion] to the blog and returns the new post's id.
///
/// [api] is Tumblr's API host, replaced in tests.
Future<String> publicarEnTumblr(
  CredencialesTumblr credenciales,
  PublicacionTumblr publicacion, {
  Uri? api,
}) async {
  final base = api ?? Uri.parse('https://api.tumblr.com');
  final url = base.replace(path: '/v2/blog/${credenciales.blog}/posts');

  final limite = 'poemario-${_aleatorio(24)}';
  final cuerpo = BytesBuilder()
    ..add(utf8.encode('--$limite\r\n'
        'Content-Disposition: form-data; name="json"\r\n'
        'Content-Type: application/json; charset=utf-8\r\n\r\n'))
    ..add(utf8.encode(jsonEncode(publicacion.npf)))
    ..add(utf8.encode('\r\n--$limite\r\n'
        'Content-Disposition: form-data; name="tarjeta"; '
        'filename="tarjeta.png"\r\n'
        'Content-Type: image/png\r\n\r\n'))
    ..add(publicacion.png)
    ..add(utf8.encode('\r\n--$limite--\r\n'));

  // A multipart body is not signed: only the oauth_* parameters are.
  final oauth = {
    'oauth_consumer_key': credenciales.consumerKey,
    'oauth_nonce': _aleatorio(32),
    'oauth_signature_method': 'HMAC-SHA1',
    'oauth_timestamp': '${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
    'oauth_token': credenciales.token,
    'oauth_version': '1.0',
  };
  oauth['oauth_signature'] = firmaOAuth1(
    metodo: 'POST',
    url: url,
    parametros: oauth,
    consumerSecret: credenciales.consumerSecret,
    tokenSecret: credenciales.tokenSecret,
  );
  final autorizacion = 'OAuth ${[
    for (final MapEntry(:key, :value) in oauth.entries)
      '${codificarOAuth(key)}="${codificarOAuth(value)}"',
  ].join(', ')}';

  final cliente = HttpClient();
  try {
    final peticion = await cliente.postUrl(url);
    peticion.headers
      ..set(HttpHeaders.authorizationHeader, autorizacion)
      ..contentType = ContentType('multipart', 'form-data',
          parameters: {'boundary': limite});
    final bytes = cuerpo.takeBytes();
    peticion.contentLength = bytes.length;
    peticion.add(bytes);
    final respuesta = await peticion.close();
    final texto = await respuesta.transform(utf8.decoder).join();
    if (respuesta.statusCode ~/ 100 != 2) {
      throw HttpException('Tumblr respondió ${respuesta.statusCode}: $texto',
          uri: url);
    }
    final datos = jsonDecode(texto) as Map<String, Object?>;
    final post = datos['response'] as Map<String, Object?>?;
    return '${post?['id'] ?? post?['id_string'] ?? ''}';
  } finally {
    cliente.close();
  }
}

/// The OAuth 1.0a HMAC-SHA1 signature of a request (RFC 5849 §3.4).
///
/// [parametros] are the oauth_* parameters plus any query or form-encoded
/// body parameters; [url]'s own query is folded in too.
String firmaOAuth1({
  required String metodo,
  required Uri url,
  required Map<String, String> parametros,
  required String consumerSecret,
  String tokenSecret = '',
}) {
  final todos = [
    for (final MapEntry(:key, :value) in {
      ...url.queryParameters,
      ...parametros,
    }.entries)
      (codificarOAuth(key), codificarOAuth(value)),
  ]..sort((a, b) {
      final porClave = a.$1.compareTo(b.$1);
      return porClave != 0 ? porClave : a.$2.compareTo(b.$2);
    });
  final normalizados = todos.map((p) => '${p.$1}=${p.$2}').join('&');
  // Scheme, host, a non-default port and path; no query or fragment.
  final sinQuery = Uri(
    scheme: url.scheme,
    host: url.host,
    port: url.hasPort ? url.port : null,
    path: url.path,
  ).toString();
  final base = [
    metodo.toUpperCase(),
    codificarOAuth(sinQuery),
    codificarOAuth(normalizados),
  ].join('&');
  final clave =
      '${codificarOAuth(consumerSecret)}&${codificarOAuth(tokenSecret)}';
  final firma = Hmac(sha1, utf8.encode(clave)).convert(utf8.encode(base));
  return base64.encode(firma.bytes);
}

/// RFC 3986 percent-encoding, as OAuth asks: everything but letters, digits
/// and `-._~`. [Uri.encodeComponent] leaves `!*'()` alone, which would break
/// the signature.
String codificarOAuth(String texto) => Uri.encodeComponent(texto)
    .replaceAll('!', '%21')
    .replaceAll('*', '%2A')
    .replaceAll("'", '%27')
    .replaceAll('(', '%28')
    .replaceAll(')', '%29');

final _azar = Random.secure();
String _aleatorio(int n) {
  const letras =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  return String.fromCharCodes(
      [for (var i = 0; i < n; i++) letras.codeUnitAt(_azar.nextInt(62))]);
}
