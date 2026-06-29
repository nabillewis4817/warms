import '../models/ordonnance.dart';
import 'api_client.dart';

/// Données spécifiques au tableau de bord patient et personnel : liste des
/// patients, statistiques du cabinet, badges de notification, ordonnances.
///
/// Chaque appel échoue silencieusement (renvoie une valeur vide) plutôt que
/// de bloquer l'écran d'accueil : ce sont des données secondaires, pas le
/// cœur de l'authentification.
class PatientService {
  PatientService._();
  static final PatientService instance = PatientService._();

  final _dio = ApiClient.instance.dio;

  Future<List<dynamic>> chargerPatients() async {
    try {
      final rep = await _dio.get('/patients/');
      final data = rep.data;
      if (data is List) return data;
      if (data is Map) return (data['results'] as List<dynamic>?) ?? [];
      return const [];
    } catch (_) {
      // Volontairement large (pas seulement DioException) : une erreur de
      // parsing/format ne doit pas non plus remonter et bloquer l'appelant.
      return const [];
    }
  }

  Future<Map<String, dynamic>?> chargerStats() async {
    try {
      final rep = await _dio.get('/statistiques/vue-generale/');
      return rep.data as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<Badges> chargerBadges() async {
    try {
      final rep = await _dio.get('/notifications/badges/');
      return Badges.fromJson(rep.data as Map<String, dynamic>);
    } catch (_) {
      return const Badges();
    }
  }

  /// Retourne l'identifiant du dossier patient de l'utilisateur connecté
  /// (utile pour les actions qui ciblent ce patient, ex. envoyer un avis).
  Future<int?> chargerIdPatientConnecte() async {
    try {
      final rep = await _dio.get('/patients/me/');
      final data = rep.data as Map<String, dynamic>;
      return data['id'] as int?;
    } catch (_) {
      return null;
    }
  }

  Future<List<Prescription>> chargerOrdonnances() async {
    try {
      final rep = await _dio.get('/prescriptions/me/');
      final liste = rep.data as List<dynamic>;
      return liste
          .map((e) => Prescription.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Envoie un avis de satisfaction simple (note + commentaire) pour le
  /// patient donné. Lance une [DioException] en cas d'échec, à charge de
  /// l'appelant d'afficher un message d'erreur adapté.
  Future<void> envoyerAvis({
    required int patientId,
    int note = 5,
    String commentaire = 'Merci pour la prise en charge.',
  }) async {
    await _dio.post('/avis/', data: {
      'patient': patientId,
      'note': note,
      'commentaire': commentaire,
    });
  }
}
