import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../config/api_config.dart';
import '../../models/message.dart';
import '../../services/conversation_service.dart';
import '../../services/secure_storage_service.dart';
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
  final _scrollCtrl = ScrollController();

  int? _conversationId;
  List<MessageConversation> _messages = [];
  bool _enChargement = true;
  bool _envoiEnCours = false;
  bool _wsConnecte = false;
  String _erreur = '';

  WebSocketChannel? _ws;
  Timer? _wsReconnect;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _initialiser();
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    _wsReconnect?.cancel();
    _pollTimer?.cancel();
    _ws?.sink.close();
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
      _connecterWs(id);
      // Polling de secours toutes les 20s si WS indisponible
      _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) {
        if (!_wsConnecte) _rafraichir(silencieux: true);
      });
      _defilerEnBas();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _erreur = 'Impossible de charger la conversation.';
        _enChargement = false;
      });
    }
  }

  Future<void> _rafraichir({bool silencieux = false}) async {
    final id = _conversationId;
    if (id == null) return;
    try {
      final messages = await _service.chargerMessages(id);
      if (!mounted) return;
      final nouveaux = messages.length > _messages.length;
      setState(() => _messages = messages);
      if (nouveaux) _defilerEnBas();
    } catch (_) {}
  }

  void _connecterWs(int conversationId) async {
    final token = await SecureStorageService.instance.lireAccessToken();
    if (token == null || token.isEmpty) return;

    final wsBase = ApiConfig.apiBaseUrl
        .replaceFirst(RegExp(r'^http://'), 'ws://')
        .replaceFirst(RegExp(r'^https://'), 'wss://')
        .replaceFirst(RegExp(r'/api/v1/?$'), '');
    final uri = Uri.tryParse('$wsBase/ws/chat/$conversationId/?token=$token');
    if (uri == null) return;

    try {
      _ws = WebSocketChannel.connect(uri);
      _ws!.stream.listen(
        (data) {
          if (!mounted) return;
          try {
            final decoded = json.decode(data as String) as Map<String, dynamic>;
            final msgJson = decoded['message'] as Map<String, dynamic>?;
            if (msgJson != null) {
              // Le payload WS utilise auteur_username (pas envoyeur: moi/autre).
              // On recharge les messages via REST pour conserver le flag deMoi
              // exact calculé côté serveur. Le léger aller-retour est invisible.
              final incomingId = msgJson['id'] as int?;
              if (incomingId != null && !_messages.any((m) => m.id == incomingId)) {
                _rafraichir(silencieux: true);
              }
            }
          } catch (_) {}
        },
        onDone: () {
          if (!mounted) return;
          setState(() => _wsConnecte = false);
          _ws = null;
          _wsReconnect?.cancel();
          _wsReconnect = Timer(const Duration(seconds: 5), () => _connecterWs(conversationId));
        },
        onError: (_) {
          _ws?.sink.close();
        },
        cancelOnError: true,
      );
      if (mounted) setState(() => _wsConnecte = true);
    } catch (_) {
      // WS unavailable - polling covers it
    }
  }

  void _defilerEnBas() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _envoyer() async {
    final texte = _messageCtrl.text.trim();
    final conversationId = _conversationId;
    if (texte.isEmpty || conversationId == null) return;

    setState(() => _envoiEnCours = true);
    _messageCtrl.clear();
    try {
      await _service.envoyerMessage(conversationId, texte);
      // If WS is connected, the new message arrives via the socket.
      // If not, reload to get our own message reflected.
      if (!_wsConnecte) await _rafraichir(silencieux: true);
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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Icon(
              _wsConnecte ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              color: _wsConnecte ? WarmsTheme.warmsSuccess : WarmsTheme.warmsGray,
              size: 20,
            ),
          ),
        ],
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
      controller: _scrollCtrl,
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
