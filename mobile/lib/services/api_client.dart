import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import 'secure_storage_service.dart';

/// Client HTTP unique de l'application, partagé par tous les services.
///
/// Centralise :
/// - la configuration de base (URL de l'API) ;
/// - l'en-tête `Authorization` une fois connecté ;
/// - le rafraîchissement automatique du token JWT sur une réponse 401
///   (le tout sans jamais dupliquer cette logique dans chaque écran).
class ApiClient {
  ApiClient._() {
    _dio.interceptors.add(
      InterceptorsWrapper(onError: _gererErreur401),
    );
  }

  static final ApiClient instance = ApiClient._();

  final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConfig.apiBaseUrl,
    // Sans timeout explicite, Dio attend indéfiniment : une requête qui
    // ne reçoit jamais de réponse (backend lent, réseau coupé en cours
    // de route) bloque alors silencieusement l'écran appelant pour
    // toujours, sans erreur ni log — exactement le symptôme observé sur
    // l'écran de démarrage après la connexion patient.
    connectTimeout: const Duration(seconds: 12),
    receiveTimeout: const Duration(seconds: 12),
  ));
  final _storage = SecureStorageService.instance;

  Dio get dio => _dio;

  void definirToken(String? access) {
    if (access == null || access.isEmpty) {
      _dio.options.headers.remove('Authorization');
    } else {
      _dio.options.headers['Authorization'] = 'Bearer $access';
    }
  }

  Future<void> _gererErreur401(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final status = error.response?.statusCode;
    final dejaRetente = error.requestOptions.extra['retry401'] == true;
    if (status != 401 || dejaRetente) {
      return handler.next(error);
    }

    final nouveauAccess = await rafraichirAccessToken();
    if (nouveauAccess == null) {
      return handler.next(error);
    }

    final opts = error.requestOptions;
    opts.headers['Authorization'] = 'Bearer $nouveauAccess';
    opts.extra['retry401'] = true;
    try {
      final reponse = await _dio.fetch(opts);
      return handler.resolve(reponse);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }

  /// Échange le refresh token contre un nouvel access token.
  ///
  /// Retourne `null` si aucun refresh token n'est disponible ou si le
  /// backend le rejette (session expirée) ; dans ce cas l'appelant doit
  /// déconnecter l'utilisateur.
  Future<String?> rafraichirAccessToken() async {
    try {
      final refresh = await _storage.lireRefreshToken();
      if (refresh == null || refresh.isEmpty) return null;

      final rep = await _dio.post(
        '/personnel/auth/token/refresh/',
        data: {'refresh': refresh},
      );
      final access = rep.data['access'] as String?;
      if (access != null) {
        await _storage.mettreAJourAccessToken(access);
        definirToken(access);
      }
      return access;
    } catch (e) {
      if (kDebugMode) debugPrint('WARMS: échec du rafraîchissement de token: $e');
      return null;
    }
  }
}
