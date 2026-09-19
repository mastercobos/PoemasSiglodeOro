import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/poema.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/favoritos_provider.dart';
import '../theme/poema_colors.dart';
import '../theme/poema_theme.dart';
import '../utils/navegacion.dart';
import '../widgets/avatar_autor.dart';
import '../widgets/linea_oro.dart';
import '../widgets/poema_list_tile.dart';
import 'autor_screen.dart';

/// Saved poems, grouped by author.
///
/// The grouping helper that was duplicated here and in the index screen is
/// gone; favourites arrive in anthology order and are grouped with a single
/// pass that preserves it, so the two screens can no longer disagree about
/// ordering.
class FavoritosScreen extends StatelessWidget {
  const FavoritosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final l10n = L10n.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.favoritosTitulo,
            style: context.tipos.appBarTitulo.copyWith(color: c.sobreSepia)),
        bottom: const LineaOro(),
      ),
      body: Consumer<FavoritosProvider>(
        builder: (context, favoritos, _) {
          final lista = favoritos.favoritos;
          if (lista.isEmpty) return _Vacio(l10n: l10n);

          final grupos = <String, List<Poema>>{};
          for (final p in lista) {
            grupos.putIfAbsent(p.autor, () => []).add(p);
          }
          final autores = grupos.keys.toList();

          return Column(
            children: [
              BandaSubtitulo(l10n.favoritosGuardados(lista.length)),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                      14, 14, 14, espacioBarraFlotante(context)),
                  itemCount: autores.length,
                  itemBuilder: (context, i) => _GrupoAutor(
                    key: ValueKey(autores[i]),
                    autor: autores[i],
                    poemas: grupos[autores[i]]!,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Vacio extends StatelessWidget {
  final L10n l10n;
  const _Vacio({required this.l10n});

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final t = context.tipos;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_border, size: 64, color: c.oroClaro),
            const SizedBox(height: 20),
            Text(l10n.favoritosVacioTitulo,
                textAlign: TextAlign.center,
                style: t.tituloPoema.copyWith(fontSize: 20, color: c.texto)),
            const SizedBox(height: 10),
            Text(l10n.favoritosVacioSubtitulo,
                textAlign: TextAlign.center,
                style: t.cuerpo.copyWith(fontSize: 14, color: c.oro)),
          ],
        ),
      ),
    );
  }
}

class _GrupoAutor extends StatelessWidget {
  final String autor;
  final List<Poema> poemas;

  const _GrupoAutor({super.key, required this.autor, required this.poemas});

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final t = context.tipos;

    return TarjetaPoemario(
      child: Column(
        children: [
          Material(
            color: c.sepia,
            child: InkWell(
              onTap: () => Navigator.of(context)
                  .push(rutaFundido((_) => AutorScreen(autor: autor))),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: EscalaLimitada(
                  maximo: 1.3,
                  child: Row(
                    children: [
                      AvatarAutor(autor: autor, tamano: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(autor,
                            style: t.autorTarjeta.copyWith(
                              fontSize: 16,
                              color: c.sobreSepia,
                              decoration: TextDecoration.underline,
                              decorationColor: c.oroClaro,
                            )),
                      ),
                      Icon(Icons.chevron_right, size: 18, color: c.oroClaro),
                    ],
                  ),
                ),
              ),
            ),
          ),
          for (var i = 0; i < poemas.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: c.oroClaro.withValues(alpha: 0.25),
              ),
            PoemaListTile(key: ValueKey(poemas[i].id), poema: poemas[i]),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
