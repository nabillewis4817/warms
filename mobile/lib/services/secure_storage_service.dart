import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Accès centralisé au stockage sécurisé (tokens JWT + cache profil local).
///
/// Toutes les clés utilisées par l'app sont définies ici pour éviter les
/// fautes de frappe et garder une vue d'ensemble de ce qui est persisté
/// sur l'appareil.
class SecureStorageService {
  SecureStorageService._();
  static final SecureStorageService instance = SecureStorageService._();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const _cleAccessToken = 'warms_access';
  static const _cleRefreshToken = 'warms_refresh';
  static const _cleServeurUrl = 'warms_server_url';
  static const _cleNom = 'user_name';
  static const _cleEmail = 'user_email';
  static const _cleTelephone = 'user_phone';
  static const _cleRole = 'user_role';
  static const _cleQrCode = 'user_qr_code';
  static const _clePhoto = 'user_photo';
  static const _cleHistoriqueRecherche = 'warms_historique_recherche';

  Future<String?> lireAccessToken() => _storage.read(key: _cleAccessToken);
  Future<String?> lireRefreshToken() => _storage.read(key: _cleRefreshToken);

  Future<String?> lireServeurUrl() => _storage.read(key: _cleServeurUrl);
  Future<void> sauvegarderServeurUrl(String url) =>
      _storage.write(key: _cleServeurUrl, value: url);

  Future<void> enregistrerTokens({required String access, String? refresh}) async {
    await _storage.write(key: _cleAccessToken, value: access);
    if (refresh != null && refresh.isNotEmpty) {
      await _storage.write(key: _cleRefreshToken, value: refresh);
    }
  }

  Future<void> mettreAJourAccessToken(String access) {
    return _storage.write(key: _cleAccessToken, value: access);
  }

  Future<void> supprimerTokens() async {
    await _storage.delete(key: _cleAccessToken);
    await _storage.delete(key: _cleRefreshToken);
  }

  /// Cache local du profil affiché instantanément au démarrage, avant que
  /// la réponse de `/personnel/me/` ne soit revenue du réseau.
  Future<Map<String, String>> lireProfilEnCache() async {
    return {
      'nom': await _storage.read(key: _cleNom) ?? '',
      'email': await _storage.read(key: _cleEmail) ?? '',
      'telephone': await _storage.read(key: _cleTelephone) ?? '',
      'role': await _storage.read(key: _cleRole) ?? '',
      'qrCode': await _storage.read(key: _cleQrCode) ?? '',
      'photo': await _storage.read(key: _clePhoto) ?? '',
    };
  }

  Future<void> sauvegarderProfilEnCache({
    required String nom,
    required String role,
    required String email,
  }) async {
    await _storage.write(key: _cleNom, value: nom);
    await _storage.write(key: _cleRole, value: role);
    await _storage.write(key: _cleEmail, value: email);
  }

  /// Historique des recherches IA, persisté localement sur l'appareil
  /// (les recherches ne sont pas envoyées au backend pour stockage).
  Future<List<String>> lireHistoriqueRecherche() async {
    final brut = await _storage.read(key: _cleHistoriqueRecherche);
    if (brut == null || brut.isEmpty) return const [];
    try {
      return (jsonDecode(brut) as List<dynamic>).cast<String>();
    } catch (_) {
      return const [];
    }
  }

  Future<void> sauvegarderHistoriqueRecherche(List<String> historique) {
    return _storage.write(key: _cleHistoriqueRecherche, value: jsonEncode(historique));
  }
}
