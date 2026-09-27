import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L10n
/// returned by `L10n.of(context)`.
///
/// Applications need to include `L10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L10n.localizationsDelegates,
///   supportedLocales: L10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the L10n.supportedLocales
/// property.
abstract class L10n {
  L10n(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L10n of(BuildContext context) {
    return Localizations.of<L10n>(context, L10n)!;
  }

  static const LocalizationsDelegate<L10n> delegate = _L10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('fr')
  ];

  /// No description provided for @tabInicio.
  ///
  /// In es, this message translates to:
  /// **'Inicio'**
  String get tabInicio;

  /// No description provided for @tabIndice.
  ///
  /// In es, this message translates to:
  /// **'Índice'**
  String get tabIndice;

  /// No description provided for @tabBuscar.
  ///
  /// In es, this message translates to:
  /// **'Buscar'**
  String get tabBuscar;

  /// No description provided for @tabFavoritos.
  ///
  /// In es, this message translates to:
  /// **'Favoritos'**
  String get tabFavoritos;

  /// No description provided for @semTabInicio.
  ///
  /// In es, this message translates to:
  /// **'Inicio, poemas del día'**
  String get semTabInicio;

  /// No description provided for @semTabIndice.
  ///
  /// In es, this message translates to:
  /// **'Índice de autores'**
  String get semTabIndice;

  /// No description provided for @semTabBuscar.
  ///
  /// In es, this message translates to:
  /// **'Buscar poemas'**
  String get semTabBuscar;

  /// No description provided for @semTabFavoritos.
  ///
  /// In es, this message translates to:
  /// **'Mis poemas favoritos'**
  String get semTabFavoritos;

  /// No description provided for @indiceTitulo.
  ///
  /// In es, this message translates to:
  /// **'Índice'**
  String get indiceTitulo;

  /// No description provided for @indiceSubtitulo.
  ///
  /// In es, this message translates to:
  /// **'— Índice de Autores —'**
  String get indiceSubtitulo;

  /// No description provided for @indiceBuscarPista.
  ///
  /// In es, this message translates to:
  /// **'Buscar autor…'**
  String get indiceBuscarPista;

  /// No description provided for @indiceSinResultados.
  ///
  /// In es, this message translates to:
  /// **'Ningún autor coincide con «{consulta}»'**
  String indiceSinResultados(String consulta);

  /// Poem count under an author's name.
  ///
  /// In es, this message translates to:
  /// **'{n, plural, =0{Sin poemas} =1{1 poema} other{{n} poemas}}'**
  String poemasContador(int n);

  /// No description provided for @inicioPoemasDelDia.
  ///
  /// In es, this message translates to:
  /// **'Poemas del día'**
  String get inicioPoemasDelDia;

  /// No description provided for @inicioTodosLosAutores.
  ///
  /// In es, this message translates to:
  /// **'Todos los autores'**
  String get inicioTodosLosAutores;

  /// No description provided for @inicioAutoresSeleccionados.
  ///
  /// In es, this message translates to:
  /// **'{n, plural, =0{Ningún autor seleccionado} =1{1 autor seleccionado} other{{n} autores seleccionados}}'**
  String inicioAutoresSeleccionados(int n);

  /// No description provided for @inicioSinAutores.
  ///
  /// In es, this message translates to:
  /// **'Ningún autor seleccionado'**
  String get inicioSinAutores;

  /// No description provided for @inicioConfigurarAutores.
  ///
  /// In es, this message translates to:
  /// **'Configurar autores'**
  String get inicioConfigurarAutores;

  /// No description provided for @inicioLeerCompleto.
  ///
  /// In es, this message translates to:
  /// **'Leer poema completo'**
  String get inicioLeerCompleto;

  /// No description provided for @inicioFiltrarAutores.
  ///
  /// In es, this message translates to:
  /// **'Filtrar autores del día'**
  String get inicioFiltrarAutores;

  /// No description provided for @buscarTitulo.
  ///
  /// In es, this message translates to:
  /// **'Buscar'**
  String get buscarTitulo;

  /// No description provided for @buscarPista.
  ///
  /// In es, this message translates to:
  /// **'Buscar por título, autor o verso…'**
  String get buscarPista;

  /// No description provided for @buscarPreparando.
  ///
  /// In es, this message translates to:
  /// **'Preparando la búsqueda…'**
  String get buscarPreparando;

