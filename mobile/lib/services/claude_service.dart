import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

/// Service Claude AI pour WARMS Mobile
/// 
/// Ce service gère les interactions avec Claude d'Anthropic pour des réponses
/// intelligentes en temps réel, avec reconnaissance vocale et synthèse vocale.
/// 
/// @author WARMS Team
/// @version 2.0.0
class ClaudeService {
  /// Instance singleton
  static final ClaudeService _instance = ClaudeService._internal();
  factory ClaudeService() => _instance;
  ClaudeService._internal();

  /// Client HTTP pour Claude API
  late Dio _dio;
  
  /// Service de reconnaissance vocale
  final SpeechToText _speech = SpeechToText();
  
  /// Service de synthèse vocale
  final FlutterTts _tts = FlutterTts();
  
  /// État de la reconnaissance vocale
  bool _isListening = false;
  bool _isClaudeAvailable = false;
  
  /// Historique de conversation pour le contexte
  final List<Map<String, String>> _conversationHistory = [];
  
  /// Initialiser le service Claude
  Future<void> initialize() async {
    try {
      // Initialiser le client HTTP pour Claude API
      _dio = Dio(BaseOptions(
        baseUrl: 'https://api.anthropic.com',
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': 'votre-clé-api-anthropic-ici',
          'anthropic-version': '2023-06-01',
        },
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
      ));
      
      // Initialiser la reconnaissance vocale
      await _speech.initialize();
      
      // Initialiser la synthèse vocale
      await _tts.setLanguage("fr-FR");
      await _tts.setSpeechRate(0.9);
      await _tts.setVolume(1.0);
      
      _isClaudeAvailable = true;
      
      if (kDebugMode) {
        print('✅ Service Claude initialisé avec succès');
      }
    } catch (e) {
      _isClaudeAvailable = false;
      if (kDebugMode) {
        print('❌ Erreur lors de l\'initialisation de Claude: $e');
      }
    }
  }
  
  /// Vérifier si Claude est disponible
  bool get isClaudeAvailable => _isClaudeAvailable;
  
  /// Vérifier si la reconnaissance vocale est disponible
  bool get isSpeechAvailable => _speech.isAvailable;
  
  /// Démarrer la reconnaissance vocale
  Future<String?> startListening() async {
    if (!_isListening && _speech.isAvailable) {
      _isListening = true;
      
final completer = Completer<String>();

await _speech.listen(
  onResult: (result) {
    final recognizedWords = result.recognizedWords;
    if (result.finalResult && recognizedWords.isNotEmpty) {
      _isListening = false;
      if (!completer.isCompleted) {
        completer.complete(recognizedWords); // ← on transmet la valeur
      }
    }
  },
  listenFor: const Duration(seconds: 30),
  pauseFor: const Duration(seconds: 3),
  partialResults: false,
  localeId: 'fr_FR',
);

final recognizedWords = await completer.future;
    }
    return null;
  }
  
  /// Arrêter la reconnaissance vocale
  Future<void> stopListening() async {
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
    }
  }
  
  /// Envoyer un message à Claude et obtenir une réponse
  Future<String> sendMessageToClaude(String message) async {
    if (!_isClaudeAvailable) {
      return _getFallbackResponse(message);
    }
    
    try {
      // Ajouter le message à l'historique
      _conversationHistory.add({
        'role': 'user',
        'content': message,
      });
      
      // Préparer la requête pour Claude API
      final requestData = {
        'model': 'claude-3-sonnet-20240229',
        'max_tokens': 1000,
        'messages': [
          {
            'role': 'user',
            'content': _buildContextualPrompt(message),
          }
        ],
      };
      
      // Appeler Claude API
      final response = await _dio.post('/v1/messages', data: requestData);
      
      if (response.statusCode == 200) {
        final claudeResponse = response.data['content'][0]['text'] as String;
        
        // Ajouter la réponse à l'historique
        _conversationHistory.add({
          'role': 'assistant',
          'content': claudeResponse,
        });
        
        // Limiter l'historique à 10 messages
        if (_conversationHistory.length > 10) {
          _conversationHistory.removeRange(0, _conversationHistory.length - 10);
        }
        
        return claudeResponse;
      } else {
        throw Exception('Erreur HTTP: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Erreur lors de l\'appel à Claude: $e');
      }
      return _getFallbackResponse(message);
    }
  }
  
  /// Construire un prompt contextuel pour Claude
    String _buildContextualPrompt(String userMessage) {
      final String systemPrompt = '''
    Tu es un assistant médical IA pour WARMS...
    Contexte: ${_conversationHistory.map((msg) => '${msg['role']}: ${msg['content']}').join('\n')}
    Message: $userMessage
    ''';
      return systemPrompt;  // ← retourne la variable locale correctement
    }
      
      /// Réponse de secours si Claude n'est pas disponible
      String _getFallbackResponse(String message) {
        if (message.toLowerCase().contains('bonjour') || message.toLowerCase().contains('salut')) {
          return 'Bonjour ! Je suis votre assistant médical WARMS. Comment puis-je vous aider aujourd\'hui ?';
        } else if (message.toLowerCase().contains('symptôme')) {
          return 'Je comprends que vous vous inquiétez à propos de symptômes. Pour une évaluation précise, je vous recommande de consulter un professionnel de santé. Pouvez-vous me décrire plus précisément ce que vous ressentez ?';
        } else if (message.toLowerCase().contains('médicament')) {
          return 'Concernant les médicaments, il est important de toujours suivre les conseils de votre médecin ou pharmacien. Je peux vous donner des informations générales, mais pas de prescriptions médicales.';
        } else {
          return 'Je suis là pour vous aider avec des informations médicales générales. Pour des conseils personnalisés, veuillez consulter un professionnel de santé. Comment puis-je vous assister ?';
        }
      }
  
  /// Synthétiser et lire la réponse vocalement
  Future<void> speakResponse(String text) async {
    try {
      await _tts.speak(text);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de la synthèse vocale: $e');
      }
    }
  }
  
  /// Arrêter la lecture vocale
  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de l\'arrêt de la lecture: $e');
      }
    }
  }
  
  /// Effacer l'historique de conversation
  void clearHistory() {
    _conversationHistory.clear();
  }
  
  /// Obtenir l'historique de conversation
  List<Map<String, String>> get conversationHistory => 
      List.unmodifiable(_conversationHistory);
  
  /// Nettoyer les ressources
  void dispose() {
    stopListening();
    stopSpeaking();
    _conversationHistory.clear();
  }
}
