import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/poema_repository.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/ajustes_provider.dart';
import '../providers/notificaciones_provider.dart';
import '../providers/tema_provider.dart';
import '../theme/poema_colors.dart';
import '../theme/poema_theme.dart';
import '../widgets/avatar_autor.dart';
import '../widgets/linea_oro.dart';

/// Appearance and the author filter.
///
/// Was `ajustes_inicio_screen.dart`. Structurally the same, with the nested
/// `shrinkWrap` list inside a `ListView` replaced by a single
/// [CustomScrollView]: the old version built every author row on every frame,
/// whether or not it was on screen.
///
/// The daily reminder lives here too: one switch and one time, deliberately
/// nothing more. Day-of-week rules would need a second selection UI and would
/// complicate the schedule for a feature most readers never touch.
class AjustesScreen extends StatelessWidget {
  const AjustesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final l10n = L10n.of(context);
    final autores = context.read<Anthology>().autores;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.ajustesTitulo,
            style: context.tipos.appBarTitulo.copyWith(color: c.sobreSepia)),
        bottom: const LineaOro(),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _Encabezado(l10n.ajustesApariencia)),
          const SliverToBoxAdapter(child: _SeccionTema()),
          SliverToBoxAdapter(child: _Encabezado(l10n.ajustesRecordatorio)),
          const SliverToBoxAdapter(child: _SeccionRecordatorio()),
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 16),
                _Encabezado(l10n.ajustesPoemasDelDia),
                const _BarraAcciones(),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            sliver: SliverList.separated(
              itemCount: autores.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 72,
                color: c.oroClaro.withValues(alpha: 0.3),
              ),
              itemBuilder: (context, i) => _FilaAutor(autor: autores[i]),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

class _Encabezado extends StatelessWidget {
  final String texto;
  const _Encabezado(this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Text(
        texto.toUpperCase(),
        style: context.tipos.cuerpoPequeno.copyWith(
          fontSize: 11,
          letterSpacing: 2,
          fontWeight: FontWeight.w700,
          color: context.colores.oro,
        ),
      ),
    );
  }
}

class _SeccionTema extends StatelessWidget {
  const _SeccionTema();

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final l10n = L10n.of(context);
    final tema = context.watch<TemaProvider>();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: c.tarjeta,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.oroClaro.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          for (final opcion in [
            (ThemeMode.system, l10n.ajustesTemaAuto, l10n.ajustesTemaAutoSub,
                Icons.brightness_auto),
            (ThemeMode.light, l10n.ajustesTemaClaro, l10n.ajustesTemaClaroSub,
                Icons.wb_sunny_outlined),
            (ThemeMode.dark, l10n.ajustesTemaOscuro, l10n.ajustesTemaOscuroSub,
                Icons.nightlight_outlined),
          ]) ...[
            if (opcion.$1 != ThemeMode.system)
              Divider(
                  height: 1,
                  indent: 56,
                  color: c.oroClaro.withValues(alpha: 0.3)),
            _OpcionTema(
              modo: opcion.$1,
              titulo: opcion.$2,
              subtitulo: opcion.$3,
              icono: opcion.$4,
              seleccionado: tema.modo == opcion.$1,
            ),
          ],
        ],
      ),
    );
  }
}

class _OpcionTema extends StatelessWidget {
  final ThemeMode modo;
  final String titulo;
  final String subtitulo;
  final IconData icono;
  final bool seleccionado;

