/// Champs standardisés extraits d'un carnet patient physique.
class ChampsCarnet {
  static const String prenom        = 'prenom';
  static const String nom           = 'nom';
  static const String dateNaissance = 'date_naissance';
  static const String sexe          = 'sexe';
  static const String telephone     = 'telephone';
  static const String email         = 'email';
  static const String adresse       = 'adresse';
  static const String groupeSanguin = 'groupe_sanguin';
  static const String allergies     = 'allergies';

  static const List<String> tous = [
    prenom, nom, dateNaissance, sexe, telephone, email, adresse, groupeSanguin, allergies,
  ];

  static String label(String champ) {
    switch (champ) {
      case prenom:        return 'Prénom';
      case nom:           return 'Nom';
      case dateNaissance: return 'Date de naissance';
      case sexe:          return 'Sexe (M / F)';
      case telephone:     return 'Téléphone';
      case email:         return 'Email';
      case adresse:       return 'Adresse';
      case groupeSanguin: return 'Groupe sanguin';
      case allergies:     return 'Allergies';
      default:            return champ;
    }
  }
}

/// Résultat d'une analyse OCR d'un carnet physique.
class CarnetScanResult {
  /// Champs dont la valeur a été extraite par OCR.
  final Map<String, String> champsExtraits;

  /// Champs standard qui n'ont PAS été trouvés dans le texte OCR.
  final List<String> champsManquants;

  /// Texte brut retourné par MLKit (pour affichage debug / correction manuelle).
  final String texteOcr;

  const CarnetScanResult({
    required this.champsExtraits,
    required this.champsManquants,
    this.texteOcr = '',
  });

  bool get estValide =>
      champsExtraits.containsKey(ChampsCarnet.prenom) ||
      champsExtraits.containsKey(ChampsCarnet.nom);

  /// Score OCR de 0 à 100 basé sur les champs extraits.
  int get scoreConfiance {
    final total = ChampsCarnet.tous.length;
    return ((champsExtraits.length / total) * 100).round();
  }
}
