import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/conversation_ia.dart';
import '../models/recherche_ia.dart';
import '../models/analyse_medicale.dart';
import '../models/document_ocr.dart';

class IAService {
  static const String baseUrl = 'http://127.0.0.1:8000/api/v1/ia-shared';
  static const String apiKey = 'YOUR_API_KEY'; // À configurer
  
  // Headers communs pour les requêtes API
  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'X-API-Key': apiKey,
  };

  // ==================== CONVERSATIONS IA ====================

  /// Crée une nouvelle conversation IA
  static Future<ConversationIA> creerConversation({
    String plateforme = 'mobile',
    Map<String, dynamic>? contexte,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/conversations/'),
        headers: headers,
        body: jsonEncode({
          'plateforme': plateforme,
          'contexte': contexte ?? {},
        }),
      );

      if (response.statusCode == 201) {
        return ConversationIA.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Erreur création conversation: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Impossible de créer la conversation: $e');
    }
  }

  /// Récupère les conversations de l'utilisateur
  static Future<List<ConversationIA>> getConversations({
    String plateforme = 'mobile',
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/conversations/?plateforme=$plateforme'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((c) => ConversationIA.fromJson(c)).toList();
      } else {
        throw Exception('Erreur récupération conversations: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Impossible de récupérer les conversations: $e');
    }
  }

  /// Envoie un message dans une conversation et reçoit la réponse IA
  static Future<Map<String, dynamic>> envoyerMessage({
    required String conversationId,
    required String message,
    String typeMessage = 'user',
    Map<String, dynamic>? metadonnees,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/conversations/$conversationId/ajouter_message/'),
        headers: headers,
        body: jsonEncode({
          'contenu': message,
          'type_message': typeMessage,
          'metadonnees': metadonnees ?? {},
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Erreur envoi message: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Impossible d\'envoyer le message: $e');
    }
  }

  // ==================== RECHERCHE MÉDICALE ====================

  /// Effectue une recherche médicale
  static Future<RechercheIA> rechercherMedical({
    required String query,
    String plateforme = 'mobile',
    Map<String, dynamic>? contexte,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/recherches/'),
        headers: headers,
        body: jsonEncode({
          'query': query,
          'plateforme': plateforme,
          'contexte': contexte ?? {},
        }),
      );

      if (response.statusCode == 201) {
        return RechercheIA.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Erreur recherche médicale: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Impossible d\'effectuer la recherche: $e');
    }
  }

  /// Récupère l'historique des recherches
  static Future<List<RechercheIA>> getHistoriqueRecherches({
    String plateforme = 'mobile',
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/recherches/?plateforme=$plateforme'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((r) => RechercheIA.fromJson(r)).toList();
      } else {
        throw Exception('Erreur historique recherches: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Impossible de récupérer l\'historique: $e');
    }
  }

  // ==================== ANALYSES MÉDICALES ====================

  /// Analyse les symptômes avec IA
  static Future<AnalyseMedicale> analyserSymptomes({
    required List<String> symptomes,
    Map<String, dynamic>? patientInfo,
    String plateforme = 'mobile',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/analyses/analyser_symptomes/'),
        headers: headers,
        body: jsonEncode({
          'symptomes': symptomes,
          'patient_info': patientInfo ?? {},
          'plateforme': plateforme,
        }),
      );

      if (response.statusCode == 201) {
        return AnalyseMedicale.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Erreur analyse symptômes: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Impossible d\'analyser les symptômes: $e');
    }
  }

  /// Suggère des traitements basés sur un diagnostic
  static Future<Map<String, dynamic>> suggererTraitements({
    required String diagnostic,
    Map<String, dynamic>? patientInfo,
    String plateforme = 'mobile',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/api/v1/ia-avancee/suggerer-traitements/'),
        headers: headers,
        body: jsonEncode({
          'diagnostic': diagnostic,
          'patient_info': patientInfo ?? {},
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Erreur suggestion traitements: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Impossible de suggérer des traitements: $e');
    }
  }

  /// Vérifie les interactions médicamenteuses
  static Future<Map<String, dynamic>> verifierInteractions({
    required List<String> medicaments,
    String plateforme = 'mobile',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/api/v1/ia-avancee/verifier-interactions/'),
        headers: headers,
        body: jsonEncode({
          'medicaments': medicaments,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Erreur vérification interactions: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Impossible de vérifier les interactions: $e');
    }
  }

  // ==================== OCR ====================

  /// Traite une image avec OCR
  static Future<DocumentOCR> traiterImageOCR({
    required File imageFile,
    Map<String, dynamic>? metadonnees,
    String plateforme = 'mobile',
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/documents/'),
      );

      request.headers.addAll(headers);
      request.fields['plateforme'] = plateforme;
      
      if (metadonnees != null) {
        request.fields['metadonnees'] = jsonEncode(metadonnees);
      }

      final imageBytes = await imageFile.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: imageFile.path.split('/').last,
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        return DocumentOCR.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Erreur OCR: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Impossible de traiter l\'image: $e');
    }
  }

  /// Récupère les documents OCR traités
  static Future<List<DocumentOCR>> getDocumentsOCR({
    String plateforme = 'mobile',
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/documents/?plateforme=$plateforme'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((d) => DocumentOCR.fromJson(d)).toList();
      } else {
        throw Exception('Erreur récupération documents: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Impossible de récupérer les documents: $e');
    }
  }

  // ==================== PRÉFÉRENCES ====================

  /// Récupère les préférences IA de l'utilisateur
  static Future<Map<String, dynamic>> getPreferences({
    String plateforme = 'mobile',
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/preferences/?plateforme=$plateforme'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Erreur récupération préférences: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Impossible de récupérer les préférences: $e');
    }
  }

  /// Met à jour les préférences IA
  static Future<Map<String, dynamic>> updatePreferences({
    required Map<String, dynamic> preferences,
    String plateforme = 'mobile',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/preferences/?plateforme=$plateforme'),
        headers: headers,
        body: jsonEncode(preferences),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Erreur mise à jour préférences: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Impossible de mettre à jour les préférences: $e');
    }
  }

  // ==================== STATISTIQUES ====================

  /// Récupère les statistiques d'utilisation IA
  static Future<Map<String, dynamic>> getStatistiques({
    String plateforme = 'mobile',
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/statistiques/?plateforme=$plateforme'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Erreur récupération statistiques: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Impossible de récupérer les statistiques: $e');
    }
  }
}