  const _OpcionTema({
    required this.modo,
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    required this.seleccionado,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final apagado = Theme.of(context).disabledColor;

    return ListTile(
      onTap: () => context.read<TemaProvider>().establecer(modo),
      // Announced as a radio group rather than three unrelated rows.
      selected: seleccionado,
      leading: Icon(icono, color: seleccionado ? c.oro : apagado),
      title: Text(titulo,
          style: context.tipos.cuerpo.copyWith(
            color: seleccionado ? c.texto : apagado,
            fontWeight: seleccionado ? FontWeight.w600 : FontWeight.normal,
          )),
      subtitle: Text(subtitulo,
          style: context.tipos.cuerpoPequeno.copyWith(color: c.textoSuave)),
      trailing: Icon(
        seleccionado ? Icons.check_circle : Icons.radio_button_unchecked,
        color: seleccionado ? c.oro : apagado,
        size: 22,
      ),
    );
  }
}

class _BarraAcciones extends StatelessWidget {
  const _BarraAcciones();

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final l10n = L10n.of(context);
    final ajustes = context.watch<AjustesProvider>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.ajustesDeAutores(
                  ajustes.totalActivos, ajustes.todosLosAutores.length),
              style: context.tipos.cuerpoPequeno
                  .copyWith(fontSize: 13, color: c.oro, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed:
                ajustes.todosSeleccionados ? null : ajustes.seleccionarTodos,
            child: Text(l10n.ajustesTodos),
          ),
          TextButton(
            onPressed:
                ajustes.ningunoSeleccionado ? null : ajustes.deseleccionarTodos,
            child: Text(l10n.ajustesNinguno),
          ),
        ],
      ),
    );
  }
}

class _FilaAutor extends StatelessWidget {
  final String autor;
  const _FilaAutor({required this.autor});

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    // Only this row rebuilds when its own switch is flipped.
    final activo = context.select<AjustesProvider, bool>(
      (a) => a.estaActivo(autor),
    );

    return ListTile(
      onTap: () => context.read<AjustesProvider>().alternarAutor(autor),
      leading: AvatarAutor(autor: autor, tamano: 40, apagado: !activo),
      title: Text(
        autor,
        style: context.tipos.autorTarjeta.copyWith(
          fontSize: 15,
          color: activo ? c.texto : Theme.of(context).disabledColor,
        ),
      ),
      trailing: ExcludeSemantics(
        child: Switch(
          value: activo,
          onChanged: (_) => context.read<AjustesProvider>().alternarAutor(autor),
        ),
      ),
    );
  }
}


/// Daily reminder: on/off and the hour.
class _SeccionRecordatorio extends StatelessWidget {
  const _SeccionRecordatorio();

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final t = context.tipos;
    final l10n = L10n.of(context);
    final avisos = context.watch<NotificacionesProvider>();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: c.tarjeta,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.oroClaro.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          SwitchListTile(
            value: avisos.activo,
            onChanged: (quiere) => quiere
                ? context.read<NotificacionesProvider>().activar()
                : context.read<NotificacionesProvider>().desactivar(),
            secondary: Icon(Icons.notifications_none,
                color: avisos.activo ? c.oro : Theme.of(context).disabledColor),
            title: Text(l10n.ajustesRecordatorioActivar,
                style: t.cuerpo.copyWith(color: c.texto)),
            subtitle: Text(l10n.ajustesRecordatorioSub,
                style: t.cuerpoPequeno.copyWith(color: c.textoSuave)),
          ),
          // Only shown when reminders are on: an hour picker above a switch
          // that is off invites the reader to set something that never fires.
          if (avisos.activo) ...[
            Divider(
                height: 1,
                indent: 56,
                color: c.oroClaro.withValues(alpha: 0.3)),
            ListTile(
              leading: Icon(Icons.schedule, color: c.oro),
              title: Text(l10n.ajustesRecordatorioHora,
                  style: t.cuerpo.copyWith(color: c.texto)),
              trailing: Text(
                // Formatted by MaterialLocalizations, so it follows the
                // locale's 12/24-hour convention and the device setting.
                MaterialLocalizations.of(context).formatTimeOfDay(
                  avisos.hora,
                  alwaysUse24HourFormat:
                      MediaQuery.alwaysUse24HourFormatOf(context),
                ),
                style: t.cuerpo
                    .copyWith(color: c.oro, fontWeight: FontWeight.w600),
              ),
              onTap: () async {
                final elegida = await showTimePicker(
                  context: context,
                  initialTime: avisos.hora,
                );
                if (elegida != null && context.mounted) {
                  await context
                      .read<NotificacionesProvider>()
                      .establecerHora(elegida);
                }
              },
            ),
          ],
          // Permission can be revoked in system settings long after the switch
          // was turned on, which would otherwise leave the UI lying.
          if (avisos.permisoDenegado)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 18, color: c.oro),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(l10n.ajustesRecordatorioPermiso,
                        style: t.cuerpoPequeno.copyWith(color: c.textoSuave)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
