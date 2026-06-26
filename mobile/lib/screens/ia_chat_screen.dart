import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../services/ia_service.dart';
import '../themes/warms_theme.dart';

/// Écran de Chat IA pour WARMS Mobile
/// 
/// Cet écran permet aux utilisateurs de discuter avec l'IA médicale WARMS
/// pour obtenir des informations, des conseils et du soutien médical.
/// 
/// Fonctionnalités principales :
/// - Chat conversationnel en temps réel
/// - Détection automatique des urgences médicales
/// - Historique des conversations persistant
/// - Interface moderne avec animations fluides
/// - Support des suggestions rapides
/// 
/// @author WARMS Team
/// @version 1.0.0
class IAChatScreen extends StatefulWidget {
  const IAChatScreen({super.key});

  @override
  State<IAChatScreen> createState() => _IAChatScreenState();
}

class _IAChatScreenState extends State<IAChatScreen> 
    with TickerProviderStateMixin {
  
  // ==================== CONTRÔLEURS ====================
  
  /// Contrôleur pour le champ de saisie de message
  final TextEditingController _messageController = TextEditingController();
  
  /// Contrôleur pour le scrolling de la liste de messages
  final ScrollController _scrollController = ScrollController();
  
  /// Animation pour l'indicateur de saisie
  late AnimationController _typingIndicatorController;
  
  /// Animation pour les messages
  late AnimationController _messageAnimationController;

  // ==================== ÉTAT ====================
  
  /// Liste des messages de la conversation
  final List<Map<String, dynamic>> _messages = [];
  
  /// État de chargement pour l'envoi de message
  bool _isLoading = false;
  
  /// Indicateur si l'IA est en train d'écrire
  bool _isTyping = false;
  
  /// Message d'erreur à afficher
  String? _errorMessage;

  /// Identifiant de la conversation IA en cours (créée ou réutilisée au
  /// premier chargement) ; nécessaire pour y ajouter des messages.
  String? _conversationId;

  // ==================== SUGGESTIONS RAPIDES ====================
  
  /// Suggestions prédéfinies pour aider l'utilisateur
  static const List<String> _suggestions = [
    'Quels sont les symptômes de la grippe ?',
    'Comment prévenir les maladies cardiaques ?',
    'Qu\'est-ce que l\'hypertension ?',
    'Conseils pour une bonne alimentation',
    'Comment gérer le stress ?',
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadConversationHistory();
    _scrollToBottom();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingIndicatorController.dispose();
    _messageAnimationController.dispose();
    super.dispose();
  }

  // ==================== INITIALISATION ====================

  /// Initialise les animations pour l'interface
  void _initializeAnimations() {
    // Animation pour l'indicateur de saisie (points qui apparaissent/disparaissent)
    _typingIndicatorController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    // Animation pour l'apparition des messages
    _messageAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  /// Récupère (ou crée) la conversation IA de l'utilisateur et charge son
  /// historique de messages depuis le service IA.
  Future<void> _loadConversationHistory() async {
    try {
      setState(() => _isLoading = true);

      final conversation = await IAService().obtenirOuCreerConversation(plateforme: 'mobile');
      _conversationId = conversation['id'] as String?;
      final messages = (conversation['messages'] as List<dynamic>? ?? [])
          .map((m) => _depuisMessageIA(m as Map<String, dynamic>))
          .toList();

      if (messages.isNotEmpty) {
        setState(() {
          _messages.addAll(messages);
          _isLoading = false;
        });
        _scrollToBottom();
      } else {
        // Message de bienvenue pour les nouvelles conversations
        _addWelcomeMessage();
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Impossible de charger l\'historique';
        _isLoading = false;
      });
      _addWelcomeMessage();
    }
  }

  /// Convertit un message renvoyé par le backend (`MessageIASerializer`)
  /// vers la forme attendue par les bulles de cet écran.
  Map<String, dynamic> _depuisMessageIA(Map<String, dynamic> message) {
    final metadonnees = message['metadonnees'] as Map<String, dynamic>? ?? const {};
    return {
      'id': message['id'],
      'type': message['type_message'] == 'user' ? 'user' : 'ia',
      'contenu': message['contenu'] ?? '',
      'timestamp': DateTime.tryParse(message['timestamp']?.toString() ?? '') ?? DateTime.now(),
      'confidence': (metadonnees['confidence'] as num?)?.toDouble() ?? 0.8,
      'urgence': metadonnees['niveau_urgence'],
    };
  }

  /// Ajoute un message de bienvenue pour démarrer la conversation
  void _addWelcomeMessage() {
    final welcomeMessage = {
      'id': DateTime.now().millisecondsSinceEpoch,
      'type': 'ia',
      'contenu': '👋 Bonjour ! Je suis WARMS, votre assistant médical intelligent.\n\n'
          'Je peux vous aider avec :\n'
          '• 🏥 Informations sur les symptômes et maladies\n'
          '• 💊 Conseils sur les traitements\n'
          '• 🥗 Recommandations de prévention\n'
          '• 🚨 Détection d\'urgences médicales\n\n'
          'Comment puis-je vous aider aujourd\'hui ?',
      'timestamp': DateTime.now(),
      'confidence': 1.0,
    };
    
    setState(() {
      _messages.add(welcomeMessage);
    });
    
    // Animation d'apparition du message
    _messageAnimationController.forward();
  }

  // ==================== GESTION DES MESSAGES ====================

  /// Envoie un message à l'IA et traite la réponse
  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    
    // Validation du message
    if (message.isEmpty) {
      _showError('Veuillez entrer un message');
      return;
    }

    if (message.length > 1000) {
      _showError('Le message est trop long (max 1000 caractères)');
      return;
    }

    // Ajouter le message de l'utilisateur
    final userMessage = {
      'id': DateTime.now().millisecondsSinceEpoch,
      'type': 'user',
      'contenu': message,
      'timestamp': DateTime.now(),
    };

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
      _isTyping = true;
      _errorMessage = null;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      final conversationId = _conversationId;
      if (conversationId == null) {
        throw Exception('Conversation non initialisée');
      }

      // Envoyer le message à l'IA et ajouter sa réponse
      final response = await IAService().envoyerMessageIA(
        conversationId: conversationId,
        message: message,
      );
      final iaMessage = _depuisMessageIA(response['message_ia'] as Map<String, dynamic>);

      setState(() {
        _messages.add(iaMessage);
        _isLoading = false;
        _isTyping = false;
      });

      // Alerte spéciale si urgence détectée
      if (iaMessage['urgence'] == 'critique') {
        _showUrgencyAlert('Urgence détectée : contactez le cabinet ou les urgences sans attendre.');
      }

      _scrollToBottom();
      _messageAnimationController.forward();

    } catch (e) {
      setState(() {
        _isLoading = false;
        _isTyping = false;
        _errorMessage = e.toString();
      });

      // Message d'erreur de l'IA
      final errorMessage = {
        'id': DateTime.now().millisecondsSinceEpoch + 2,
        'type': 'ia',
        'contenu': '😔 Désolé, je rencontre des difficultés techniques. '
            'Veuillez réessayer dans quelques instants.',
        'timestamp': DateTime.now(),
        'confidence': 0.0,
        'is_error': true,
      };

      setState(() {
        _messages.add(errorMessage);
      });
      
      _scrollToBottom();
    }
  }

  // ==================== INTERFACE UTILISATEUR ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Messages d'erreur
          if (_errorMessage != null) _buildErrorMessage(),
          
          // Liste des messages
          Expanded(
            child: _isLoading && _messages.isEmpty
                ? _buildLoadingState()
                : _buildMessagesList(),
          ),
          
          // Indicateur de saisie IA
          if (_isTyping) _buildTypingIndicator(),
          
          // Zone de saisie
          _buildMessageInput(),
        ],
      ),
    );
  }

  /// Construit la barre d'application avec le titre et les actions
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: WarmsTheme.warmsAccent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.medical_services,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'WARMS IA',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
        ],
      ),
      backgroundColor: Colors.white,
      elevation: 0,
      actions: [
        // Bouton d'options
        IconButton(
          onPressed: _showOptions,
          icon: const Icon(Icons.more_vert),
          tooltip: 'Options',
        ),
      ],
    );
  }

  /// Affiche un message d'erreur s'il y en a un
  Widget _buildErrorMessage() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[600], size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(
                color: Colors.red[800],
                fontSize: 14,
              ),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _errorMessage = null),
            icon: const Icon(Icons.close, size: 16),
            color: Colors.red[600],
          ),
        ],
      ),
    );
  }

  /// État de chargement initial
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animation Lottie de chargement
          Lottie.asset(
            'assets/animations/doctor_loading.json',
            width: 200,
            height: 200,
            repeat: true,
          ),
          const SizedBox(height: 24),
          Text(
            'Chargement de votre conversation...',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'WARMS prépare vos réponses personnalisées',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// Liste des messages avec animations
  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return _buildMessageBubble(message, index);
      },
    );
  }

  /// Construit une bulle de message individuelle
  Widget _buildMessageBubble(Map<String, dynamic> message, int index) {
    final isUserMessage = message['type'] == 'user';
    final isErrorMessage = message['is_error'] == true;
    
    return AnimatedBuilder(
      animation: _messageAnimationController,
      builder: (context, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: Offset(isUserMessage ? 1.0 : -1.0, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: _messageAnimationController,
            curve: Curves.easeOutQuart,
          )),
          child: FadeTransition(
            opacity: _messageAnimationController,
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: isUserMessage 
                    ? MainAxisAlignment.end 
                    : MainAxisAlignment.start,
                children: [
                  if (!isUserMessage) ...[
                    // Avatar de l'IA
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: CircleAvatar(
                        backgroundColor: WarmsTheme.warmsAccent,
                        radius: 16,
                        child: const Icon(
                          Icons.smart_toy,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                  
                  // Bulle de message
                  Flexible(
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isUserMessage 
                            ? WarmsTheme.warmsAccent
                            : isErrorMessage 
                                ? Colors.red[100]
                                : Colors.white,
                        borderRadius: BorderRadius.circular(16).copyWith(
                          bottomLeft: isUserMessage ? Radius.circular(16) : Radius.circular(4),
                          bottomRight: isUserMessage ? Radius.circular(4) : Radius.circular(16),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: isErrorMessage 
                            ? Border.all(color: Colors.red[200]!)
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Contenu du message
                          Text(
                            message['contenu'] ?? '',
                            style: TextStyle(
                              color: isUserMessage || isErrorMessage
                                  ? Colors.white
                                  : Colors.black87,
                              fontSize: 15,
                              height: 1.4,
                            ),
                          ),
                          
                          // Métadonnées du message
                          if (message['confidence'] != null || message['urgence'] != null) ...[
                            const SizedBox(height: 8),
                            _buildMessageMetadata(message),
                          ],
                          
                          // Timestamp
                          const SizedBox(height: 4),
                          Text(
                            _formatTimestamp(message['timestamp']),
                            style: TextStyle(
                              color: isUserMessage || isErrorMessage
                                  ? Colors.white70
                                  : Colors.grey[500],
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  if (isUserMessage) ...[
                    // Avatar de l'utilisateur
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      child: CircleAvatar(
                        backgroundColor: Colors.grey[300],
                        radius: 16,
                        child: const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Construit les métadonnées du message (confiance, urgence)
  Widget _buildMessageMetadata(Map<String, dynamic> message) {
    final confidence = message['confidence'] as double?;
    final urgence = message['urgence'] as String?;
    
    return Row(
      children: [
        // Indicateur de confiance
        if (confidence != null && confidence < 1.0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _getConfidenceColor(confidence).withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${(confidence * 100).toInt()}%',
              style: TextStyle(
                color: _getConfidenceColor(confidence),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        
        // Indicateur d'urgence
        if (urgence != null && urgence == 'critique') ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning,
                  color: Colors.red[600],
                  size: 10,
                ),
                const SizedBox(width: 2),
                Text(
                  'URGENCE',
                  style: TextStyle(
                    color: Colors.red[600],
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Indicateur de saisie de l'IA avec animation
  Widget _buildTypingIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Avatar de l'IA
          CircleAvatar(
            backgroundColor: WarmsTheme.warmsAccent,
            radius: 16,
            child: const Icon(
              Icons.smart_toy,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          
          // Bulle de saisie avec points animés
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16).copyWith(
                bottomRight: const Radius.circular(4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) {
                return AnimatedBuilder(
                  animation: _typingIndicatorController,
                  builder: (context, child) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  /// Zone de saisie de message avec suggestions
  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Suggestions rapides
          if (_messages.isEmpty) _buildSuggestions(),
          
          // Champ de saisie
          Row(
            children: [
              // Bouton microphone (optionnel)
              Container(
                margin: const EdgeInsets.only(right: 8),
                child: IconButton(
                  onPressed: _toggleVoiceInput,
                  icon: const Icon(Icons.mic),
                  tooltip: 'Saisie vocale',
                ),
              ),
              
              // Champ de texte
              Expanded(
                child: TextField(
                  controller: _messageController,
                  maxLines: null,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Tapez votre message...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: WarmsTheme.warmsAccent),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    suffixIcon: _isLoading
                        ? Padding(
                            padding: const EdgeInsets.all(12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  WarmsTheme.warmsAccent,
                                ),
                              ),
                            ),
                          )
                        : null,
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              
              const SizedBox(width: 8),
              
              // Bouton d'envoi
              FloatingActionButton(
                onPressed: _isLoading ? null : _sendMessage,
                backgroundColor: WarmsTheme.warmsAccent,
                mini: true,
                child: const Icon(
                  Icons.send,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Suggestions rapides pour aider l'utilisateur
  Widget _buildSuggestions() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _suggestions.length,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text(
                _suggestions[index],
                style: const TextStyle(fontSize: 12),
              ),
              onPressed: () {
                _messageController.text = _suggestions[index];
                _sendMessage();
              },
              backgroundColor: WarmsTheme.warmsBg,
              side: BorderSide(color: WarmsTheme.warmsAccent.withValues(alpha: 0.3)),
            ),
          );
        },
      ),
    );
  }

  // ==================== UTILITAIRES ====================

  /// Fait défiler la liste vers le bas
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

  /// Formate le timestamp pour l'affichage
  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) return '';
    
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'À l\'instant';
    } else if (difference.inHours < 1) {
      return 'Il y a ${difference.inMinutes} min';
    } else if (difference.inDays < 1) {
      return 'Il y a ${difference.inHours}h';
    } else {
      return '${timestamp.day}/${timestamp.month} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }

  /// Retourne la couleur en fonction du niveau de confiance
  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return Colors.green[600]!;
    if (confidence >= 0.6) return Colors.orange[600]!;
    return Colors.red[600]!;
  }

  /// Affiche un message d'erreur temporaire
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[600],
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Affiche une alerte d'urgence
  void _showUrgencyAlert(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red[600]),
            const SizedBox(width: 8),
            const Text('⚠️ Alerte d\'urgence'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('J\'ai compris'),
          ),
          ElevatedButton(
            onPressed: _callEmergencyServices,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
            ),
            child: const Text('Appeler les urgences'),
          ),
        ],
      ),
    );
  }

  /// Affiche le menu d'options
  void _showOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Historique des conversations'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Naviguer vers l'historique
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Préférences IA'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Naviguer vers les préférences
              },
            ),
            ListTile(
              leading: const Icon(Icons.clear),
              title: const Text('Effacer la conversation'),
              onTap: () {
                Navigator.pop(context);
                _clearConversation();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Active la saisie vocale (placeholder pour l'implémentation)
  void _toggleVoiceInput() {
    // TODO: Implémenter la saisie vocale
    _showError('Saisie vocale bientôt disponible');
  }

  /// Appelle les services d'urgence
  void _callEmergencyServices() {
    // TODO: Implémenter l'appel d'urgence
    _showError('Appel d\'urgence bientôt disponible');
  }

  /// Efface la conversation actuelle
  void _clearConversation() {
    setState(() {
      _messages.clear();
      _addWelcomeMessage();
    });
  }
}
