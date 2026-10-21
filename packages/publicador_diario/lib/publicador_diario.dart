/// The daily Tumblr bot: each app's two poems of the day, posted as the
/// app's own share card to the app's own blog.
///
/// Each app calls [publicarPoemasDelDia] from `publicacion/publicacion_test.dart`
/// with its [AppConfig] and a [GuionPublicacion], and a server runs it once
/// or twice a day from the app's folder (see `publicar.sh` beside this
/// package):
///
///     flutter test publicacion/
///
/// It runs under `flutter test` because the card is the real
/// [TarjetaCompartir] widget, drawn by the engine with the app's fonts and
/// ornament, exactly as the app shares it.
///
/// Environment:
///
/// * `TUMBLR_BLOG`, `TUMBLR_CONSUMER_KEY`, `TUMBLR_CONSUMER_SECRET`,
///   `TUMBLR_TOKEN`, `TUMBLR_TOKEN_SECRET`: the blog and its credentials
///   ([CredencialesTumblr]). Without them, or with `SIMULAR=1`, nothing is
///   posted: each post's card and JSON are written to `$SALIDA` (default
///   `build/publicaciones`) to look at.
/// * `CUAL`: `1` or `2` posts only that poem of the day (one in the morning,
///   one in the evening); unset posts both.
/// * `FECHA`: `2026-10-12` posts that day's poems instead of today's.
/// * `DIAS`: `30` schedules the poems of 30 days from `FECHA` (or today)
///   instead of posting them: each goes to Tumblr with its publication time,
///   [GuionPublicacion.horas] in the machine's time zone (`publicar.sh` sets
///   `TZ`), and Tumblr publishes it then. A time already past is skipped.
/// * `ESTADO`: the folder that records what has been posted (default
///   `build/publicaciones`). A poem already posted is never posted again, so
///   a run that failed halfway can simply be repeated.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:capturas_tienda/capturas_tienda.dart' show cargarFuentes;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poemario_core/config/app_config.dart';
import 'package:poemario_core/data/poema.dart';
import 'package:poemario_core/data/poema_repository.dart';
import 'package:poemario_core/domain/seleccion_diaria.dart';
import 'package:poemario_core/l10n/generated/app_localizations.dart';
import 'package:poemario_core/utils/compartir_poema.dart';
import 'package:provider/provider.dart';

import 'src/tumblr.dart';

export 'src/tumblr.dart';

/// What an app's posts say besides the poem.
class GuionPublicacion {
  final AppConfig config;

  /// Tags after the poem's author and before its title and
  /// [AppConfig.nombreTienda]: the language's poetry tags, the period. The
  /// most searched go first, as Tumblr's tag pages and search weigh a post's
  /// first tags most.
  final List<String> etiquetas;

  /// The closing line of each post, linked to [enlaceTienda].
  final String invitacion;

  /// The app's store page; null while it isn't out, which leaves the closing
  /// line off.
  final String? enlaceTienda;

  /// The hour each poem of the day is published at when scheduled (`DIAS`):
  /// the first poem at `horas[0]`, the second at `horas[1]`.
  final List<int> horas;

  const GuionPublicacion({
    required this.config,
    required this.etiquetas,
    required this.invitacion,
    this.enlaceTienda,
    this.horas = const [9, 20],
  });
}

/// The first day of the bot's own run of days. Each day's selection avoids
/// the authors of the two days before, as in the app, and this is where that
/// chain starts. Never change it: every day's poems after it would change.
final origenSerie = DateTime(2026, 10, 1);

/// The poems of the day for [fecha], with every author selected.
///
/// The same [SeleccionDiariaService] as the app's Home, carried day by day
/// from [origenSerie] so no author repeats from one day to the next.
SeleccionDiaria seleccionPara(List<Poema> pool, DateTime fecha) {
  final dias = DateTime.utc(fecha.year, fecha.month, fecha.day)
          .difference(DateTime.utc(
              origenSerie.year, origenSerie.month, origenSerie.day))
          .inDays +
      1;
  if (dias < 1) {
    return SeleccionDiariaService.paraFecha(pool: pool, fecha: fecha);
  }
  return SeleccionDiariaService.serie(
          pool: pool, desde: origenSerie, dias: dias)
      .last;
}

