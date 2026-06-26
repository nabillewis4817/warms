import '../models/notification_interne.dart';
import 'api_client.dart';

/// Notifications internes (`/notifications/`) : liste, marquage lu, badges
/// par niveau. Distinct de [NotificationService] (push Firebase/locales).
class NotificationsInternesService {
  NotificationsInternesService._();
  static final NotificationsInternesService instance = NotificationsInternesService._();

  final _dio = ApiClient.instance.dio;

  Future<List<NotificationInterne>> chargerNotifications() async {
    try {
      final rep = await _dio.get('/notifications/');
      final data = rep.data;
      final liste = data is Map ? (data['results'] as List<dynamic>? ?? []) : data as List<dynamic>;
      return liste.map((e) => NotificationInterne.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> marquerLu(int id) async {
    await _dio.post('/notifications/$id/marquer_lu/');
  }
}
