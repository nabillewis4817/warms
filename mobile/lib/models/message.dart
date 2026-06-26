/// Un message échangé dans une conversation avec le cabinet.
///
/// Reflète la réponse de `GET /conversations/{id}/messages/`.
class MessageConversation {
  final int id;
  final String contenu;
  final DateTime horodatage;
  final bool deMoi;
  final bool estLu;

  const MessageConversation({
    required this.id,
    required this.contenu,
    required this.horodatage,
    required this.deMoi,
    required this.estLu,
  });

  factory MessageConversation.fromJson(Map<String, dynamic> json) {
    return MessageConversation(
      id: json['id'] as int,
      contenu: (json['contenu'] ?? '').toString(),
      horodatage: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'].toString())
          : DateTime.now(),
      deMoi: json['envoyeur'] == 'moi',
      estLu: json['est_lu'] == true,
    );
  }
}