/// [poema]'s title as a post shows it: without the edition's numbering
/// ("- 1329 - Jornada II…", "- CXLVIII - Josefa Vaca…"), and its first verse
/// when the numbering is all there is ("- 96 -"). The card keeps the title as
/// the app prints it; this is only the post's heading, tag and alt text.
String tituloPara(Poema poema) {
  final titulo = poema.etiqueta.replaceFirst(_numeracion, '').trim();
  return titulo.isNotEmpty ? titulo : poema.primerVerso.trim();
}

final _numeracion = RegExp(r'^\s*[-–—]\s*[0-9IVXLCDM]*\s*[-–—]\s*');

/// [poema]'s tags: its author, then [extra], then its title and the app's
/// name, which few people search for. Tumblr separates tags with commas and
/// caps them at 140 characters; a repeated tag is dropped.
List<String> etiquetasPara(Poema poema, String nombreApp, List<String> extra) {
  final vistas = <String>{};
  return [
    for (final bruta in [poema.autor, ...extra, tituloPara(poema), nombreApp])
      if (_limpiarEtiqueta(bruta) case final e
          when e.isNotEmpty && vistas.add(e.toLowerCase()))
        e,
  ];
}

String _limpiarEtiqueta(String texto) {
  final limpia = texto
      .replaceAll(RegExp(r'[,#«»“”"]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      // "- CXLVIII - Josefa Vaca": a numbering dash, or a closing "…".
      .replaceAll(RegExp(r'^[-–—\s]+|[-–—.;:…\s]+$'), '');
  return limpia.length <= 140 ? limpia : limpia.substring(0, 140).trim();
}

/// Declares the test that posts the day's poems.
void publicarPoemasDelDia(GuionPublicacion guion) {
  final entorno = Platform.environment;
  final fecha = DateTime.tryParse(entorno['FECHA'] ?? '') ?? DateTime.now();
  final dia = DateTime(fecha.year, fecha.month, fecha.day);
  final cual = int.tryParse(entorno['CUAL'] ?? '');
  final dias = int.tryParse(entorno['DIAS'] ?? '');
  final credenciales =
      entorno['SIMULAR'] == '1' ? null : CredencialesTumblr.delEntorno(entorno);
  final salida = entorno['SALIDA'] ?? 'build/publicaciones';
  final estado = entorno['ESTADO'] ?? 'build/publicaciones';
  final config = guion.config;
  final nombre = dias == null
      ? 'poemas del día ${_fecha(dia)}'
      : 'poemas de $dias días desde ${_fecha(dia)}';

  testWidgets(nombre, (tester) async {
    await tester.runAsync(() => cargarFuentes(config.fuentes.body));
    final anthology = (await tester.runAsync(() => PoemaRepository(
          assetPath: config.assetPoemas,
          compararTitulos: config.compararTitulos,
        ).cargar()))!;
    final aviso =
        lookupL10n(config.locale).compartirLeerCompleto(config.nombreTienda);

    for (var d = 0; d < (dias ?? 1); d++) {
      final fecha = DateTime(dia.year, dia.month, dia.day + d);
      final nombreDia = _fecha(fecha);
      final poemas = seleccionPara(anthology.poemas, fecha).poemas;
      for (final (i, poema) in poemas.indexed) {
        final n = i + 1;
        if (cual != null && cual != n) continue;
        final programada = dias == null
            ? null
            : DateTime(fecha.year, fecha.month, fecha.day, guion.horas[i]);
        if (programada != null && programada.isBefore(DateTime.now())) {
          // ignore: avoid_print
          print('$nombreDia #$n: ${guion.horas[i]}:00 ya ha pasado');
          continue;
        }
        final marca =
            File('$estado/${config.locale.languageCode}_${nombreDia}_$n.json');
        if (credenciales != null && marca.existsSync()) {
          // ignore: avoid_print
          print('Ya publicado: ${marca.path}');
          continue;
        }

        await tester.runAsync(poema.cargarTexto);
        // The first poem in the light theme, the second in the dark one, so
        // the blog shows both of the app's faces.
        final png = await _dibujarTarjeta(
          tester,
          config: config,
          poema: poema,
          aviso: aviso,
          oscuro: n == 2,
        );
        final publicacion = PublicacionTumblr(
          png: png,
          ancho: (_anchoTarjeta * _escala).round(),
          alto: (_altoTarjeta * _escala).round(),
          textoAlternativo: _textoAlternativo(poema),
          titulo: tituloPara(poema),
          autor: poema.autor,
          invitacion: guion.invitacion,
          enlace: guion.enlaceTienda,
          etiquetas: etiquetasPara(poema, config.nombreTienda, guion.etiquetas),
          programada: programada,
        );

        // ignore: avoid_print
        print('$nombreDia #$n: ${tituloPara(poema)} — ${poema.autor}'
            '${programada == null ? '' : ', a las ${guion.horas[i]}:00'}');
        if (credenciales == null) {
          final carpeta = '$salida/$nombreDia';
          File('$carpeta/${n}_tarjeta.png')
            ..createSync(recursive: true)
            ..writeAsBytesSync(png);
          File('$carpeta/${n}_post.json').writeAsStringSync(
              const JsonEncoder.withIndent('  ').convert(publicacion.npf));
          // ignore: avoid_print
          print('  simulado, en $carpeta');
          continue;
        }

        final id =
            await tester.runAsync(() => HttpOverrides.runWithHttpOverrides(
                  () => publicarEnTumblr(credenciales, publicacion),
                  _RedReal(),
                ));
        marca
          ..createSync(recursive: true)
          ..writeAsStringSync(jsonEncode({
            'blog': credenciales.blog,
            'id': id,
            'poema': poema.id,
            'publicado': DateTime.now().toIso8601String(),
            if (programada != null) 'programado': programada.toIso8601String(),
          }));
        // ignore: avoid_print
        print('  ${programada == null ? 'publicado' : 'programado'} en '
            '${credenciales.blog}: $id');
      }
    }
  }, timeout: Timeout(Duration(minutes: 5 + 2 * (dias ?? 0))));
}

const _anchoTarjeta = 800.0;
const _altoTarjeta = 1000.0;

/// 1600 × 2000: sharp on a phone, well under Tumblr's image size limit.
const _escala = 2.0;

/// Draws [poema]'s share card as the app would share it.
Future<Uint8List> _dibujarTarjeta(
  WidgetTester tester, {
  required AppConfig config,
  required Poema poema,
  required String aviso,
  required bool oscuro,
}) async {
  tester.view
    ..physicalSize = const Size(_anchoTarjeta * _escala, _altoTarjeta * _escala)
    ..devicePixelRatio = _escala;
  addTearDown(tester.view.reset);

  final clave = GlobalKey();
  await tester.pumpWidget(Provider<AppConfig>.value(
    value: config,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: oscuro ? config.temaOscuro : config.temaClaro,
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.noScaling),
        child: Material(
          type: MaterialType.transparency,
          child: Align(
            alignment: Alignment.topLeft,
            child: RepaintBoundary(
              key: clave,
              child: TarjetaCompartir(
                poema: poema,
                firma: config.firmaCompartir,
                avisoCompleto: aviso,
              ),
            ),
          ),
        ),
      ),
    ),
  ));

  // The ornament's image decodes on the real event loop, which the test's
  // fake clock doesn't run.
  for (var i = 0; i < 4; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await tester.pump(const Duration(milliseconds: 100));
  }

  final limite =
      clave.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final png = await tester.runAsync(() async {
    final imagen = await limite.toImage(pixelRatio: _escala);
    final datos = await imagen.toByteData(format: ui.ImageByteFormat.png);
    imagen.dispose();
    return datos!.buffer.asUint8List();
  });
  return png!;
}

/// The title, the author and the whole text: the card shows a long poem
/// only in part.
String _textoAlternativo(Poema poema) {
  final texto =
      '${tituloPara(poema)}. ${poema.autor}.\n\n${poema.texto.trim()}';
  // Tumblr's alt text limit is 4096 characters.
  return texto.length <= 4000 ? texto : '${texto.substring(0, 3999)}…';
}

String _fecha(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// `flutter test` answers every HTTP request with a 400; this lets the post
/// out.
class _RedReal extends HttpOverrides {}
