import '../models/avis.dart';
import 'api_client.dart';

/// Avis de satisfaction des patients (`/avis/avis/`).
class AvisService {
  AvisService._();
  static final AvisService instance = AvisService._();

  final _dio = ApiClient.instance.dio;

  /// Envoie un nouvel avis pour le patient connecté.
  Future<void> envoyerAvis({
    required String typeAvis,
    required int note,
    required String titre,
    required String commentaire,
    List<String> pointsNegatifs = const [],
  }) async {
    await _dio.post('/avis/avis/', data: {
      'type_avis': typeAvis,
      'note': note,
      'titre': titre,
      'commentaire': commentaire,
      'points_negatifs': pointsNegatifs,
    });
  }

  /// Charge les avis déjà laissés par le patient connecté.
  Future<List<Avis>> chargerMesAvis(int patientId) async {
    try {
      final rep = await _dio.get('/avis/avis/', queryParameters: {'patient_id': patientId});
      final data = rep.data;
      final liste = data is Map ? (data['results'] as List<dynamic>? ?? []) : data as List<dynamic>;
      return liste.map((e) => Avis.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return const [];
    }
  }
}
