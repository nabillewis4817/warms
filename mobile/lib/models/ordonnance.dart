import '../config/api_config.dart';

/// Une ligne de médicament au sein d'une [Prescription].
class LignePrescription {
  final String medicament;
  final String posologie;
  final String duree;
  final String remarques;

  const LignePrescription({
    required this.medicament,
    required this.posologie,
    required this.duree,
    required this.remarques,
  });

  factory LignePrescription.fromJson(Map<String, dynamic> json) {
    return LignePrescription(
      medicament: (json['medicament'] ?? '').toString(),
      posologie: (json['posologie'] ?? '').toString(),
      duree: (json['duree'] ?? '').toString(),
      remarques: (json['remarques'] ?? '').toString(),
    );
  }
}

/// Une ordonnance complète, telle que renvoyée par `GET /prescriptions/me/`.
class Prescription {
  final int id;
  final String titre;
  final String statut;
  final String praticienNom;
  final String notePraticien;
  final String conseils;
  final String recommandations;
  final List<LignePrescription> lignes;
  final DateTime? creeLe;

  const Prescription({
    required this.id,
    required this.titre,
    required this.statut,
    required this.praticienNom,
    required this.notePraticien,
    required this.conseils,
    required this.recommandations,
    required this.lignes,
    required this.creeLe,
  });

  factory Prescription.fromJson(Map<String, dynamic> json) {
    return Prescription(
      id: (json['id'] as num?)?.toInt() ?? 0,
      titre: (json['titre'] ?? '').toString(),
      statut: (json['statut'] ?? 'active').toString(),
      praticienNom: (json['praticien_nom'] ?? '').toString(),
      notePraticien: (json['note_praticien'] ?? '').toString(),
      conseils: (json['conseils'] ?? '').toString(),
      recommandations: (json['recommandations'] ?? '').toString(),
      lignes: ((json['lignes'] as List<dynamic>?) ?? [])
          .map((e) => LignePrescription.fromJson(e as Map<String, dynamic>))
          .toList(),
      creeLe: DateTime.tryParse((json['cree_le'] ?? '').toString()),
    );
  }

  String get urlPdf => '${ApiConfig.apiBaseUrl}/prescriptions/$id/pdf/';

  String get libelleStatut {
    switch (statut) {
      case 'terminee':
        return 'Terminée';
      case 'annulee':
        return 'Annulée';
      default:
        return 'Active';
    }
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
