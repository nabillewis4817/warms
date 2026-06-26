/// Une notification interne (rappel, message, alerte critique...).
///
/// Reflète `GET /notifications/`.
class NotificationInterne {
  final int id;
  final String titre;
  final String contenu;
  final String niveau;
  final bool lu;
  final DateTime creeLe;

  const NotificationInterne({
    required this.id,
    required this.titre,
    required this.contenu,
    required this.niveau,
    required this.lu,
    required this.creeLe,
  });

  factory NotificationInterne.fromJson(Map<String, dynamic> json) {
    return NotificationInterne(
      id: json['id'] as int,
      titre: (json['titre'] ?? '').toString(),
      contenu: (json['contenu'] ?? '').toString(),
      niveau: (json['niveau'] ?? 'info').toString(),
      lu: json['lu'] == true,
      creeLe: json['cree_le'] != null
          ? DateTime.parse(json['cree_le'].toString())
          : DateTime.now(),
    );
  }
}