  /// No description provided for @buscarVacioTitulo.
  ///
  /// In es, this message translates to:
  /// **'Escribe para buscar'**
  String get buscarVacioTitulo;

  /// No description provided for @buscarVacioSubtitulo.
  ///
  /// In es, this message translates to:
  /// **'Busca por título, autor o cualquier verso'**
  String get buscarVacioSubtitulo;

  /// No description provided for @buscarSinResultados.
  ///
  /// In es, this message translates to:
  /// **'Sin resultados para «{consulta}»'**
  String buscarSinResultados(String consulta);

  /// No description provided for @buscarBorrar.
  ///
  /// In es, this message translates to:
  /// **'Borrar búsqueda'**
  String get buscarBorrar;

  /// No description provided for @favoritosTitulo.
  ///
  /// In es, this message translates to:
  /// **'Favoritos'**
  String get favoritosTitulo;

  /// No description provided for @favoritosVacioTitulo.
  ///
  /// In es, this message translates to:
  /// **'Aún no tienes favoritos'**
  String get favoritosVacioTitulo;

  /// No description provided for @favoritosVacioSubtitulo.
  ///
  /// In es, this message translates to:
  /// **'Pulsa el corazón al leer un poema para guardarlo aquí.'**
  String get favoritosVacioSubtitulo;

  /// No description provided for @favoritosGuardados.
  ///
  /// In es, this message translates to:
  /// **'{n, plural, =1{— 1 poema guardado —} other{— {n} poemas guardados —}}'**
  String favoritosGuardados(int n);

  /// No description provided for @favoritosAnadido.
  ///
  /// In es, this message translates to:
  /// **'Añadido a favoritos'**
  String get favoritosAnadido;

  /// No description provided for @favoritosEliminado.
  ///
  /// In es, this message translates to:
  /// **'Eliminado de favoritos'**
  String get favoritosEliminado;

  /// No description provided for @favoritosAnadir.
  ///
  /// In es, this message translates to:
  /// **'Añadir a favoritos: {titulo}'**
  String favoritosAnadir(String titulo);

  /// No description provided for @favoritosQuitar.
  ///
  /// In es, this message translates to:
  /// **'Quitar de favoritos: {titulo}'**
  String favoritosQuitar(String titulo);

  /// No description provided for @favoritosGuardado.
  ///
  /// In es, this message translates to:
  /// **'Guardado en favoritos'**
  String get favoritosGuardado;

  /// No description provided for @favoritosNoGuardado.
  ///
  /// In es, this message translates to:
  /// **'No guardado en favoritos'**
  String get favoritosNoGuardado;

  /// No description provided for @ajustesTitulo.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get ajustesTitulo;

  /// No description provided for @ajustesApariencia.
  ///
  /// In es, this message translates to:
  /// **'Apariencia'**
  String get ajustesApariencia;

  /// No description provided for @ajustesTemaAuto.
  ///
  /// In es, this message translates to:
  /// **'Automático'**
  String get ajustesTemaAuto;

  /// No description provided for @ajustesTemaAutoSub.
  ///
  /// In es, this message translates to:
  /// **'Sigue la configuración del sistema'**
  String get ajustesTemaAutoSub;

  /// No description provided for @ajustesTemaClaro.
  ///
  /// In es, this message translates to:
  /// **'Claro'**
  String get ajustesTemaClaro;

  /// No description provided for @ajustesTemaClaroSub.
  ///
  /// In es, this message translates to:
  /// **'Fondo crema, texto oscuro'**
  String get ajustesTemaClaroSub;

  /// No description provided for @ajustesTemaOscuro.
  ///
  /// In es, this message translates to:
  /// **'Oscuro'**
  String get ajustesTemaOscuro;

  /// No description provided for @ajustesTemaOscuroSub.
  ///
  /// In es, this message translates to:
  /// **'Fondo negro, menos fatiga ocular'**
  String get ajustesTemaOscuroSub;

  /// No description provided for @ajustesPoemasDelDia.
  ///
  /// In es, this message translates to:
  /// **'Poemas del día'**
  String get ajustesPoemasDelDia;

  /// No description provided for @ajustesDeAutores.
  ///
  /// In es, this message translates to:
  /// **'{activos} de {total} autores'**
  String ajustesDeAutores(int activos, int total);

  /// No description provided for @ajustesTodos.
  ///
  /// In es, this message translates to:
  /// **'Todos'**
  String get ajustesTodos;

  /// No description provided for @ajustesNinguno.
  ///
  /// In es, this message translates to:
  /// **'Ninguno'**
  String get ajustesNinguno;

