import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/poema_repository.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/poema_colors.dart';
import '../theme/poema_theme.dart';
import '../utils/navegacion.dart';
import '../widgets/linea_oro.dart';
import '../widgets/poema_list_tile.dart';

/// Every poem by one author.
///
/// Takes only the author's name now. It used to receive both the author's
/// poems *and* the whole anthology, and re-sorted the list on every build even
/// though the caller had already sorted it.
class AutorScreen extends StatelessWidget {
  final String autor;

  const AutorScreen({super.key, required this.autor});

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    // Already grouped and sorted at load time.
    final poemas = context.read<Anthology>().porAutor[autor] ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: Text(autor,
            style: context.tipos.appBarTituloPequeno
                .copyWith(color: c.sobreSepia),
            overflow: TextOverflow.ellipsis),
        bottom: const LineaOro(),
      ),
      body: Column(
        children: [
          BandaSubtitulo(L10n.of(context).poemasContador(poemas.length)),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.only(bottom: espacioBarraFlotante(context)),
              itemCount: poemas.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: c.oroClaro.withValues(alpha: 0.3),
              ),
              itemBuilder: (context, i) => PoemaListTile(
                key: ValueKey(poemas[i].id),
                poema: poemas[i],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
