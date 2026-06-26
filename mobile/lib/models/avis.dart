/// Un avis de satisfaction laissé par le patient.
///
/// Reflète `GET/POST /avis/avis/`.
class Avis {
  final int id;
  final String typeAvis;
  final int note;
  final String titre;
  final String commentaire;
  final bool aReponse;
  final String reponsePersonnel;
  final DateTime creeLe;

  const Avis({
    required this.id,
    required this.typeAvis,
    required this.note,
    required this.titre,
    required this.commentaire,
    required this.aReponse,
    required this.reponsePersonnel,
    required this.creeLe,
  });

  factory Avis.fromJson(Map<String, dynamic> json) {
    return Avis(
      id: json['id'] as int,
      typeAvis: (json['type_avis'] ?? 'general').toString(),
      note: json['note'] as int? ?? 0,
      titre: (json['titre'] ?? '').toString(),
      commentaire: (json['commentaire'] ?? '').toString(),
      aReponse: json['a_reponse'] == true,
      reponsePersonnel: (json['reponse_personnel'] ?? '').toString(),
      creeLe: json['cree_le'] != null
          ? DateTime.parse(json['cree_le'].toString())
          : DateTime.now(),
    );
  }
}

/// Les types d'avis acceptés par le backend (`Avis.TypeAvis`).
class TypeAvis {
  static const consultation = 'consultation';
  static const traitement = 'traitement';
  static const accueil = 'accueil';
  static const installations = 'installations';
  static const personnel = 'personnel';
  static const general = 'general';

  static const Map<String, String> libelles = {
    consultation: 'Consultation',
    traitement: 'Traitement',
    accueil: 'Accueil',
    installations: 'Installations',
    personnel: 'Personnel',
    general: 'Général',
  };
}