  /// No description provided for @ajustesRecordatorio.
  ///
  /// In es, this message translates to:
  /// **'Recordatorio diario'**
  String get ajustesRecordatorio;

  /// No description provided for @ajustesRecordatorioActivar.
  ///
  /// In es, this message translates to:
  /// **'Avisarme cada día'**
  String get ajustesRecordatorioActivar;

  /// No description provided for @ajustesRecordatorioSub.
  ///
  /// In es, this message translates to:
  /// **'Un aviso con los poemas del día'**
  String get ajustesRecordatorioSub;

  /// No description provided for @ajustesRecordatorioHora.
  ///
  /// In es, this message translates to:
  /// **'Hora del aviso'**
  String get ajustesRecordatorioHora;

  /// No description provided for @ajustesRecordatorioPermiso.
  ///
  /// In es, this message translates to:
  /// **'Activa las notificaciones en los ajustes del sistema para recibir el aviso diario.'**
  String get ajustesRecordatorioPermiso;

  /// No description provided for @ajustesAbrirAjustesSistema.
  ///
  /// In es, this message translates to:
  /// **'Abrir ajustes'**
  String get ajustesAbrirAjustesSistema;

  /// No description provided for @notifTitulo.
  ///
  /// In es, this message translates to:
  /// **'Hoy hay poemas nuevos'**
  String get notifTitulo;

  /// No description provided for @notifLinea.
  ///
  /// In es, this message translates to:
  /// **'{titulo} — {autor}: «{verso}»'**
  String notifLinea(String titulo, String autor, String verso);

  /// No description provided for @notifLineaSinTitulo.
  ///
  /// In es, this message translates to:
  /// **'«{verso}» — {autor}'**
  String notifLineaSinTitulo(String verso, String autor);

  /// No description provided for @notifCuerpoGenerico.
  ///
  /// In es, this message translates to:
  /// **'Hay poemas nuevos esperándote'**
  String get notifCuerpoGenerico;

  /// No description provided for @notifCanalNombre.
  ///
  /// In es, this message translates to:
  /// **'Poema del día'**
  String get notifCanalNombre;

  /// No description provided for @notifCanalDescripcion.
  ///
  /// In es, this message translates to:
  /// **'Un recordatorio diario con los poemas seleccionados para hoy'**
  String get notifCanalDescripcion;

  /// No description provided for @compartirTitulo.
  ///
  /// In es, this message translates to:
  /// **'Compartir: {titulo}'**
  String compartirTitulo(String titulo);

  /// No description provided for @compartirError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo compartir'**
  String get compartirError;

  /// No description provided for @semPoema.
  ///
  /// In es, this message translates to:
  /// **'Poema: {titulo}, de {autor}'**
  String semPoema(String titulo, String autor);

  /// No description provided for @errorCargaTitulo.
  ///
  /// In es, this message translates to:
  /// **'No se pudo cargar la antología'**
  String get errorCargaTitulo;

  /// No description provided for @errorCargaSubtitulo.
  ///
  /// In es, this message translates to:
  /// **'Vuelve a abrir la aplicación. Si el problema continúa, reinstálala.'**
  String get errorCargaSubtitulo;

  /// No description provided for @reintentar.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get reintentar;

  /// No description provided for @propinasTitulo.
  ///
  /// In es, this message translates to:
  /// **'Apoya la antología'**
  String get propinasTitulo;

  /// No description provided for @propinasTexto.
  ///
  /// In es, this message translates to:
  /// **'La aplicación es gratuita y no tiene anuncios. Si te gusta, puedes invitarnos a un café. Es solo un gesto de agradecimiento: no desbloquea nada.'**
  String get propinasTexto;

  /// No description provided for @propinasGracias.
  ///
  /// In es, this message translates to:
  /// **'¡Gracias por tu apoyo!'**
  String get propinasGracias;

  /// No description provided for @propinasError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo completar el pago. No se ha hecho ningún cargo.'**
  String get propinasError;
}

class _L10nDelegate extends LocalizationsDelegate<L10n> {
  const _L10nDelegate();

  @override
  Future<L10n> load(Locale locale) {
    return SynchronousFuture<L10n>(lookupL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_L10nDelegate old) => false;
}

L10n lookupL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return L10nEn();
    case 'es':
      return L10nEs();
    case 'fr':
      return L10nFr();
  }

  throw FlutterError(
      'L10n.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
