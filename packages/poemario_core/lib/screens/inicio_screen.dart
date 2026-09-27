import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../widgets/versos_ajustados.dart';
import '../data/poema.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/ajustes_provider.dart';
import '../providers/poema_del_dia_provider.dart';
import '../theme/poema_colors.dart';
import '../theme/poema_theme.dart';
import '../utils/navegacion.dart';
import '../widgets/texto_de_poema.dart';
import '../widgets/linea_oro.dart';
import '../widgets/ornamento.dart';
import '../widgets/poema_list_tile.dart';
import 'ajustes_screen.dart';
import 'poema_screen.dart';

/// Poems of the day.
///
/// The selection, its caching and the date now live in [PoemaDelDiaProvider];
/// this screen only draws. That is what lets the notification scheduler show
/// the same poem in tomorrow morning's notification.
///
/// The date string comes from `intl` rather than a hand-written month array,
/// so it's correct in every locale an app is built for.
class InicioScreen extends StatefulWidget {
  const InicioScreen({super.key});

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> {
  @override
  void initState() {
    super.initState();
    // Record today's authors once they've actually been shown, so tomorrow's
    // pick can avoid them.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<PoemaDelDiaProvider>().registrarVisto();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final t = context.tipos;
    final l10n = L10n.of(context);
    final config = context.config;

    final diario = context.watch<PoemaDelDiaProvider>();
    final ajustes = context.watch<AjustesProvider>();
    final destacados = diario.poemasDelDia;

    final fecha = DateFormat.yMMMMd(config.locale.toLanguageTag())
        .format(diario.seleccion.fecha);

    return Scaffold(
      appBar: AppBar(
        title: Text(config.nombreApp,
            style: t.appBarTitulo.copyWith(color: c.sobreSepia)),
        bottom: const LineaOro(),
        actions: [
          IconButton(
            tooltip: l10n.inicioFiltrarAutores,
            icon: Icon(Icons.tune, color: c.oroClaro, size: 22),
            onPressed: () => Navigator.of(context)
                .push(rutaFundido((_) => const AjustesScreen())),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(18, 24, 18, espacioBarraFlotante(context)),
        child: Column(
          children: [
            Text(fecha.toUpperCase(),
                textAlign: TextAlign.center,
                style: t.cuerpoPequeno
                    .copyWith(fontSize: 10, letterSpacing: 2, color: c.oro)),
            const SizedBox(height: 6),
            Text(l10n.inicioPoemasDelDia,
                textAlign: TextAlign.center,
                style: t.tituloPoema.copyWith(fontSize: 24, color: c.texto)),
            const SizedBox(height: 8),
            const Filete(),
            const SizedBox(height: 10),
            Text(
              ajustes.todosSeleccionados
                  ? l10n.inicioTodosLosAutores
                  : l10n.inicioAutoresSeleccionados(ajustes.totalActivos),
              textAlign: TextAlign.center,
              style: t.cuerpoPequeno
                  .copyWith(fontSize: 11, color: c.textoSuave, letterSpacing: .5),
            ),
            const SizedBox(height: 24),
            if (destacados.isEmpty)
              _SinAutores(l10n: l10n)
            else
              for (final p in destacados)
                _TarjetaPoemaDelDia(key: ValueKey(p.id), poema: p),
          ],
        ),
      ),
    );
  }
}

class _SinAutores extends StatelessWidget {
  final L10n l10n;
  const _SinAutores({required this.l10n});

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Column(
        children: [
          Icon(Icons.sentiment_neutral, size: 48, color: c.oroClaro),
          const SizedBox(height: 16),
          Text(l10n.inicioSinAutores,
              textAlign: TextAlign.center,
              style: context.tipos.tituloTarjeta.copyWith(color: c.texto)),
          const SizedBox(height: 8),
          TextButton.icon(
            icon: Icon(Icons.tune, color: c.oro),
            label: Text(l10n.inicioConfigurarAutores,
                style: TextStyle(color: c.oro)),
            onPressed: () => Navigator.of(context)
                .push(rutaFundido((_) => const AjustesScreen())),
          ),
        ],
      ),
    );
  }
}

/// A poem of the day: sepia header, opening lines, call to action.
class _TarjetaPoemaDelDia extends StatelessWidget {
  final Poema poema;
  const _TarjetaPoemaDelDia({super.key, required this.poema});

  /// The first four lines of the poem, honouring its own stanza breaks.
  String get _fragmento {
    final versos = poema.versos.take(4).join('\n');
    return poema.versos.length > 4 ? '$versos\n…' : versos;
  }

  /// [_fragmento] for [DisposicionVersos.ajustada]: the first four verses,
  /// section marks left out, as one stanza for [VersosAjustados].
  List<List<String>> get _fragmentoAjustado {
    final versos = [
      for (final e in poema.estrofas)
        if (!esMarcaDeSeccion(e)) ...e,
    ];
    return [
      [...versos.take(4), if (versos.length > 4) '…'],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final t = context.tipos;
    final l10n = L10n.of(context);

    return MergeSemantics(
      child: TarjetaPoemario(
        margen: const EdgeInsets.only(bottom: 20),
        radio: 14,
        child: Material(
          color: c.tarjeta,
          child: InkWell(
            onTap: () => Navigator.of(context)
                .push(rutaFundido((_) => PoemaScreen(poema: poema))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: c.sepia,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(poema.etiqueta,
                          style: t.tituloTarjeta.copyWith(color: c.sobreSepia)),
                      if (poema.mostrarPrimerVerso)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text('«${poema.primerVerso}»',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.cuerpoPequeno.copyWith(
                                  color: c.sobreSepia.withValues(alpha: .54),
                                  fontStyle: FontStyle.italic)),
                        ),
                      const SizedBox(height: 4),
                      Text(poema.autor,
                          style: t.autorCursiva.copyWith(color: c.oroClaro)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
                  child: TextoDePoema(
                    poema: poema,
                    builder: (_) {
                      final estilo = t.verso.copyWith(
                          fontSize: 15, height: 1.85, color: c.texto);
                      if (context.config.disposicionVersos ==
                          DisposicionVersos.ajustada) {
                        return VersosAjustados(
                            estrofas: _fragmentoAjustado,
                            estilo: estilo,
                            alineacion: TextAlign.start);
                      }
                      return Text(_fragmento, style: estilo);
                    },
                  ),
                ),
                // Plain text, not a disabled TextButton. The old version used
                // `onPressed: null`, so screen readers announced a disabled
                // button sitting on top of the card that was the real target.
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: ExcludeSemantics(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 4, 18, 14),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.menu_book_outlined, size: 16, color: c.oro),
                          const SizedBox(width: 6),
                          Text(l10n.inicioLeerCompleto,
                              style: t.cuerpoPequeno.copyWith(
                                  fontSize: 13,
                                  color: c.oro,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
