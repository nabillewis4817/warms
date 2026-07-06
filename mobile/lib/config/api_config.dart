/// Centralise la configuration API.
///
/// L'URL de base est résolvable à trois niveaux (priorité décroissante) :
/// 1. `--dart-define=WARMS_API_BASE_URL=http://...` au build/run
/// 2. URL sauvegardée au runtime dans SecureStorage (configurée par l'utilisateur)
/// 3. Valeur par défaut (`http://127.0.0.1:8000/api/v1` — fonctionne en web local
///    et sur émulateur Android via 10.0.2.2 non ; sur device physique il faut
///    configurer l'IP depuis l'écran de connexion).
class ApiConfig {
  ApiConfig._();

  /// URL compilée via --dart-define (vide si non fournie).
  static const String _compiledUrl = String.fromEnvironment(
    'WARMS_API_BASE_URL',
    defaultValue: '',
  );

  static const String defaultUrl = 'http://127.0.0.1:8000/api/v1';

  /// URL active : overridée au runtime si l'utilisateur l'a configurée,
  /// sinon celle compilée, sinon la valeur par défaut.
  static String _runtimeUrl = '';

  static String get apiBaseUrl =>
      _runtimeUrl.isNotEmpty
          ? _runtimeUrl
          : _compiledUrl.isNotEmpty
              ? _compiledUrl
              : defaultUrl;

  /// Appelé par [ApiClient] au démarrage après avoir lu SecureStorage.
  static void setRuntimeUrl(String url) {
    _runtimeUrl = url.trimRight().replaceAll(RegExp(r'/$'), '');
  }

  static String get iaSharedBaseUrl => '$apiBaseUrl/ia-shared';
}
