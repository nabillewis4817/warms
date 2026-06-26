/// Une ligne d'ordonnance (médicament + posologie) renvoyée par
/// `GET /prescriptions/me/`.
class Ordonnance {
  final String medicament;
  final String posologie;

  const Ordonnance({required this.medicament, required this.posologie});

  factory Ordonnance.fromJson(Map<String, dynamic> json) {
    return Ordonnance(
      medicament: (json['medicament'] ?? '').toString(),
      posologie: (json['posologie'] ?? '').toString(),
    );
  }
}

/// Compteurs de notifications en attente (rappels, messages, alertes critiques).
class Badges {
  final int rappel;
  final int message;
  final int critique;

  const Badges({this.rappel = 0, this.message = 0, this.critique = 0});

  factory Badges.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const {};
    return Badges(
      rappel: (data['rappel'] as int?) ?? 0,
      message: (data['message'] as int?) ?? 0,
      critique: (data['critique'] as int?) ?? 0,
    );
  }

  int get total => rappel + message + critique;
}
