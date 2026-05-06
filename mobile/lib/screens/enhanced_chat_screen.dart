import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../services/claude_service.dart';
import '../themes/warms_theme.dart';

/// Écran de chat IA amélioré pour WARMS Mobile
/// 
/// Cet écran offre une interface de conversation moderne avec :
/// - Reconnaissance vocale et synthèse vocale
/// - Interface intuitive avec animations fluides
/// - Support multilingue (français/anglais)
/// - Thème WARMS cohérent
/// - Gestion intelligente des conversations
/// 
/// @author WARMS Team
/// @version 2.0.0
class EnhancedChatScreen extends StatefulWidget {
  const EnhancedChatScreen({super.key});

  @override
  State<EnhancedChatScreen> createState() => _EnhancedChatScreenState();
}

class _EnhancedChatScreenState extends State<EnhancedChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  bool _isListening = false;
  bool _isSpeaking = false;
  late ClaudeService _claudeService;
  late SpeechToText _speech;
  late FlutterTts _tts;
  bool _isClaudeAvailable = true;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _addWelcomeMessage();
  }

  Future<void> _initializeServices() async {
    _claudeService = ClaudeService();
    await _claudeService.initialize();
    
    _speech = SpeechToText();
    _tts = FlutterTts();
    
    // Vérifier la disponibilité des services
    await _tts.setLanguage('fr-FR');
    await _tts.setSpeechRate(0.9);
    await _tts.setVolume(1.0);
    
    final locales = await _speech.locales();
    final frenchLocale = locales.firstWhere(
      (locale) => locale.localeId.startsWith('fr'),
      orElse: () => locales.first,
    );
    
  await _speech.initialize(
        onStatus: (status) {
          setState(() {
            _isListening = status == 'listening';
          });
        },
        onError: (error) {
          setState(() => _isListening = false);
        },
      );
  }

  void _addWelcomeMessage() {
    setState(() {
      _messages.add({
        'role': 'assistant',
        'content': '👋 Bonjour ! Je suis votre assistant médical WARMS. Comment puis-je vous aider aujourd\'hui ?',
        'timestamp': DateTime.now().toIso8601String(),
      });
    });
    _scrollToBottom();
  }

  void _handleUserMessage(String message) {
    if (message.trim().isEmpty) return;
    
    setState(() {
      _messages.add({
        'role': 'user',
        'content': message,
        'timestamp': DateTime.now().toIso8601String(),
      });
    });
    
    _sendMessageToClaude(message);
    _scrollToBottom();
  }

  Future<void> _sendMessageToClaude(String message) async {
    setState(() {
      _messages.add({
        'role': 'assistant',
        'content': '⏳ Réflexion en cours...',
        'timestamp': DateTime.now().toIso8601String(),
      });
    });
    _scrollToBottom();

    try {
      final response = await _claudeService.sendMessageToClaude(message);
      setState(() {
        _messages.removeLast(); // Retirer le message de "réflexion"
        _messages.add({
          'role': 'assistant',
          'content': response,
          'timestamp': DateTime.now().toIso8601String(),
        });
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.removeLast(); // Retirer le message de "réflexion"
        _messages.add({
          'role': 'assistant',
          'content': '❌ Désolé, je rencontre des difficultés techniques. Veuillez réessayer dans quelques instants.',
          'timestamp': DateTime.now().toIso8601String(),
        });
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _startListening() async {
    if (!_isListening && _speech.isAvailable) {
      await _speech.listen(
        onResult: (result) {
          if (result.finalResult && result.recognizedWords.isNotEmpty) {
            _handleUserMessage(result.recognizedWords);
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: false,
        localeId: 'fr_FR',
      );
    }
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
  }

  Future<void> _speakResponse(String text) async {
    if (text.trim().isEmpty) return;
    
    setState(() => _isSpeaking = true);
    
    try {
      await _tts.speak(text);
    } catch (e) {
      setState(() => _isSpeaking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          '💬 Chat IA WARMS',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: WarmsTheme.warmsAccent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: WarmsTheme.warmsBlue.withOpacity( 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  final isUser = message['role'] == 'user';
                  final timestamp = DateTime.parse(message['timestamp']!);
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isUser ? WarmsTheme.warmsAccent : WarmsTheme.warmsBlue,
                          ),
                          child: Center(
                            child: Icon(
                              isUser ? Icons.person : Icons.smart_toy,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Message
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Heure
                              Text(
                                '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: WarmsTheme.warmsGray,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              // Contenu
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isUser ? WarmsTheme.warmsAccent.withOpacity( 0.1) : Colors.grey.withOpacity( 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  message['content']!,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: isUser ? WarmsTheme.warmsNavy : Colors.black87,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          
          // Zone de saisie
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(
                top: BorderSide(
                  color: WarmsTheme.warmsGray.withOpacity( 0.3),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                // Champ de texte
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Tapez votre message...',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(width: 8),
                
                // Boutons d'action
                Column(
                  children: [
                    // Microphone
                    GestureDetector(
                      onTap: _isListening ? _stopListening : _startListening,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isListening ? WarmsTheme.warmsError : WarmsTheme.warmsSuccess,
                          boxShadow: [
                            BoxShadow(
                              color: (_isListening ? WarmsTheme.warmsError : WarmsTheme.warmsSuccess).withOpacity( 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Envoi
                    GestureDetector(
                      onTap: () => _handleUserMessage(_messageController.text),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: WarmsTheme.warmsAccent,
                          boxShadow: [
                            BoxShadow(
                              color: WarmsTheme.warmsAccent.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: _isSpeaking                          // ← child: avec ternaire
                            ? const CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              )
                            : const Icon(
                                Icons.send,
                                color: Colors.white,
                                size: 24,
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }
}


