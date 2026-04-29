import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/conversation_ia.dart';
import '../services/ia_service.dart';

class IAChatScreen extends StatefulWidget {
  final ConversationIA? conversationExistante;

  const IAChatScreen({Key? key, this.conversationExistante}) : super(key: key);

  @override
  _IAChatScreenState createState() => _IAChatScreenState();
}

class _IAChatScreenState extends State<IAChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  ConversationIA? _conversation;
  List<MessageIA> _messages = [];
  bool _isLoading = false;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _initialiserConversation();
  }

  Future<void> _initialiserConversation() async {
    if (widget.conversationExistante != null) {
      setState(() {
        _conversation = widget.conversationExistante;
        _messages = widget.conversationExistante!.messages;
      });
    } else {
      await _creerNouvelleConversation();
    }
  }

  Future<void> _creerNouvelleConversation() async {
    setState(() => _isLoading = true);
    
    try {
      final conversation = await IAService.creerConversation(
        contexte: {
          'specialite': 'medicale',
          'langue': 'fr',
          'mode': 'mobile'
        }
      );
      
      setState(() {
        _conversation = conversation;
        _messages = conversation.messages;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Impossible de créer la conversation: $e');
    }
  }

  Future<void> _envoyerMessage() async {
    if (_messageController.text.trim().isEmpty || _conversation == null) return;

    final messageText = _messageController.text.trim();
    _messageController.clear();
    
    // Ajouter le message utilisateur immédiatement
    final userMessage = MessageIA(
      contenu: messageText,
      typeMessage: 'user',
      timestamp: DateTime.now(),
    );
    
    setState(() {
      _messages.add(userMessage);
      _isTyping = true;
    });
    
    _scrollToBottom();

    try {
      final reponse = await IAService.envoyerMessage(
        conversationId: _conversation!.id,
        message: messageText,
      );

      setState(() {
        if (reponse['message_ia'] != null) {
          final iaMessage = MessageIA.fromJson(reponse['message_ia']);
          _messages.add(iaMessage);
        }
        _isTyping = false;
      });
      
      _scrollToBottom();
    } catch (e) {
      setState(() => _isTyping = false);
      _showErrorSnackBar('Erreur lors de l\'envoi du message: $e');
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

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {},
          textColor: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.smart_toy,
                color: Colors.blue[800],
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Assistant Médical WARMS',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _isTyping ? 'En train d\'écrire...' : 'Prêt à vous aider',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showInfoDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length && _isTyping) {
                        return _buildTypingIndicator();
                      }
                      final message = _messages[index];
                      return _buildMessageBubble(message);
                    },
                  ),
                ),
                _buildMessageInput(),
              ],
            ),
    );
  }

  Widget _buildMessageBubble(MessageIA message) {
    final isUser = message.isUser;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.smart_toy,
                color: Colors.blue[800],
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? Colors.blue[600] : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.contenu,
                    style: TextStyle(
                      color: isUser ? Colors.white : Colors.black87,
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      color: isUser ? Colors.white70 : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Colors.grey[300],
              child: Icon(
                Icons.person,
                color: Colors.grey[600],
                size: 20,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.smart_toy,
              color: Colors.blue[800],
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
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
              children: [
                _buildDot(0),
                const SizedBox(width: 4),
                _buildDot(1),
                const SizedBox(width: 4),
                _buildDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: Colors.grey[400],
        shape: BoxShape.circle,
      ),
    );
  }

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
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Tapez votre message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _envoyerMessage(),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.blue[600],
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.send,
                  color: Colors.white,
                ),
                onPressed: _envoyerMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'À l\'instant';
    } else if (difference.inHours < 1) {
      return 'Il y a ${difference.inMinutes} min';
    } else if (difference.inDays < 1) {
      return 'Il y a ${difference.inHours}h';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assistant Médical WARMS'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🤖 Votre assistant médical intelligent'),
            SizedBox(height: 12),
            Text('Capacités:'),
            SizedBox(height: 8),
            BulletPoint('• Analyse de symptômes'),
            BulletPoint('• Suggestions de traitements'),
            BulletPoint('• Vérification d\'interactions'),
            BulletPoint('• Recherche médicale'),
            SizedBox(height: 12),
            Text('⚠️ Ne remplace pas un avis médical professionnel'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }
}

class BulletPoint extends StatelessWidget {
  final String text;
  
  const BulletPoint(this.text, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 4),
      child: Text(text),
    );
  }
}
