import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';

/// Service d'Intelligence Artificielle pour WARMS Mobile
/// 
/// Ce service gère toutes les interactions avec l'IA backend WARMS :
/// - Chat conversationnel intelligent
/// - Recherche médicale multi-sources
/// - Analyse de symptômes avec détection d'urgence
/// - Traitement OCR de documents médicaux
/// - Gestion des préférences utilisateur
/// 
/// @author WARMS Team
/// @version 1.0.0
class IAService {
  /// Instance singleton du service IA
  /// Pattern Singleton pour garantir une seule instance dans toute l'application
  static final IAService _instance = IAService._internal();
  factory IAService() => _instance;
  IAService._internal() {
    _configureDio();
  }

  /// Client HTTP pour les appels API
  /// Configuration optimisée pour les appels backend WARMS
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'http://127.0.0.1:8000/api/v1/ia-shared',
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent': 'WARMS-Mobile/1.0.0',
    },
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 15),
  ));
  
  /// Stockage sécurisé pour les tokens d'authentification
  /// Utilise FlutterSecureStorage pour la sécurité des données sensibles
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  /// Configuration du client HTTP avec gestion des erreurs et retry
  void _configureDio() {
    // Configuration pour le développement (accepter les certificats auto-signés)
    if (!kReleaseMode) {
      (_dio.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate = (client) {
        client.badCertificateCallback = (cert, host, port) => true;
        return client;
      };
    }

    // Intercepteur pour ajouter automatiquement le token d'authentification
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: 'access_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          // Log des erreurs pour le debugging
          if (kDebugMode) {
            print('🔴 Erreur API IA: ${error.message}');
            print('📍 URL: ${error.requestOptions.uri}');
            print('📊 Status: ${error.response?.statusCode}');
          }
          handler.next(error);
        },
      ),
    );
  }

  // ==================== CHAT INTELLIGENT ====================

  /// Envoie un message au chat IA et récupère la réponse
  /// 
  /// [message] - Le message de l'utilisateur à analyser
  /// [plateforme] - La plateforme d'origine ('mobile')
  /// [contexte] - Contexte additionnel pour personnaliser la réponse
  /// 
  /// Retourne une Map contenant la réponse de l'IA et les métadonnées
  /// 
  /// Lance une [Exception] en cas d'erreur de communication
  Future<Map<String, dynamic>> envoyerMessageIA({
    required String message,
    required String plateforme,
    Map<String, dynamic>? contexte,
  }) async {
    try {
      if (kDebugMode) {
        print('💬 Envoi message IA: "$message"');
      }

      final response = await _dio.post(
        '/conversations/',
        data: {
          'message': message.trim(),
          'plateforme': plateforme,
          'contexte': {
            ...?contexte,
            'timestamp': DateTime.now().toIso8601String(),
            'user_agent': 'WARMS-Mobile',
          },
        },
      );

      if (kDebugMode) {
        print('✅ Réponse IA reçue: ${response.data['reponse']?.substring(0, 50)}...');
      }

      return response.data;
    } on DioException catch (e) {
      final messageErreur = _getDioErrorMessage(e);
      throw Exception('💬 Erreur chat IA: $messageErreur');
    } catch (e) {
      throw Exception('💬 Erreur inattendue chat IA: $e');
    }
  }

  /// Récupère l'historique des conversations de l'utilisateur
  /// 
  /// Retourne une liste des conversations avec leurs messages
  Future<List<Map<String, dynamic>>> getConversations() async {
    try {
      final response = await _dio.get('/conversations/');
      return List<Map<String, dynamic>>.from(response.data);
    } on DioException catch (e) {
      final messageErreur = _getDioErrorMessage(e);
      throw Exception('📚 Erreur récupération conversations: $messageErreur');
    } catch (e) {
      throw Exception('📚 Erreur inattendue conversations: $e');
    }
  }

  // ==================== RECHERCHE MÉDICALE ====================

  /// Effectue une recherche médicale multi-sources
  /// 
  /// [query] - La requête de recherche médicale
  /// [plateforme] - La plateforme d'origine
  /// [contexte] - Contexte médical du patient si disponible
  /// 
  /// Retourne les résultats de recherche avec sources et pertinence
  Future<Map<String, dynamic>> rechercherMedical({
    required String query,
    required String plateforme,
    Map<String, dynamic>? contexte,
  }) async {
    try {
      if (kDebugMode) {
        print('🔍 Recherche médicale: "$query"');
      }

      final response = await _dio.post(
        '/recherches/',
        data: {
          'query': query.trim(),
          'plateforme': plateforme,
          'contexte': {
            ...?contexte,
            'timestamp': DateTime.now().toIso8601String(),
            'sources': ['pubmed', 'google_scholar', 'who'],
          },
        },
      );

      final resultats = response.data;
      if (kDebugMode) {
        print('🔍 ${resultats['resultats']?.length ?? 0} résultats trouvés');
      }

      return resultats;
    } on DioException catch (e) {
      final messageErreur = _getDioErrorMessage(e);
      throw Exception('🔍 Erreur recherche médicale: $messageErreur');
    } catch (e) {
      throw Exception('🔍 Erreur inattendue recherche: $e');
    }
  }

  // ==================== ANALYSE DE SYMPTÔMES ====================

  /// Analyse les symptômes et fournit des recommandations médicales
  /// 
  /// [symptomes] - Liste des symptômes à analyser
  /// [plateforme] - La plateforme d'origine
  /// [contexte] - Informations patient (âge, sexe, antécédents)
  /// 
  /// Retourne l'analyse avec niveau d'urgence et recommandations
  Future<Map<String, dynamic>> analyserSymptomes({
    required List<String> symptomes,
    required String plateforme,
    Map<String, dynamic>? contexte,
  }) async {
    try {
      if (kDebugMode) {
        print('🏥 Analyse symptômes: ${symptomes.join(', ')}');
      }

      final response = await _dio.post(
        '/analyses/',
        data: {
          'symptomes': symptomes.where((s) => s.trim().isNotEmpty).toList(),
          'plateforme': plateforme,
          'contexte': {
            ...?contexte,
            'timestamp': DateTime.now().toIso8601String(),
            'analyse_type': 'symptomes',
          },
        },
      );

      final analyse = response.data;
      
      // Alerte immédiate si urgence détectée
      if (analyse['niveau_urgence'] == 'critique') {
        if (kDebugMode) {
          print('🚨 URGENCE DÉTECTÉE: ${analyse['alerte_urgence']}');
        }
      }

      return analyse;
    } on DioException catch (e) {
      final messageErreur = _getDioErrorMessage(e);
      throw Exception('🏥 Erreur analyse symptômes: $messageErreur');
    } catch (e) {
      throw Exception('🏥 Erreur inattendue analyse: $e');
    }
  }

  // ==================== TRAITEMENT OCR ====================

  /// Traite une image avec OCR pour extraire le texte médical
  /// 
  /// [imageFile] - Le fichier image à traiter
  /// [metadonnees] - Métadonnées du document (type, patient, etc.)
  /// 
  /// Retourne le texte extrait avec niveau de confiance
  Future<Map<String, dynamic>> traiterImageOCR({
    required File imageFile,
    Map<String, dynamic>? metadonnees,
  }) async {
    try {
      if (!await imageFile.exists()) {
        throw Exception('📷 Fichier image introuvable');
      }

      if (kDebugMode) {
        print('📷 Traitement OCR: ${imageFile.path}');
      }

      final formData = FormData.fromMap({
        'fichier': await MultipartFile.fromFile(
          imageFile.path,
          filename: 'document_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
        'metadonnees': {
          ...?metadonnees,
          'plateforme': 'mobile',
          'timestamp': DateTime.now().toIso8601String(),
          'file_size': await imageFile.length(),
        },
      });

      final response = await _dio.post('/ocr/extract-text/', data: formData);
      
      final resultat = response.data;
      if (kDebugMode) {
        print('📷 OCR terminé - Confiance: ${resultat['confiance']}%');
        print('📝 Texte extrait: ${resultat['texte_extrait']?.substring(0, 50)}...');
      }

      return resultat;
    } on DioException catch (e) {
      final messageErreur = _getDioErrorMessage(e);
      throw Exception('📷 Erreur traitement OCR: $messageErreur');
    } catch (e) {
      throw Exception('📷 Erreur inattendue OCR: $e');
    }
  }

  // ==================== PRÉFÉRENCES IA ====================

  /// Récupère les préférences IA de l'utilisateur
  /// 
  /// Retourne les préférences de personnalisation de l'IA
  Future<Map<String, dynamic>> getPreferencesIA() async {
    try {
      final response = await _dio.get('/preferences/');
      return response.data;
    } on DioException catch (e) {
      final messageErreur = _getDioErrorMessage(e);
      throw Exception('⚙️ Erreur récupération préférences: $messageErreur');
    } catch (e) {
      throw Exception('⚙️ Erreur inattendue préférences: $e');
    }
  }

  /// Sauvegarde les préférences IA de l'utilisateur
  /// 
  /// [preferences] - Les préférences à sauvegarder
  Future<Map<String, dynamic>> sauvegarderPreferencesIA({
    required Map<String, dynamic> preferences,
  }) async {
    try {
      final response = await _dio.post(
        '/preferences/',
        data: {
          ...preferences,
          'plateforme': 'mobile',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      
      if (kDebugMode) {
        print('⚙️ Préférences IA sauvegardées');
      }
      
      return response.data;
    } on DioException catch (e) {
      final messageErreur = _getDioErrorMessage(e);
      throw Exception('⚙️ Erreur sauvegarde préférences: $messageErreur');
    } catch (e) {
      throw Exception('⚙️ Erreur inattendue sauvegarde: $e');
    }
  }

  // ==================== UTILITAIRES ====================

  /// Extrait un message d'erreur compréhensible depuis une exception Dio
  String _getDioErrorMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return 'Timeout de connexion (15s)';
      case DioExceptionType.sendTimeout:
        return 'Timeout d\'envoi (15s)';
      case DioExceptionType.receiveTimeout:
        return 'Timeout de réception (30s)';
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        switch (statusCode) {
          case 401:
            return 'Non autorisé - Veuillez vous reconnecter';
          case 403:
            return 'Accès refusé - Permissions insuffisantes';
          case 404:
            return 'Service IA indisponible';
          case 500:
            return 'Erreur serveur IA - Réessayez plus tard';
          default:
            return 'Erreur HTTP $statusCode';
        }
      case DioExceptionType.cancel:
        return 'Requête annulée';
      case DioExceptionType.connectionError:
        return 'Erreur de connexion - Vérifiez votre réseau';
      case DioExceptionType.badCertificate:
        return 'Erreur de certificat SSL';
      case DioExceptionType.unknown:
      default:
        return e.message ?? 'Erreur inconnue';
    }
  }

  /// Vérifie si le service IA est disponible
  Future<bool> isServiceAvailable() async {
    try {
      await _dio.get('/health/', 
        options: Options(
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('🔴 Service IA indisponible: $e');
      }
      return false;
    }
  }
}
