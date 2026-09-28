import 'package:flutter/widgets.dart';

/// Reports two-finger pinches over [child] without taking part in the gesture
/// arena.
///
/// A [ScaleGestureRecognizer] inside a scroll view loses to the scroll's drag
/// as soon as the first finger moves, and would compete with a
/// [SelectionArea]'s long press and drag. Raw pointer events see every
/// finger whoever wins, so scrolling and selecting behave as before and the
/// pinch is read alongside them.
///
/// [alEmpezar] gets the focal point (between the two fingers, in [child]'s
/// coordinates); [alCambiar] the distance between the fingers relative to the
/// start, and the current focal point, until either finger lifts;
/// [alTerminar] fires once every finger is up, so a caller that holds
/// scrolling during the pinch doesn't let the remaining finger fling it.
class Pellizco extends StatefulWidget {
  final void Function(Offset foco)? alEmpezar;
  final void Function(double escala, Offset foco) alCambiar;
  final VoidCallback? alTerminar;
  final Widget child;

  const Pellizco({
    super.key,
    this.alEmpezar,
    required this.alCambiar,
    this.alTerminar,
    required this.child,
  });

  @override
  State<Pellizco> createState() => _PellizcoState();
}

class _PellizcoState extends State<Pellizco> {
  final _dedos = <int, Offset>{};

  /// The two pointers being followed and their distance at the start, while
  /// a pinch is on.
  (int, int)? _par;
  double _distanciaInicial = 0;
  bool _hubo = false;

  Offset _foco((int, int) par) => (_dedos[par.$1]! + _dedos[par.$2]!) / 2;

  double _distancia((int, int) par) =>
      (_dedos[par.$1]! - _dedos[par.$2]!).distance;

  void _abajo(PointerDownEvent e) {
    _dedos[e.pointer] = e.localPosition;
    if (_par != null || _dedos.length != 2) return;
    final par = (_dedos.keys.first, _dedos.keys.last);
    final distancia = _distancia(par);
    if (distancia < 1) return;
    _par = par;
    _distanciaInicial = distancia;
    _hubo = true;
    widget.alEmpezar?.call(_foco(par));
  }

  void _mover(PointerMoveEvent e) {
    if (!_dedos.containsKey(e.pointer)) return;
    _dedos[e.pointer] = e.localPosition;
    final par = _par;
    if (par == null || (e.pointer != par.$1 && e.pointer != par.$2)) return;
    widget.alCambiar(_distancia(par) / _distanciaInicial, _foco(par));
  }

  void _arriba(PointerEvent e) {
    _dedos.remove(e.pointer);
    final par = _par;
    if (par != null && (e.pointer == par.$1 || e.pointer == par.$2)) {
      _par = null;
    }
    if (_dedos.isEmpty && _hubo) {
      _hubo = false;
      widget.alTerminar?.call();
    }
  }

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: _abajo,
        onPointerMove: _mover,
        onPointerUp: _arriba,
        onPointerCancel: _arriba,
        child: widget.child,
      );
}
