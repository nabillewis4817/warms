import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  String? _fcmToken;
  bool _isInitialized = false;

  // Initialisation du service de notifications
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Demander les permissions de notification
      await _requestPermissions();

      // Initialiser les notifications locales
      await _initializeLocalNotifications();

      // Initialiser Firebase Messaging
      await _initializeFirebaseMessaging();

      _isInitialized = true;
      print('✅ Service de notifications initialisé');
    } catch (e) {
      print('❌ Erreur initialisation notifications: $e');
    }
  }

  Future<void> _requestPermissions() async {
    // Permission pour les notifications locales
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Permission pour les notifications push
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    print('🔔 Permission notifications: ${settings.authorizationStatus}');
  }

  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  Future<void> _initializeFirebaseMessaging() async {
    // Obtenir le token FCM
    _fcmToken = await _firebaseMessaging.getToken();
    print('📱 FCM Token: $_fcmToken');
    
    // Sauvegarder le token localement
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', _fcmToken!);

    // Écouter les messages en foreground
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Écouter les messages quand l'app est en background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Vérifier les messages au démarrage
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage);
    }

    // Écouter les changements de token
    _firebaseMessaging.onTokenRefresh(_handleTokenRefresh);
  }

  void _handleForegroundMessage(RemoteMessage message) {
    print('📨 Message reçu en foreground: ${message.notification?.title}');
    
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.android;

    if (notification != null && android != null) {
      _flutterLocalNotificationsPlugin.show(
        androidNotificationId: android.hashCode,
        notificationTitle: notification.title,
        notificationBody: notification.body,
        payload: message.data.toString(),
      );
    }
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    print('📱 Message ouvert depuis background/closed: ${message.notification?.title}');
    _navigateToNotificationScreen(message);
  }

  void _handleTokenRefresh(String token) {
    print('🔄 Token FCM rafraîchi: $token');
    _fcmToken = token;
    // TODO: Envoyer le nouveau token au serveur
  }

  void _onNotificationTapped(NotificationResponse response) {
    print('👆 Notification tapée: ${response.payload}');
    // TODO: Naviguer vers l'écran approprié
  }

  void _navigateToNotificationScreen(RemoteMessage message) {
    // Logique de navigation basée sur le type de notification
    final String? type = message.data['type'];
    
    switch (type) {
      case 'nouveau_message':
        // Naviguer vers l'écran de chat
        break;
      case 'rendez_vous':
        // Naviguer vers l'écran des rendez-vous
        break;
      case 'avis':
        // Naviguer vers l'écran des avis
        break;
      default:
        // Navigation par défaut
        break;
    }
  }

  // Envoyer une notification locale
  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'warms_channel',
      'WARMS Notifications',
      channelDescription: 'Notifications de l\'application WARMS',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      payload: payload,
      platformChannelSpecifics: platformChannelSpecifics,
    );
  }

  // Notifications médicales spécifiques
  Future<void> showRappelRendezVous({
    required String patientNom,
    required DateTime dateRdv,
  }) async {
    await showLocalNotification(
      id: 1001,
      title: '📅 Rappel de rendez-vous',
      body: 'Rendez-vous avec $patientNom le ${_formatDate(dateRdv)}',
      payload: 'rendez_vous',
    );
  }

  Future<void> showNouveauMessage({
    required String expediteur,
    required String message,
  }) async {
    await showLocalNotification(
      id: 2001,
      title: '💬 Nouveau message',
      body: '$expediteur: $message',
      payload: 'nouveau_message',
    );
  }

  Future<void> showAvisRecu({
    required int note,
    required String titre,
  }) async {
    await showLocalNotification(
      id: 3001,
      title: '⭐ Nouvel avis reçu',
      body: '$titre - Note: $note/5',
      payload: 'avis',
    );
  }

  Future<void> showAlerteUrgence({
    required String message,
  }) async {
    await showLocalNotification(
      id: 4001,
      title: '🚨 Alerte d\'urgence',
      body: message,
      payload: 'urgence',
    );
  }

  Future<void> showResultatAnalyse({
    required String typeAnalyse,
    required String resultat,
  }) async {
    await showLocalNotification(
      id: 5001,
      title: '📊 Résultat d\'analyse disponible',
      body: '$typeAnalyse: $resultat',
      payload: 'analyse_resultat',
    );
  }

  // Planifier des notifications
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      payload: payload,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidAllowWhileIdle: true,
    );
  }

  // Annuler une notification planifiée
  Future<void> cancelNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
  }

  // Annuler toutes les notifications
  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  // Obtenir les notifications pending
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
  }

  // Méthodes utilitaires
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} à ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String? get fcmToken => _fcmToken;

  bool get isInitialized => _isInitialized;
}
