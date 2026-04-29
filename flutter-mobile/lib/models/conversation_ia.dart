class ConversationIA {
  final String id;
  final String plateforme;
  final DateTime creeLe;
  final DateTime modifieLe;
  final Map<String, dynamic> contexte;
  final List<MessageIA> messages;

  ConversationIA({
    required this.id,
    required this.plateforme,
    required this.creeLe,
    required this.modifieLe,
    required this.contexte,
    this.messages = const [],
  });

  factory ConversationIA.fromJson(Map<String, dynamic> json) {
    return ConversationIA(
      id: json['id'],
      plateforme: json['plateforme'],
      creeLe: DateTime.parse(json['cree_le']),
      modifieLe: DateTime.parse(json['modifie_le']),
      contexte: Map<String, dynamic>.from(json['contexte'] ?? {}),
      messages: (json['messages'] as List<dynamic>?)
          ?.map((m) => MessageIA.fromJson(m))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'plateforme': plateforme,
      'cree_le': creeLe.toIso8601String(),
      'modifie_le': modifieLe.toIso8601String(),
      'contexte': contexte,
      'messages': messages.map((m) => m.toJson()).toList(),
    };
  }
}

class MessageIA {
  final int? id;
  final String contenu;
  final String typeMessage; // 'user' ou 'ia'
  final DateTime timestamp;
  final Map<String, dynamic> metadonnees;

  MessageIA({
    this.id,
    required this.contenu,
    required this.typeMessage,
    required this.timestamp,
    this.metadonnees = const {},
  });

  factory MessageIA.fromJson(Map<String, dynamic> json) {
    return MessageIA(
      id: json['id'],
      contenu: json['contenu'],
      typeMessage: json['type_message'],
      timestamp: DateTime.parse(json['timestamp']),
      metadonnees: Map<String, dynamic>.from(json['metadonnees'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'contenu': contenu,
      'type_message': typeMessage,
      'timestamp': timestamp.toIso8601String(),
      'metadonnees': metadonnees,
    };
  }

  bool get isUser => typeMessage == 'user';
  bool get isIA => typeMessage == 'ia';
}
