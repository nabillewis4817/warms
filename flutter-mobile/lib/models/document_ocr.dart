class DocumentOCR {
  final int? id;
  final String? fichierOriginalUrl;
  final String? fichierTraiteUrl;
  final String texteExtrait;
  final Map<String, dynamic> metadonnees;
  final double confiance;
  final String plateforme;
  final DateTime creeLe;

  DocumentOCR({
    this.id,
    this.fichierOriginalUrl,
    this.fichierTraiteUrl,
    required this.texteExtrait,
    this.metadonnees = const {},
    required this.confiance,
    required this.plateforme,
    required this.creeLe,
  });

  factory DocumentOCR.fromJson(Map<String, dynamic> json) {
    return DocumentOCR(
      id: json['id'],
      fichierOriginalUrl: json['fichier_original'],
      fichierTraiteUrl: json['fichier_traite'],
      texteExtrait: json['texte_extrait'],
      metadonnees: Map<String, dynamic>.from(json['metadonnees'] ?? {}),
      confiance: (json['confiance'] as num).toDouble(),
      plateforme: json['plateforme'],
      creeLe: DateTime.parse(json['cree_le']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fichier_original': fichierOriginalUrl,
      'fichier_traite': fichierTraiteUrl,
      'texte_extrait': texteExtrait,
      'metadonnees': metadonnees,
      'confiance': confiance,
      'plateforme': plateforme,
      'cree_le': creeLe.toIso8601String(),
    };
  }
}

class DocumentInfo {
  final String? patientNom;
  final String? patientPrenom;
  final String? dateNaissance;
  final String? numeroDossier;
  final String typeDocument;
  final List<String> motsCles;

  DocumentInfo({
    this.patientNom,
    this.patientPrenom,
    this.dateNaissance,
    this.numeroDossier,
    required this.typeDocument,
    this.motsCles = const [],
  });

  factory DocumentInfo.fromJson(Map<String, dynamic> json) {
    return DocumentInfo(
      patientNom: json['patient_nom'],
      patientPrenom: json['patient_prenom'],
      dateNaissance: json['date_naissance'],
      numeroDossier: json['numero_dossier'],
      typeDocument: json['type_document'] ?? 'document_medical',
      motsCles: List<String>.from(json['mots_cles'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'patient_nom': patientNom,
      'patient_prenom': patientPrenom,
      'date_naissance': dateNaissance,
      'numero_dossier': numeroDossier,
      'type_document': typeDocument,
      'mots_cles': motsCles,
    };
  }
}
