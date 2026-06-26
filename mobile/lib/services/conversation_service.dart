import '../models/message.dart';
import 'api_client.dart';

/// Conversation texte avec le cabinet (distincte du chat IA — voir
/// [IAChatScreen]/[EnhancedChatScreen] qui parlent à l'assistant Claude,
/// pas au personnel du cabinet).
class ConversationService {
  ConversationService._();
  static final ConversationService instance = ConversationService._();

  final _dio = ApiClient.instance.dio;

  /// Retourne l'identifiant de la conversation du patient avec le cabinet,
  /// en la créant si elle n'existe pas encore.
  Future<int> obtenirOuCreerConversation() async {
    final rep = await _dio.get('/conversations/');
    final conversations = rep.data as List<dynamic>;
    if (conversations.isNotEmpty) {
      return (conversations.first as Map<String, dynamic>)['id'] as int;
    }

    final creation = await _dio.post('/conversations/', data: {
      'titre': 'Ma conversation avec le cabinet',
      'type_conversation': 'patient',
    });
    return (creation.data as Map<String, dynamic>)['id'] as int;
  }

  Future<List<MessageConversation>> chargerMessages(int conversationId) async {
    final rep = await _dio.get('/conversations/$conversationId/messages/');
    final liste = rep.data as List<dynamic>;
    return liste
        .map((e) => MessageConversation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> marquerLus(int conversationId) {
    return _dio.post('/conversations/$conversationId/marquer_lus/');
  }

  Future<void> envoyerMessage(int conversationId, String contenu) {
    return _dio.post(
      '/conversations/$conversationId/envoyer_message/',
      data: {'contenu': contenu},
    );
  }
}
