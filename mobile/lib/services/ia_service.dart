import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// Service d'Intelligence Artificielle pour WARMS Mobile : chat
/// conversationnel, recherche médicale, analyse de symptômes, OCR.
///
/// Utilise le client HTTP partagé ([ApiClient]) plutôt qu'une instance Dio
/// dédiée : avant ce changement, ce service lisait le token sous la clé
/// `'access_token'`, qui n'a jamais été écrite nulle part (le reste de
/// l'app utilise `'warms_access'` via [SecureStorageService]) — toutes les
/// requêtes IA partaient donc sans en-tête `Authorization` et échouaient
/// silencieusement en 401/403.
class IAService {
  static final IAService _instance = IAService._internal();
  factory IAService() => _instance;
  IAService._internal();

  final Dio _dio = ApiClient.instance.dio;
  static const _prefixe = '/ia-shared';

  // ==================== CHAT INTELLIGENT ====================

  /// Retourne la conversation IA existante de l'utilisateur pour cette
  /// plateforme (avec son historique de messages), ou en crée une nouvelle
  /// s'il n'y en a aucune.
  Future<Map<String, dynamic>> obtenirOuCreerConversation({required String plateforme}) async {
    try {
      final rep = await _dio.get('$_prefixe/conversations/', queryParameters: {'plateforme': plateforme});
      final data = rep.data;
      final liste = data is Map ? (data['results'] as List<dynamic>? ?? []) : data as List<dynamic>;
      if (liste.isNotEmpty) return liste.first as Map<String, dynamic>;

      final creation = await _dio.post('$_prefixe/conversations/', data: {'plateforme': plateforme});
      return creation.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_messageErreur(e));
    }
  }

  /// Ajoute un message utilisateur à une conversation et récupère la
  /// réponse de l'IA. Retourne `{message_user, message_ia}`.
  Future<Map<String, dynamic>> envoyerMessageIA({
    required String conversationId,
    required String message,
  }) async {
    try {
      final response = await _dio.post(
        '$_prefixe/conversations/$conversationId/ajouter_message/',
        data: {'contenu': message.trim(), 'type_message': 'user'},
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_messageErreur(e));
    }
  }

  // ==================== RECHERCHE MÉDICALE ====================

  /// Effectue une recherche médicale multi-sources.
  Future<Map<String, dynamic>> rechercherMedical({
    required String query,
    required String plateforme,
    Map<String, dynamic>? contexte,
  }) async {
    try {
      final response = await _dio.post(
        '$_prefixe/recherches/',
        data: {
          'query': query.trim(),
          'plateforme': plateforme,
          'contexte': {
            ...?contexte,
            'timestamp': DateTime.now().toIso8601String(),
          },
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_messageErreur(e));
    }
  }

  // ==================== ANALYSE DE SYMPTÔMES ====================

  /// Analyse les symptômes et fournit des recommandations médicales.
  Future<Map<String, dynamic>> analyserSymptomes({
    required List<String> symptomes,
    required String plateforme,
    Map<String, dynamic>? contexte,
  }) async {
    try {
      final response = await _dio.post(
        '$_prefixe/analyses/',
        data: {
          'symptomes': symptomes.where((s) => s.trim().isNotEmpty).toList(),
          'plateforme': plateforme,
          'contexte': {
            ...?contexte,
            'timestamp': DateTime.now().toIso8601String(),
          },
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_messageErreur(e));
    }
  }

  // ==================== TRAITEMENT OCR ====================

  /// Traite une image avec OCR pour extraire le texte médical.
  Future<Map<String, dynamic>> traiterImageOCR({
    required File imageFile,
    Map<String, dynamic>? metadonnees,
  }) async {
    if (!await imageFile.exists()) {
      throw Exception('Fichier image introuvable');
    }
    try {
      final formData = FormData.fromMap({
        'fichier': await MultipartFile.fromFile(
          imageFile.path,
          filename: 'document_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
        'metadonnees': {
          ...?metadonnees,
          'plateforme': 'mobile',
          'timestamp': DateTime.now().toIso8601String(),
        },
      });
      final response = await _dio.post('$_prefixe/ocr/extract-text/', data: formData);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_messageErreur(e));
    }
  }

  // ==================== PRÉFÉRENCES IA ====================

  Future<Map<String, dynamic>> getPreferencesIA() async {
    try {
      final response = await _dio.get('$_prefixe/preferences/');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_messageErreur(e));
    }
  }

  Future<Map<String, dynamic>> sauvegarderPreferencesIA({
    required Map<String, dynamic> preferences,
  }) async {
    try {
      final response = await _dio.post(
        '$_prefixe/preferences/',
        data: {...preferences, 'plateforme': 'mobile'},
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_messageErreur(e));
    }
  }

  // ==================== UTILITAIRES ====================

  String _messageErreur(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Le service IA met trop de temps à répondre. Réessayez.';
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        if (statusCode == 401 || statusCode == 403) {
          return 'Session expirée, veuillez vous reconnecter.';
        }
        return 'Le service IA est momentanément indisponible.';
      case DioExceptionType.connectionError:
        return 'Vérifiez votre connexion réseau.';
      default:
        if (kDebugMode) debugPrint("Wam's: erreur IA: ${e.message}");
        return 'Une erreur inattendue est survenue.';
    }
  }

  Future<bool> isServiceAvailable() async {
    try {
      await _dio.get(
        '$_prefixe/health/',
        options: Options(receiveTimeout: const Duration(seconds: 5)),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
