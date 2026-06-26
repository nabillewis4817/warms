/// Préférences de notification d'un utilisateur (email/SMS/push/rappels).
class PreferencesNotifications {
  final bool email;
  final bool sms;
  final bool push;
  final bool rappelsAuto;

  const PreferencesNotifications({
    this.email = true,
    this.sms = false,
    this.push = true,
    this.rappelsAuto = true,
  });

  factory PreferencesNotifications.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const {};
    return PreferencesNotifications(
      email: data['email'] == null ? true : data['email'] == true,
      sms: data['sms'] == true,
      push: data['push'] == null ? true : data['push'] == true,
      rappelsAuto:
          data['rappels_auto'] == null ? true : data['rappels_auto'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'email': email,
        'sms': sms,
        'push': push,
        'rappels_auto': rappelsAuto,
      };

  PreferencesNotifications copyWith({
    bool? email,
    bool? sms,
    bool? push,
    bool? rappelsAuto,
  }) {
    return PreferencesNotifications(
      email: email ?? this.email,
      sms: sms ?? this.sms,
      push: push ?? this.push,
      rappelsAuto: rappelsAuto ?? this.rappelsAuto,
    );
  }
}

/// Profil de l'utilisateur connecté, qu'il soit patient ou personnel.
///
/// Reflète la réponse de `GET /personnel/me/`.
class Utilisateur {
  final String prenom;
  final String nom;
  final String role;
  final String email;
  final String telephone;
  final String qrCode;
  final String photoProfil;
  final String langueInterface;
  final bool modeSombre;
  final PreferencesNotifications preferencesNotifications;

  const Utilisateur({
    required this.prenom,
    required this.nom,
    required this.role,
    required this.email,
    required this.telephone,
    required this.qrCode,
    required this.photoProfil,
    required this.langueInterface,
    required this.modeSombre,
    required this.preferencesNotifications,
  });

  /// Utilisateur "vide" utilisé avant le premier chargement du profil.
  factory Utilisateur.vide() => const Utilisateur(
        prenom: '',
        nom: '',
        role: '',
        email: '',
        telephone: '',
        qrCode: '',
        photoProfil: '',
        langueInterface: 'fr',
        modeSombre: false,
        preferencesNotifications: PreferencesNotifications(),
      );

  factory Utilisateur.fromJson(Map<String, dynamic> json) {
    return Utilisateur(
      prenom: (json['prenom'] ?? '').toString(),
      nom: (json['nom'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      telephone: (json['telephone'] ?? '').toString(),
      qrCode: (json['qr_code'] ?? '').toString(),
      photoProfil: (json['photo_profil'] ?? '').toString(),
      langueInterface: (json['langue_interface'] as String?) == 'en' ? 'en' : 'fr',
      modeSombre: json['mode_sombre'] == true,
      preferencesNotifications: PreferencesNotifications.fromJson(
        (json['preferences_notifications'] as Map?)?.cast<String, dynamic>(),
      ),
    );
  }

  String get nomComplet => '$prenom $nom'.trim();

  bool get estPatient => role == 'patient';

  /// Initiales (ex: "Jean Dupont" -> "JD") pour l'avatar de repli.
  String get initiales {
    final p = prenom.isNotEmpty ? prenom[0] : '';
    final n = nom.isNotEmpty ? nom[0] : '';
    final valeur = '$p$n'.toUpperCase();
    return valeur.isEmpty ? '?' : valeur;
  }

  Utilisateur copyWith({
    String? langueInterface,
    bool? modeSombre,
    PreferencesNotifications? preferencesNotifications,
  }) {
    return Utilisateur(
      prenom: prenom,
      nom: nom,
      role: role,
      email: email,
      telephone: telephone,
      qrCode: qrCode,
      photoProfil: photoProfil,
      langueInterface: langueInterface ?? this.langueInterface,
      modeSombre: modeSombre ?? this.modeSombre,
      preferencesNotifications:
          preferencesNotifications ?? this.preferencesNotifications,
    );
  }
}
