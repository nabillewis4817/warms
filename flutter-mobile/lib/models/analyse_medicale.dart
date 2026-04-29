class AnalyseMedicale {
  final int? id;
  final int? patientId;
  final String typeAnalyse;
  final Map<String, dynamic> donneesEntree;
  final AnalyseResultat resultat;
  final double confiance;
  final String plateforme;
  final DateTime creeLe;

  AnalyseMedicale({
    this.id,
    this.patientId,
    required this.typeAnalyse,
    required this.donneesEntree,
    required this.resultat,
    required this.confiance,
    required this.plateforme,
    required this.creeLe,
  });

  factory AnalyseMedicale.fromJson(Map<String, dynamic> json) {
    return AnalyseMedicale(
      id: json['id'],
      patientId: json['patient_id'],
      typeAnalyse: json['type_analyse'],
      donneesEntree: Map<String, dynamic>.from(json['donnees_entree']),
      resultat: AnalyseResultat.fromJson(json['resultat']),
      confiance: (json['confiance'] as num).toDouble(),
      plateforme: json['plateforme'],
      creeLe: DateTime.parse(json['cree_le']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'type_analyse': typeAnalyse,
      'donnees_entree': donneesEntree,
      'resultat': resultat.toJson(),
      'confiance': confiance,
      'plateforme': plateforme,
      'cree_le': creeLe.toIso8601String(),
    };
  }
}

class AnalyseResultat {
  final List<DiagnosticPossible> diagnosticsPossibles;
  final bool urgence;
  final double confiance;

  AnalyseResultat({
    required this.diagnosticsPossibles,
    required this.urgence,
    required this.confiance,
  });

  factory AnalyseResultat.fromJson(Map<String, dynamic> json) {
    return AnalyseResultat(
      diagnosticsPossibles: (json['diagnostic_possibles'] as List<dynamic>?)
          ?.map((d) => DiagnosticPossible.fromJson(d))
          .toList() ?? [],
      urgence: json['urgence'] ?? false,
      confiance: (json['confiance'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'diagnostic_possibles': diagnosticsPossibles.map((d) => d.toJson()).toList(),
      'urgence': urgence,
      'confiance': confiance,
    };
  }
}

class DiagnosticPossible {
  final String condition;
  final double probabilite;
  final List<String> symptomesAssocies;
  final List<String> recommandations;

  DiagnosticPossible({
    required this.condition,
    required this.probabilite,
    required this.symptomesAssocies,
    required this.recommandations,
  });

  factory DiagnosticPossible.fromJson(Map<String, dynamic> json) {
    return DiagnosticPossible(
      condition: json['condition'],
      probabilite: (json['probabilite'] as num).toDouble(),
      symptomesAssocies: List<String>.from(json['symptomes_associes'] ?? []),
      recommandations: List<String>.from(json['recommandations'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'condition': condition,
      'probabilite': probabilite,
      'symptomes_associes': symptomesAssocies,
      'recommandations': recommandations,
    };
  }
}
