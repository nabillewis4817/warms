import 'package:dio/dio.dart';

import 'api_client.dart';
import 'notification_service.dart';
import 'secure_storage_service.dart';

/// Erreur d'authentification avec un message déjà traduit, prêt à afficher
/// directement à l'utilisateur (voir [AuthService._messageDepuisErreurDio]).
class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

/// Gère le cycle de vie de la session : connexion, restauration au
/// démarrage, déconnexion. Ne connaît rien du profil métier (voir
/// [ProfilService]) : sa seule responsabilité est le token JWT.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final _api = ApiClient.instance;
  final _storage = SecureStorageService.instance;

  /// Tente de restaurer une session existante à partir du token stocké.
  ///
  /// Retourne `true` si un access token valide (ou rafraîchissable) est
  /// disponible. Si le refresh échoue (session expirée), nettoie le
  /// stockage et retourne `false`.
  Future<bool> restaurerSession() async {
    final token = await _storage.lireAccessToken();
    if (token == null || token.isEmpty) return false;

    _api.definirToken(token);
    final access = await _api.rafraichirAccessToken();
    if (access == null) {
      await deconnexion();
      return false;
    }
    try {
      NotificationService().envoyerTokenAuServeur();
    } catch (_) {}
    return true;
  }

  /// Authentifie l'utilisateur avec son couple identifiant/mot de passe.
  ///
  /// Lance une [AuthException] avec un message lisible en cas d'échec.
  Future<void> connexion(String username, String password) async {
    try {
      final rep = await _api.dio.post('/personnel/auth/token/', data: {
        'username': username,
        'password': password,
      });

      final access = rep.data['access'] as String?;
      final refresh = rep.data['refresh'] as String?;
      if (access == null || access.isEmpty) {
        throw AuthException('Token d\'accès invalide reçu du serveur.');
      }

      await _storage.enregistrerTokens(access: access, refresh: refresh);
      _api.definirToken(access);
      try {
        NotificationService().envoyerTokenAuServeur();
      } catch (_) {}
    } on DioException catch (e) {
      throw AuthException(_messageDepuisErreurDio(e));
    }
  }

  Future<void> deconnexion() async {
    await _storage.supprimerTokens();
    _api.definirToken(null);
  }

  String _messageDepuisErreurDio(DioException e) {
    if (e.response?.statusCode == 401) {
      return 'Identifiants incorrects. Vérifiez votre nom d\'utilisateur et votre mot de passe.';
    }
    if (e.response?.statusCode == 404) {
      return 'Service d\'authentification indisponible.';
    }
    if (e.type == DioExceptionType.connectionTimeout) {
      return 'Délai de connexion dépassé. Vérifiez votre connexion.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'Impossible de se connecter au serveur. Vérifiez que le backend est démarré.';
    }
    return 'Échec de connexion.';
  }
}
