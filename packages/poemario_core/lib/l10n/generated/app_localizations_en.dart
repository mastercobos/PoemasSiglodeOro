// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class L10nEn extends L10n {
  L10nEn([String locale = 'en']) : super(locale);

  @override
  String get tabInicio => 'Today';

  @override
  String get tabIndice => 'Index';

  @override
  String get tabBuscar => 'Search';

  @override
  String get tabFavoritos => 'Saved';

  @override
  String get semTabInicio => 'Today\'s poems';

  @override
  String get semTabIndice => 'Index of poets';

  @override
  String get semTabBuscar => 'Search poems';

  @override
  String get semTabFavoritos => 'My saved poems';

  @override
  String get indiceTitulo => 'Index';

  @override
  String get indiceSubtitulo => '— Index of Poets —';

  @override
  String poemasContador(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n poems',
      one: '1 poem',
      zero: 'No poems',
    );
    return '$_temp0';
  }

  @override
  String get inicioPoemasDelDia => 'Poems of the day';

  @override
  String get inicioTodosLosAutores => 'All poets';

  @override
  String inicioAutoresSeleccionados(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n poets selected',
      one: '1 poet selected',
      zero: 'No poets selected',
    );
    return '$_temp0';
  }

  @override
  String get inicioSinAutores => 'No poets selected';

  @override
  String get inicioConfigurarAutores => 'Choose poets';

  @override
  String get inicioLeerCompleto => 'Read the full poem';

  @override
  String get inicioFiltrarAutores => 'Filter today\'s poets';

  @override
  String get buscarTitulo => 'Search';

  @override
  String get buscarPista => 'Search by title, poet or line…';

  @override
  String get buscarVacioTitulo => 'Type to search';

  @override
  String get buscarVacioSubtitulo => 'Search by title, poet or any line';

  @override
  String buscarSinResultados(String consulta) {
    return 'No results for “$consulta”';
  }

  @override
  String get buscarBorrar => 'Clear search';

  @override
  String get favoritosTitulo => 'Saved';

  @override
  String get favoritosVacioTitulo => 'Nothing saved yet';

  @override
  String get favoritosVacioSubtitulo =>
      'Tap the heart while reading a poem to keep it here.';

  @override
  String favoritosGuardados(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '— $n poems saved —',
      one: '— 1 poem saved —',
    );
    return '$_temp0';
  }

  @override
  String get favoritosAnadido => 'Saved';

  @override
  String get favoritosEliminado => 'Removed from saved';

  @override
  String favoritosAnadir(String titulo) {
    return 'Save $titulo';
  }

  @override
  String favoritosQuitar(String titulo) {
    return 'Remove $titulo from saved';
  }

  @override
  String get favoritosGuardado => 'Saved';

  @override
  String get favoritosNoGuardado => 'Not saved';

  @override
  String get ajustesTitulo => 'Settings';

  @override
  String get ajustesApariencia => 'Appearance';

  @override
  String get ajustesTemaAuto => 'Automatic';

  @override
  String get ajustesTemaAutoSub => 'Follow the system setting';

  @override
  String get ajustesTemaClaro => 'Light';

  @override
  String get ajustesTemaClaroSub => 'Cream background, dark text';

  @override
  String get ajustesTemaOscuro => 'Dark';

  @override
  String get ajustesTemaOscuroSub => 'Dark background, easier on the eyes';

  @override
  String get ajustesPoemasDelDia => 'Poems of the day';

  @override
  String ajustesDeAutores(int activos, int total) {
    return '$activos of $total poets';
  }

  @override
  String get ajustesTodos => 'All';

  @override
  String get ajustesNinguno => 'None';

  @override
  String get ajustesRecordatorio => 'Daily reminder';

  @override
  String get ajustesRecordatorioActivar => 'Remind me every day';

  @override
  String get ajustesRecordatorioSub =>
      'A notification with the poems of the day';

  @override
  String get ajustesRecordatorioHora => 'Reminder time';

  @override
  String get ajustesRecordatorioPermiso =>
      'Turn on notifications in system settings to get the daily reminder.';

  @override
  String get ajustesAbrirAjustesSistema => 'Open settings';

  @override
  String get notifTitulo => 'Poem of the day';

  @override
  String notifCuerpo(String titulo, String autor) {
    return '$titulo — $autor';
  }

  @override
  String get notifCuerpoGenerico => 'New poems are waiting for you';

  @override
  String get notifCanalNombre => 'Poem of the day';

  @override
  String get notifCanalDescripcion =>
      'A daily reminder with the poems chosen for today';

  @override
  String compartirTitulo(String titulo) {
    return 'Share: $titulo';
  }

  @override
  String get compartirError => 'Couldn\'t share';

  @override
  String semPoema(String titulo, String autor) {
    return 'Poem: $titulo, by $autor';
  }

  @override
  String get errorCargaTitulo => 'Couldn\'t load the anthology';

  @override
  String get errorCargaSubtitulo =>
      'Please reopen the app. If it keeps happening, reinstall it.';

  @override
  String get reintentar => 'Try again';

  @override
  String get propinasTitulo => 'Support the anthology';

  @override
  String get propinasTexto =>
      'The app is free and has no ads. If you enjoy it, you can buy us a coffee. It\'s just a thank-you: it doesn\'t unlock anything.';

  @override
  String get propinasGracias => 'Thank you for your support!';

  @override
  String get propinasError =>
      'The payment couldn\'t be completed. You have not been charged.';
}
