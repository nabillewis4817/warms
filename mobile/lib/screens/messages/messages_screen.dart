import 'package:flutter/material.dart';

import '../../models/message.dart';
import '../../services/conversation_service.dart';
import '../../themes/warms_theme.dart';
import '../../widgets/skeleton_box.dart';

/// Conversation texte avec le cabinet.
///
/// Résout (ou crée) automatiquement la conversation du patient au premier
/// affichage, affiche les messages en bulles, et permet d'en envoyer de
/// nouveaux — une vraie boîte d'envoi, absente de l'ancienne fenêtre de
/// dialogue en lecture seule qu'elle remplace.
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _service = ConversationService.instance;
  final _messageCtrl = TextEditingController();

  int? _conversationId;
  List<MessageConversation> _messages = [];
  bool _enChargement = true;
  bool _envoiEnCours = false;
  String _erreur = '';

  @override
  void initState() {
    super.initState();
    _initialiser();
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _initialiser() async {
    try {
      final id = await _service.obtenirOuCreerConversation();
      final messages = await _service.chargerMessages(id);
      await _service.marquerLus(id);
      if (!mounted) return;
      setState(() {
        _conversationId = id;
        _messages = messages;
        _enChargement = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _erreur = 'Impossible de charger la conversation.';
        _enChargement = false;
      });
    }
  }

  Future<void> _envoyer() async {
    final texte = _messageCtrl.text.trim();
    final conversationId = _conversationId;
    if (texte.isEmpty || conversationId == null) return;

    setState(() => _envoiEnCours = true);
    _messageCtrl.clear();
    try {
      await _service.envoyerMessage(conversationId, texte);
      final messages = await _service.chargerMessages(conversationId);
      if (!mounted) return;
      setState(() => _messages = messages);
    } catch (_) {
      if (!mounted) return;
      setState(() => _erreur = "Échec de l'envoi du message.");
    } finally {
      if (mounted) setState(() => _envoiEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WarmsTheme.warmsBg,
      appBar: AppBar(
        title: const Text('Messages du cabinet'),
        backgroundColor: WarmsTheme.warmsCard,
      ),
      body: Column(
        children: [
          Expanded(child: _corps()),
          if (_erreur.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(_erreur, style: const TextStyle(color: WarmsTheme.warmsError)),
            ),
          _zoneSaisie(),
        ],
      ),
    );
  }

  Widget _corps() {
    if (_enChargement) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: SkeletonBulles(),
      );
    }
    if (_messages.isEmpty) {
      return Center(
        child: Text('Aucun message pour le moment', style: TextStyle(color: WarmsTheme.warmsGray)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) => _bulle(_messages[index]),
    );
  }

  Widget _bulle(MessageConversation message) {
    final aMoi = message.deMoi;
    return Align(
      alignment: aMoi ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: aMoi ? WarmsTheme.warmsAccent : WarmsTheme.warmsCard,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: WarmsTheme.warmsBlue.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Text(
          message.contenu,
          style: TextStyle(color: aMoi ? Colors.white : WarmsTheme.warmsNavy),
        ),
      ),
    );
  }

  Widget _zoneSaisie() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      decoration: BoxDecoration(
        color: WarmsTheme.warmsCard,
        boxShadow: [BoxShadow(color: WarmsTheme.warmsBlue.withValues(alpha: 0.08), blurRadius: 10)],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageCtrl,
                decoration: InputDecoration(
                  hintText: 'Écrire un message...',
                  filled: true,
                  fillColor: WarmsTheme.warmsBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                ),
                onSubmitted: (_) => _envoyer(),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: const BoxDecoration(color: WarmsTheme.warmsAccent, shape: BoxShape.circle),
              child: IconButton(
                onPressed: _envoiEnCours ? null : _envoyer,
                icon: _envoiEnCours
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
