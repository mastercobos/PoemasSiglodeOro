import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/poema_repository.dart';
import '../domain/orden_titulos.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/poema_colors.dart';
import '../theme/poema_theme.dart';
import '../utils/navegacion.dart';
import '../widgets/avatar_autor.dart';
import '../widgets/campo_busqueda.dart';
import '../widgets/poema_list_tile.dart';
import 'autor_screen.dart';

/// Index of authors. Was `home_screen.dart`, renamed because "home" and
/// "inicio" were two different tabs and reviewers kept opening the wrong file.
///
/// The grouping that used to run in `initState` (and again, identically, in
/// the favourites screen) is now done once at load in [Anthology].
///
/// The author filter matches anywhere in the name, ignoring case and accents,
/// so "lope" finds "Lope de Vega" and "gongora" finds "Góngora". With a few
/// hundred authors the list is filtered on every keystroke; no debounce.
class IndiceScreen extends StatefulWidget {
  const IndiceScreen({super.key});

  @override
  State<IndiceScreen> createState() => _IndiceScreenState();
}

class _IndiceScreenState extends State<IndiceScreen> {
  final _controlador = TextEditingController();

  /// Folded query; empty shows every author.
  String _consulta = '';

  @override
  void initState() {
    super.initState();
    _controlador.addListener(_alEscribir);
  }

  @override
  void dispose() {
    _controlador
      ..removeListener(_alEscribir)
      ..dispose();
    super.dispose();
  }

  void _alEscribir() {
    final consulta = plegarParaOrden(_controlador.text.trim());
    if (consulta != _consulta) setState(() => _consulta = consulta);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final t = context.tipos;
    final l10n = L10n.of(context);
    final anthology = context.read<Anthology>();
    final autores = _consulta.isEmpty
        ? anthology.autores
        : [
            for (final a in anthology.autores)
              if (plegarParaOrden(a).contains(_consulta)) a,
          ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.indiceTitulo,
            style: t.appBarTitulo.copyWith(color: c.sobreSepia)),
        bottom: CampoBusqueda(
          controlador: _controlador,
          pista: l10n.indiceBuscarPista,
          borrar: l10n.buscarBorrar,
        ),
      ),
      body: Column(
        children: [
          BandaSubtitulo(l10n.indiceSubtitulo),
          Expanded(
            child: autores.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        l10n.indiceSinResultados(_controlador.text.trim()),
                        textAlign: TextAlign.center,
                        style: t.cuerpo.copyWith(color: c.textoSuave),
                      ),
                    ),
                  )
                : ListView.builder(
                    // Back to the top when the filter changes, as in Search.
                    key: ValueKey(_consulta),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                        14, 14, 14, espacioBarraFlotante(context)),
                    itemCount: autores.length,
                    itemBuilder: (context, i) {
                      final autor = autores[i];
                      return _TarjetaAutor(
                        key: ValueKey(autor),
                        autor: autor,
                        totalPoemas: anthology.porAutor[autor]!.length,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaAutor extends StatelessWidget {
  final String autor;
  final int totalPoemas;

  const _TarjetaAutor({
    super.key,
    required this.autor,
    required this.totalPoemas,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final t = context.tipos;

    return MergeSemantics(
      child: TarjetaPoemario(
        child: Material(
          color: c.tarjeta,
          child: InkWell(
            onTap: () => Navigator.of(context)
                .push(rutaFundido((_) => AutorScreen(autor: autor))),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              // A fixed-size avatar beside a name genuinely can't grow without
              // bound, so scaling is capped here — and only here.
              child: EscalaLimitada(
                maximo: 1.3,
                child: Row(
                  children: [
                    AvatarAutor(autor: autor),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(autor,
                              style: t.autorTarjeta.copyWith(color: c.texto)),
                          const SizedBox(height: 2),
                          Text(L10n.of(context).poemasContador(totalPoemas),
                              style:
                                  t.cuerpoPequeno.copyWith(color: c.oro)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 22, color: c.oro),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
