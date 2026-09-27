// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class L10nFr extends L10n {
  L10nFr([String locale = 'fr']) : super(locale);

  @override
  String get tabInicio => 'Accueil';

  @override
  String get tabIndice => 'Index';

  @override
  String get tabBuscar => 'Recherche';

  @override
  String get tabFavoritos => 'Favoris';

  @override
  String get semTabInicio => 'Accueil, poèmes du jour';

  @override
  String get semTabIndice => 'Index des poètes';

  @override
  String get semTabBuscar => 'Rechercher des poèmes';

  @override
  String get semTabFavoritos => 'Mes poèmes favoris';

  @override
  String get indiceTitulo => 'Index';

  @override
  String get indiceSubtitulo => '— Index des poètes —';

  @override
  String get indiceBuscarPista => 'Rechercher un poète…';

  @override
  String indiceSinResultados(String consulta) {
    return 'Aucun poète ne correspond à « $consulta »';
  }

  @override
  String poemasContador(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n poèmes',
      one: '1 poème',
      zero: 'Aucun poème',
    );
    return '$_temp0';
  }

  @override
  String get inicioPoemasDelDia => 'Poèmes du jour';

  @override
  String get inicioTodosLosAutores => 'Tous les poètes';

  @override
  String inicioAutoresSeleccionados(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n poètes sélectionnés',
      one: '1 poète sélectionné',
      zero: 'Aucun poète sélectionné',
    );
    return '$_temp0';
  }

  @override
  String get inicioSinAutores => 'Aucun poète sélectionné';

  @override
  String get inicioConfigurarAutores => 'Choisir les poètes';

  @override
  String get inicioLeerCompleto => 'Lire le poème en entier';

  @override
  String get inicioFiltrarAutores => 'Filtrer les poètes du jour';

  @override
  String get buscarTitulo => 'Recherche';

  @override
  String get buscarPista => 'Titre, poète ou vers…';

  @override
  String get buscarPreparando => 'Préparation de la recherche…';

  @override
  String get buscarVacioTitulo => 'Tapez pour rechercher';

  @override
  String get buscarVacioSubtitulo => 'Par titre, poète ou n’importe quel vers';

  @override
  String buscarSinResultados(String consulta) {
    return 'Aucun résultat pour « $consulta »';
  }

  @override
  String get buscarBorrar => 'Effacer la recherche';

  @override
  String get favoritosTitulo => 'Favoris';

  @override
  String get favoritosVacioTitulo => 'Pas encore de favoris';

  @override
  String get favoritosVacioSubtitulo =>
      'Touchez le cœur en lisant un poème pour le garder ici.';

  @override
  String favoritosGuardados(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '— $n poèmes gardés —',
      one: '— 1 poème gardé —',
    );
    return '$_temp0';
  }

  @override
  String get favoritosAnadido => 'Ajouté aux favoris';

  @override
  String get favoritosEliminado => 'Retiré des favoris';

  @override
  String favoritosAnadir(String titulo) {
    return 'Ajouter aux favoris : $titulo';
  }

  @override
  String favoritosQuitar(String titulo) {
    return 'Retirer des favoris : $titulo';
  }

  @override
  String get favoritosGuardado => 'Dans les favoris';

  @override
  String get favoritosNoGuardado => 'Pas dans les favoris';

  @override
  String get ajustesTitulo => 'Réglages';

  @override
  String get ajustesApariencia => 'Apparence';

  @override
  String get ajustesTemaAuto => 'Automatique';

  @override
  String get ajustesTemaAutoSub => 'Suivre le réglage du système';

  @override
  String get ajustesTemaClaro => 'Clair';

  @override
  String get ajustesTemaClaroSub => 'Fond crème, texte foncé';

  @override
  String get ajustesTemaOscuro => 'Sombre';

  @override
  String get ajustesTemaOscuroSub => 'Fond sombre, plus reposant pour les yeux';

  @override
  String get ajustesPoemasDelDia => 'Poèmes du jour';

  @override
  String ajustesDeAutores(int activos, int total) {
    return '$activos poètes sur $total';
  }

  @override
  String get ajustesTodos => 'Tous';

  @override
  String get ajustesNinguno => 'Aucun';

  @override
  String get ajustesRecordatorio => 'Rappel quotidien';

  @override
  String get ajustesRecordatorioActivar => 'Me le rappeler chaque jour';

  @override
  String get ajustesRecordatorioSub =>
      'Une notification avec les poèmes du jour';

  @override
  String get ajustesRecordatorioHora => 'Heure du rappel';

  @override
  String get ajustesRecordatorioPermiso =>
      'Activez les notifications dans les réglages du système pour recevoir le rappel quotidien.';

  @override
  String get ajustesAbrirAjustesSistema => 'Ouvrir les réglages';

  @override
  String get notifTitulo => 'De nouveaux poèmes aujourd’hui';

  @override
  String notifLinea(String titulo, String autor, String verso) {
    return '$titulo — $autor : « $verso »';
  }

  @override
  String notifLineaSinTitulo(String verso, String autor) {
    return '« $verso » — $autor';
  }

  @override
  String get notifCuerpoGenerico => 'De nouveaux poèmes vous attendent';

  @override
  String get notifCanalNombre => 'Poème du jour';

  @override
  String get notifCanalDescripcion =>
      'Un rappel quotidien avec les poèmes choisis pour aujourd’hui';

  @override
  String compartirTitulo(String titulo) {
    return 'Partager : $titulo';
  }

  @override
  String get compartirError => 'Le partage a échoué';

  @override
  String semPoema(String titulo, String autor) {
    return 'Poème : $titulo, de $autor';
  }

  @override
  String get errorCargaTitulo => 'Impossible de charger l’anthologie';

  @override
  String get errorCargaSubtitulo =>
      'Rouvrez l’application. Si le problème persiste, réinstallez-la.';

  @override
  String get reintentar => 'Réessayer';

  @override
  String get propinasTitulo => 'Soutenir l’anthologie';

  @override
  String get propinasTexto =>
      'L’application est gratuite et sans publicité. Si elle vous plaît, vous pouvez nous offrir un café. C’est juste un merci : cela ne débloque rien.';

  @override
  String get propinasGracias => 'Merci de votre soutien !';

  @override
  String get propinasError =>
      'Le paiement n’a pas pu aboutir. Aucun montant n’a été débité.';
}
