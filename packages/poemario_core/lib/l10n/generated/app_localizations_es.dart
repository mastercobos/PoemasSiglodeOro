// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class L10nEs extends L10n {
  L10nEs([String locale = 'es']) : super(locale);

  @override
  String get tabInicio => 'Inicio';

  @override
  String get tabIndice => 'Índice';

  @override
  String get tabBuscar => 'Buscar';

  @override
  String get tabFavoritos => 'Favoritos';

  @override
  String get semTabInicio => 'Inicio, poemas del día';

  @override
  String get semTabIndice => 'Índice de autores';

  @override
  String get semTabBuscar => 'Buscar poemas';

  @override
  String get semTabFavoritos => 'Mis poemas favoritos';

  @override
  String get indiceTitulo => 'Índice';

  @override
  String get indiceSubtitulo => '— Índice de Autores —';

  @override
  String get indiceBuscarPista => 'Buscar autor…';

  @override
  String indiceSinResultados(String consulta) {
    return 'Ningún autor coincide con «$consulta»';
  }

  @override
  String poemasContador(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n poemas',
      one: '1 poema',
      zero: 'Sin poemas',
    );
    return '$_temp0';
  }

  @override
  String get inicioPoemasDelDia => 'Poemas del día';

  @override
  String get inicioTodosLosAutores => 'Todos los autores';

  @override
  String inicioAutoresSeleccionados(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n autores seleccionados',
      one: '1 autor seleccionado',
      zero: 'Ningún autor seleccionado',
    );
    return '$_temp0';
  }

  @override
  String get inicioSinAutores => 'Ningún autor seleccionado';

  @override
  String get inicioConfigurarAutores => 'Configurar autores';

  @override
  String get inicioLeerCompleto => 'Leer poema completo';

  @override
  String get inicioFiltrarAutores => 'Filtrar autores del día';

  @override
  String get buscarTitulo => 'Buscar';

  @override
  String get buscarPista => 'Buscar por título, autor o verso…';

  @override
  String get buscarVacioTitulo => 'Escribe para buscar';

  @override
  String get buscarVacioSubtitulo =>
      'Busca por título, autor o cualquier verso';

  @override
  String buscarSinResultados(String consulta) {
    return 'Sin resultados para «$consulta»';
  }

  @override
  String get buscarBorrar => 'Borrar búsqueda';

  @override
  String get favoritosTitulo => 'Favoritos';

  @override
  String get favoritosVacioTitulo => 'Aún no tienes favoritos';

  @override
  String get favoritosVacioSubtitulo =>
      'Pulsa el corazón al leer un poema para guardarlo aquí.';

  @override
  String favoritosGuardados(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '— $n poemas guardados —',
      one: '— 1 poema guardado —',
    );
    return '$_temp0';
  }

  @override
  String get favoritosAnadido => 'Añadido a favoritos';

  @override
  String get favoritosEliminado => 'Eliminado de favoritos';

  @override
  String favoritosAnadir(String titulo) {
    return 'Añadir a favoritos: $titulo';
  }

  @override
  String favoritosQuitar(String titulo) {
    return 'Quitar de favoritos: $titulo';
  }

  @override
  String get favoritosGuardado => 'Guardado en favoritos';

  @override
  String get favoritosNoGuardado => 'No guardado en favoritos';

  @override
  String get ajustesTitulo => 'Ajustes';

  @override
  String get ajustesApariencia => 'Apariencia';

  @override
  String get ajustesTemaAuto => 'Automático';

  @override
  String get ajustesTemaAutoSub => 'Sigue la configuración del sistema';

  @override
  String get ajustesTemaClaro => 'Claro';

  @override
  String get ajustesTemaClaroSub => 'Fondo crema, texto oscuro';

  @override
  String get ajustesTemaOscuro => 'Oscuro';

  @override
  String get ajustesTemaOscuroSub => 'Fondo negro, menos fatiga ocular';

  @override
  String get ajustesPoemasDelDia => 'Poemas del día';

  @override
  String ajustesDeAutores(int activos, int total) {
    return '$activos de $total autores';
  }

  @override
  String get ajustesTodos => 'Todos';

  @override
  String get ajustesNinguno => 'Ninguno';

  @override
  String get ajustesRecordatorio => 'Recordatorio diario';

  @override
  String get ajustesRecordatorioActivar => 'Avisarme cada día';

  @override
  String get ajustesRecordatorioSub => 'Un aviso con los poemas del día';

  @override
  String get ajustesRecordatorioHora => 'Hora del aviso';

  @override
  String get ajustesRecordatorioPermiso =>
      'Activa las notificaciones en los ajustes del sistema para recibir el aviso diario.';

  @override
  String get ajustesAbrirAjustesSistema => 'Abrir ajustes';

  @override
  String get notifTitulo => 'Poema del día';

  @override
  String notifCuerpo(String titulo, String autor) {
    return '$titulo — $autor';
  }

  @override
  String get notifCuerpoGenerico => 'Hay poemas nuevos esperándote';

  @override
  String get notifCanalNombre => 'Poema del día';

  @override
  String get notifCanalDescripcion =>
      'Un recordatorio diario con los poemas seleccionados para hoy';

  @override
  String compartirTitulo(String titulo) {
    return 'Compartir: $titulo';
  }

  @override
  String get compartirError => 'No se pudo compartir';

  @override
  String semPoema(String titulo, String autor) {
    return 'Poema: $titulo, de $autor';
  }

  @override
  String get errorCargaTitulo => 'No se pudo cargar la antología';

  @override
  String get errorCargaSubtitulo =>
      'Vuelve a abrir la aplicación. Si el problema continúa, reinstálala.';

  @override
  String get reintentar => 'Reintentar';

  @override
  String get propinasTitulo => 'Apoya la antología';

  @override
  String get propinasTexto =>
      'La aplicación es gratuita y no tiene anuncios. Si te gusta, puedes invitarnos a un café. Es solo un gesto de agradecimiento: no desbloquea nada.';

  @override
  String get propinasGracias => '¡Gracias por tu apoyo!';

  @override
  String get propinasError =>
      'No se pudo completar el pago. No se ha hecho ningún cargo.';
}
