/// Centralise la configuration API.
///
/// Surchargable via:
/// `flutter run --dart-define=WARMS_API_BASE_URL=http://<host>:8000/api/v1`
class ApiConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'WARMS_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000/api/v1',
  );

  static String get iaSharedBaseUrl => '$apiBaseUrl/ia-shared';
}

