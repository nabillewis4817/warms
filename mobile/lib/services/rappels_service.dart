import 'api_client.dart';
import 'notification_service.dart';

class Rappel {
  final int id;
  final String titre;
  final String message;
  final DateTime dateHeure;
  final String recurrence;
  final bool actif;

  const Rappel({
    required this.id,
    required this.titre,
    required this.message,
    required this.dateHeure,
    required this.recurrence,
    required this.actif,
  });

  factory Rappel.fromJson(Map<String, dynamic> json) {
    return Rappel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      titre: (json['titre'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      dateHeure: DateTime.parse(json['date_heure'] as String).toLocal(),
      recurrence: (json['recurrence'] ?? 'aucune').toString(),
      actif: json['actif'] as bool? ?? true,
    );
  }

  String get libelleRecurrence {
    switch (recurrence) {
      case 'quotidien':
        return 'Tous les jours';
      case 'hebdomadaire':
        return 'Toutes les semaines';
      case 'mensuel':
        return 'Tous les mois';
      default:
        return 'Une seule fois';
    }
  }
}

/// CRUD des rappels personnalisables + synchronisation de la notification
/// locale planifiée associée (créée/mise à jour/annulée en même temps que
/// le rappel côté backend, pour qu'elle survive même hors-ligne).
class RappelsService {
  RappelsService._();
  static final RappelsService instance = RappelsService._();

  final _dio = ApiClient.instance.dio;
  final _notifications = NotificationService();

  Future<List<Rappel>> lister() async {
    try {
      final rep = await _dio.get('/rappels/');
      final data = rep.data;
      final liste = data is List ? data : (data['results'] as List<dynamic>? ?? []);
      return liste.map((e) => Rappel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<Rappel> creer({
    required String titre,
    required String message,
    required DateTime dateHeure,
    required String recurrence,
  }) async {
    final rep = await _dio.post('/rappels/', data: {
      'titre': titre,
      'message': message,
      'date_heure': dateHeure.toUtc().toIso8601String(),
      'recurrence': recurrence,
    });
    final rappel = Rappel.fromJson(rep.data as Map<String, dynamic>);
    await _notifications.planifierRappel(
      id: rappel.id,
      titre: rappel.titre,
      message: rappel.message,
      quand: rappel.dateHeure,
      recurrence: rappel.recurrence,
    );
    return rappel;
  }

  Future<void> supprimer(int id) async {
    await _dio.delete('/rappels/$id/');
    await _notifications.cancelNotification(id);
  }

  Future<Rappel> basculerActif(Rappel rappel) async {
    final rep = await _dio.patch('/rappels/${rappel.id}/', data: {'actif': !rappel.actif});
    final maj = Rappel.fromJson(rep.data as Map<String, dynamic>);
    if (maj.actif) {
      await _notifications.planifierRappel(
        id: maj.id,
        titre: maj.titre,
        message: maj.message,
        quand: maj.dateHeure,
        recurrence: maj.recurrence,
      );
    } else {
      await _notifications.cancelNotification(maj.id);
    }
    return maj;
  }

  /// Reprogramme localement tous les rappels actifs : à appeler à l'ouverture
  /// de l'écran des rappels, pour ré-aligner les notifications natives avec
  /// le backend (ex: après réinstallation de l'app).
  Future<void> resynchroniser(List<Rappel> rappels) async {
    for (final rappel in rappels.where((r) => r.actif)) {
      await _notifications.planifierRappel(
        id: rappel.id,
        titre: rappel.titre,
        message: rappel.message,
        quand: rappel.dateHeure,
        recurrence: rappel.recurrence,
      );
    }
  }
}
