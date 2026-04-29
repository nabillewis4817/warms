class RechercheIA {
  final int? id;
  final String query;
  final String plateforme;
  final List<RechercheResult> resultat;
  final DateTime timestamp;
  final Map<String, dynamic> contexte;

  RechercheIA({
    this.id,
    required this.query,
    required this.plateforme,
    required this.resultat,
    required this.timestamp,
    this.contexte = const {},
  });

  factory RechercheIA.fromJson(Map<String, dynamic> json) {
    return RechercheIA(
      id: json['id'],
      query: json['query'],
      plateforme: json['plateforme'],
      resultat: (json['resultat']['results'] as List<dynamic>?)
          ?.map((r) => RechercheResult.fromJson(r))
          .toList() ?? [],
      timestamp: DateTime.parse(json['timestamp']),
      contexte: Map<String, dynamic>.from(json['contexte'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'query': query,
      'plateforme': plateforme,
      'resultat': {'results': resultat.map((r) => r.toJson()).toList()},
      'timestamp': timestamp.toIso8601String(),
      'contexte': contexte,
    };
  }
}

class RechercheResult {
  final String titre;
  final String url;
  final String snippet;
  final String source;
  final String? date;
  final double pertinence;

  RechercheResult({
    required this.titre,
    required this.url,
    required this.snippet,
    required this.source,
    this.date,
    required this.pertinence,
  });

  factory RechercheResult.fromJson(Map<String, dynamic> json) {
    return RechercheResult(
      titre: json['titre'],
      url: json['url'],
      snippet: json['snippet'],
      source: json['source'],
      date: json['date'],
      pertinence: (json['pertinence'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'titre': titre,
      'url': url,
      'snippet': snippet,
      'source': source,
      'date': date,
      'pertinence': pertinence,
    };
  }
}
