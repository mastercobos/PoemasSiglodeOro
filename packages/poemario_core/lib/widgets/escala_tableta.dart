import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../theme/poema_theme.dart';
import '../utils/navegacion.dart';

/// Larger text on a tablet, as large as the reader allows.
///
/// A phone's text sizes on a tablet leave a sonnet sitting in a small block
/// of a large, empty page. Here every text in the app grows by one factor:
/// the largest at which, with the system's text size at its default, the
/// reader still shows
///
/// * a whole sonnet, heading included, between the app bar and the nav pill,
///   and
/// * the anthology's longest sonnet verse ([AppConfig.versoMasLargo]) on one
///   line.
///
/// The column width ([margenLateral]) grows by the same factor, so lines
/// break where they would on a phone. A reader's own larger system text size
/// multiplies on top. Phones (shortest side under [ladoMinimo]) are left
/// exactly as they are.
///
/// It depends on the orientation: turned sideways, a tablet is shorter, so
/// the factor is smaller.
class EscalaTableta extends StatefulWidget {
  final Widget child;

  const EscalaTableta({super.key, required this.child});

  /// Material's breakpoint between phones and tablets.
  static const ladoMinimo = 600.0;

  /// Never more than this, whatever the screen.
  static const factorMaximo = 2.0;

  /// The factor in force above [context]; 1 on a phone or without an
  /// [EscalaTableta].
  static double factorDe(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_Factor>()?.factor ?? 1;

  /// The factor for a screen described by [datos], with the app's text
  /// styles [tipos] and its longest sonnet verse [verso].
  @visibleForTesting
  static double calcular(
    MediaQueryData datos,
    PoemaTextStyles tipos,
    String verso,
  ) {
    if (datos.size.shortestSide < ladoMinimo) return 1;
    final usuario = datos.textScaler;
    bool cabe(double f) =>
        _cabeSoneto(datos, tipos, verso, _Por(usuario, f), f);
    if (!cabe(1)) return 1;
    if (cabe(factorMaximo)) return factorMaximo;
    // Bisection: both conditions only get harder as the factor grows.
    var bajo = 1.0;
    var alto = factorMaximo;
    for (var i = 0; i < 16; i++) {
      final medio = (bajo + alto) / 2;
      if (cabe(medio)) {
        bajo = medio;
      } else {
        alto = medio;
      }
    }
    return bajo;
  }

  @override
  State<EscalaTableta> createState() => _EscalaTabletaState();
}

class _EscalaTabletaState extends State<EscalaTableta> {
  // MediaQuery changes for many reasons (the keyboard, among others); only
  // these change the factor.
  Object? _clave;
  double _factor = 1;

  @override
  Widget build(BuildContext context) {
    final datos = MediaQuery.of(context);
    final verso = context.config.versoMasLargo;
    final clave = (
      datos.size,
      datos.padding.top,
      datos.padding.bottom,
      datos.textScaler,
      context.tipos,
      verso,
    );
    if (clave != _clave) {
      _clave = clave;
      _factor = EscalaTableta.calcular(datos, context.tipos, verso);
    }
    if (_factor == 1) return widget.child;
    return _Factor(
      factor: _factor,
      child: MediaQuery(
        data: datos.copyWith(textScaler: _Por(datos.textScaler, _factor)),
        child: widget.child,
      ),
    );
  }
}

class _Factor extends InheritedWidget {
  final double factor;

  const _Factor({required this.factor, required super.child});

  @override
  bool updateShouldNotify(_Factor anterior) => factor != anterior.factor;
}

/// The reader's own scaler, times [factor].
class _Por extends TextScaler {
  final TextScaler base;
  final double factor;

  const _Por(this.base, this.factor);

  @override
  double scale(double fontSize) => base.scale(fontSize) * factor;

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => base.textScaleFactor * factor;

  @override
  bool operator ==(Object other) =>
      other is _Por && other.base == base && other.factor == factor;

  @override
  int get hashCode => Object.hash(base, factor);
}

/// Whether, with [escalador] (column [factor] times wider), the reader shows
/// a 4-4-3-3 sonnet whole and [verso] on one line.
///
/// Mirrors `PoemaScreen`'s page: keep the two in step. The widget test "a
/// sonnet fits whole on a tablet" checks this against the real reader.
bool _cabeSoneto(
  MediaQueryData datos,
  PoemaTextStyles t,
  String verso,
  TextScaler escalador,
  double factor,
) {
  double medir(String texto, TextStyle estilo, {double? ancho}) {
    final p = TextPainter(
      text: TextSpan(text: texto, style: estilo),
      textScaler: escalador,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: ancho ?? double.infinity);
    final valor = ancho == null ? p.width : p.height;
    p.dispose();
    return valor;
  }

  // Horizontal: the verse on one line in the page's column.
  const margenPagina = 28.0;
  // As margenLateral lays it out.
  final margen = math.max(
      margenPagina, (datos.size.width - anchoMaximoColumna * factor) / 2);
  final columna = datos.size.width - 2 * margen;
  if (medir(verso, t.verso) > columna) return false;

  // Vertical: from the page's top to the sonnet's last verse.
  const sinLimite = 1e6;
  final cabecera = 36 + // page padding
      18 * 1.7 + // the ornament's emblem
      28 +
      medir('Ág', t.tituloPoema, ancho: sinLimite) +
      4 +
      medir('Ág',
          t.cuerpoPequeno.copyWith(fontSize: 13, fontStyle: FontStyle.italic),
          ancho: sinLimite) +
      6 +
      20 + // the author link's padding
      medir('Ág', t.autorCursiva.copyWith(fontSize: 14), ancho: sinLimite) +
      26 +
      2 + // the rule
      34;
  final soneto = [
    for (final estrofa in [4, 4, 3, 3]) List.filled(estrofa, 'Ág').join('\n'),
  ].join('\n\n');
  final versos = medir(soneto, t.verso, ancho: sinLimite);

  final barraSuperior = datos.padding.top + kToolbarHeight + 1;
  final pildora = espacioBarraFlotanteCon(
    escalador: escalador,
    etiqueta: t.navLabel,
    margenSistema: datos.padding.bottom,
  );
  // Room between the last verse and the pill, so the sonnet doesn't read
  // as running under it.
  const holgura = 24.0;
  return cabecera + versos + holgura <=
      datos.size.height - barraSuperior - pildora;
}
