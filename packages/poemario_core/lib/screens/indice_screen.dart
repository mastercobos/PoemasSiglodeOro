import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/poema_repository.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/poema_colors.dart';
import '../theme/poema_theme.dart';
import '../utils/navegacion.dart';
import '../widgets/avatar_autor.dart';
import '../widgets/linea_oro.dart';
import '../widgets/poema_list_tile.dart';
import 'autor_screen.dart';

/// Index of authors. Was `home_screen.dart`, renamed because "home" and
/// "inicio" were two different tabs and reviewers kept opening the wrong file.
///
/// The grouping that used to run in `initState` (and again, identically, in
/// the favourites screen) is now done once at load in [Anthology].
class IndiceScreen extends StatelessWidget {
  const IndiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final l10n = L10n.of(context);
    final anthology = context.read<Anthology>();
    final autores = anthology.autores;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.indiceTitulo,
            style: context.tipos.appBarTitulo.copyWith(color: c.sobreSepia)),
        bottom: const LineaOro(),
      ),
      body: Column(
        children: [
          BandaSubtitulo(l10n.indiceSubtitulo),
          Expanded(
            child: ListView.builder(
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
