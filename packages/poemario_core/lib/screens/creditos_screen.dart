import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/poema_colors.dart';
import '../theme/poema_theme.dart';
import '../utils/navegacion.dart';
import '../widgets/linea_oro.dart';

/// Where the texts come from: [AppConfig.creditos], one card per source.
///
/// Lives in the app rather than only on the store page because CC BY-SA asks
/// for the credit to accompany the material, and the material is the app.
class CreditosScreen extends StatelessWidget {
  const CreditosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final t = context.tipos;
    final l10n = L10n.of(context);
    final creditos = context.config.creditos;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.creditosTitulo,
            style: t.appBarTitulo.copyWith(color: c.sobreSepia)),
        bottom: const LineaOro(),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(14, 18, 14, espacioBarraFlotante(context)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 12),
            child: Text(l10n.creditosIntro,
                style: t.cuerpoPequeno.copyWith(color: c.textoSuave)),
          ),
          for (final credito in creditos) _TarjetaCredito(credito: credito),
        ],
      ),
    );
  }
}

class _TarjetaCredito extends StatelessWidget {
  final CreditoFuente credito;
  const _TarjetaCredito({required this.credito});

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final t = context.tipos;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.tarjeta,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.oroClaro.withValues(alpha: 0.6)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(credito.nombre,
                  style: t.tituloTarjeta.copyWith(color: c.texto)),
              const SizedBox(height: 6),
              Text(credito.descripcion,
                  style: t.cuerpoPequeno.copyWith(color: c.texto)),
              if (credito.enlace != null) ...[
                const SizedBox(height: 8),
                SelectableText(credito.enlace!,
                    style: t.cuerpoPequeno
                        .copyWith(color: c.oro, fontWeight: FontWeight.w600)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
