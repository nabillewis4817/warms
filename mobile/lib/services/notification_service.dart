import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:timezone/timezone.dart' as tz;

import 'api_client.dart';

/**
 * Service de notifications pour WARMS Mobile
 * 
 * Ce service gère les notifications locales et push pour l'application mobile.
 * Il inclut la configuration Firebase, les notifications locales, et la gestion
 * des permissions.
 * 
 * @author WARMS Team
 * @version 1.0.0
 */
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal() {
    _initializeNotifications();
  }

  /// Instance de Flutter Local Notifications
  final FlutterLocalNotificationsPlugin _notifications = 
      FlutterLocalNotificationsPlugin();
  
  /// Instance de Firebase Messaging
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  
  /// Stockage sécurisé pour les tokens
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  /// Stream controller pour les notifications reçues
  final StreamController<RemoteMessage> _messageStreamController = 
      StreamController<RemoteMessage>.broadcast();
  
  /// Stream des messages reçus
  Stream<RemoteMessage> get messageStream => _messageStreamController.stream;
  
  /// Token FCM actuel
  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  /**
   * Initialise les notifications locales et Firebase
   */
  Future<void> _initializeNotifications() async {
    try {
      // Configuration des notifications locales Android
      const AndroidInitializationSettings androidSettings = 
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      // Configuration des notifications iOS
      const DarwinInitializationSettings iosSettings = 
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      
      // Configuration globale
      const InitializationSettings settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      
      await _notifications.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );
      
      // Initialiser Firebase Messaging
      await _initializeFirebaseMessaging();
      
      if (kDebugMode) {
        print('🔔 Service de notifications initialisé avec succès');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de l\'initialisation des notifications: $e');
      }
    }
  }

  /**
   * Initialise Firebase Messaging
   */
  Future<void> _initializeFirebaseMessaging() async {
    try {
      // Demander la permission pour les notifications
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (kDebugMode) {
        print('📱 Permissions notifications: ${settings.authorizationStatus}');
      }

      // Obtenir le token FCM
      _fcmToken = await _firebaseMessaging.getToken();
      await _storage.write(key: 'fcm_token', value: _fcmToken ?? '');
      
      if (kDebugMode) {
        print('🔑 Token FCM: $_fcmToken');
      }

      // Écouter les changements de token
      _firebaseMessaging.onTokenRefresh.listen((token) {
        _fcmToken = token;
        _storage.write(key: 'fcm_token', value: token);
        if (kDebugMode) {
          print('🔄 Token FCM rafraîchi: $token');
        }
        // Si une session est active, on renvoie immédiatement le nouveau
        // jeton (sinon le backend continuerait à pousser vers l'ancien).
        envoyerTokenAuServeur();
      });

      // Configurer les handlers pour les messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
      
      // Gérer les messages en arrière-plan (terminé)
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur Firebase Messaging: $e');
      }
    }
  }

  /// Envoie le jeton FCM courant au backend pour que le serveur puisse
  /// pousser de vraies notifications (nouveaux messages, alertes...) vers
  /// cet appareil. À appeler après une connexion réussie et après une
  /// restauration de session, en plus de l'appel automatique sur
  /// rafraîchissement de jeton (voir [onTokenRefresh] ci-dessus).
  ///
  /// Échoue silencieusement si aucune session n'est active ou si le réseau
  /// est indisponible : ce n'est jamais bloquant pour le reste de l'app.
  Future<void> envoyerTokenAuServeur() async {
    try {
      _fcmToken ??= await _firebaseMessaging.getToken();
      final token = _fcmToken;
      if (token == null || token.isEmpty) return;

      await ApiClient.instance.dio.post(
        '/personnel/me/fcm-token/',
        data: {'fcm_token': token},
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Wam's: envoi du jeton FCM au serveur impossible: $e");
      }
    }
  }

  /**
   * Gère les messages reçus lorsque l'app est en premier plan
   */
  void _handleForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      print('📨 Message reçu en premier plan: ${message.notification?.title}');
    }

    // Afficher la notification locale
    _showLocalNotification(
      title: message.notification?.title ?? "Wam's",
      body: message.notification?.body ?? 'Nouveau message',
      payload: message.data.toString(),
    );

    // Diffuser le message pour les autres parties de l'app
    _messageStreamController.add(message);
  }

  /**
   * Gère les messages lorsque l'utilisateur ouvre l'app depuis une notification
   */
  void _handleMessageOpenedApp(RemoteMessage message) {
    if (kDebugMode) {
      print('📂 Message ouvert depuis notification: ${message.notification?.title}');
    }
    
    _messageStreamController.add(message);
  }

  /**
   * Affiche une notification locale
   */
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'warms_channel',
      "Wam's Notifications",
      channelDescription: "Notifications médicales Wam's",
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF1E4DB7),
      enableLights: true,
      ledColor: Color(0xFF1E4DB7),
      ledOnMs: 1000,
      ledOffMs: 500,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notification_sound'),
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'notification_sound.aiff',
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: payload,
    );
  }

  /**
   * Gère le clic sur une notification
   */
  void _onNotificationTapped(NotificationResponse response) {
    if (kDebugMode) {
      print('👆 Notification cliquée: ${response.payload}');
    }
    
    // TODO: Naviguer vers la page appropriée selon le payload
    // Exemple: si payload contient "type:appointment", naviguer vers les rendez-vous
  }

  /**
   * Envoie une notification de rappel de rendez-vous
   */
  Future<void> sendAppointmentReminder({
    required String patientName,
    required DateTime appointmentTime,
    required String location,
  }) async {
    final timeFormatted = '${appointmentTime.hour.toString().padLeft(2, '0')}:${appointmentTime.minute.toString().padLeft(2, '0')}';
    
    await _showLocalNotification(
      title: '📅 Rappel de rendez-vous',
      body: 'Rendez-vous avec $patientName à $timeFormatted - $location',
      payload: 'type:appointment;patient:$patientName',
    );
  }

  /**
   * Envoie une notification de médicament
   */
  Future<void> sendMedicationReminder({
    required String medicationName,
    required String dosage,
  }) async {
    await _showLocalNotification(
      title: '💊 Prise de médicament',
      body: 'Il est temps de prendre $medicationName - $dosage',
      payload: 'type:medication;med:$medicationName',
    );
  }

  /**
   * Envoie une notification de message médical
   */
  Future<void> sendMedicalMessage({
    required String senderName,
    required String message,
  }) async {
    await _showLocalNotification(
      title: '📨 Message médical',
      body: '$senderName: $message',
      payload: 'type:message;sender:$senderName',
    );
  }

  /**
   * Envoie une notification d'urgence
   */
  Future<void> sendUrgentAlert({
    required String alertType,
    required String description,
  }) async {
    await _showLocalNotification(
      title: '🚨 Alerte d\'urgence',
      body: '$alertType - $description',
      payload: 'type:urgent;alert:$alertType',
    );
  }

  /**
   * Planifie une notification récurrente
   */
  Future<void> scheduleRecurringNotification({
    required int id,
    required String title,
    required String body,
    required TimeOfDay scheduledTime,
    required RepeatInterval repeatInterval,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'warms_recurring',
      "Wam's Recurring",
      channelDescription: "Notifications récurrentes Wam's",
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF1E4DB7),
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: _nextInstanceOfTime(scheduledTime),
      notificationDetails: notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /**
   * Calcule la prochaine occurrence d'une heure spécifique
   */
  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
      0,
    );
    
    // Si l'heure est déjà passée aujourd'hui, planifier pour demain
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  /// Demande la permission d'afficher des notifications (obligatoire sur
  /// Android 13+ ; no-op silencieux ailleurs). À appeler avant de planifier
  /// un premier rappel.
  Future<void> demanderPermissionLocale() async {
    try {
      await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (e) {
      if (kDebugMode) debugPrint("Wam's: permission notifications locale refusée/indisponible: $e");
    }
  }

  /// Planifie un rappel personnalisable (titre + message libres) à une date
  /// et heure précises, avec une récurrence au choix.
  ///
  /// Contrairement à [scheduleRecurringNotification] (toujours quotidienne,
  /// basée sur une [TimeOfDay] seule), cette méthode part d'une [DateTime]
  /// complète : nécessaire pour une récurrence hebdomadaire/mensuelle, qui
  /// doit retenir le jour de la semaine ou le jour du mois choisi.
  Future<void> planifierRappel({
    required int id,
    required String titre,
    required String message,
    required DateTime quand,
    required String recurrence,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'warms_rappels',
      "Wam's Rappels",
      channelDescription: 'Rappels personnalisables programmés par l\'utilisateur',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF1E4DB7),
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const notificationDetails = NotificationDetails(android: androidDetails, iOS: iosDetails);

    final tz.TZDateTime cible = _prochaineOccurrence(quand, recurrence);
    DateTimeComponents? composantes;
    switch (recurrence) {
      case 'quotidien':
        composantes = DateTimeComponents.time;
        break;
      case 'hebdomadaire':
        composantes = DateTimeComponents.dayOfWeekAndTime;
        break;
      case 'mensuel':
        composantes = DateTimeComponents.dayOfMonthAndTime;
        break;
      default:
        composantes = null; // 'aucune' : une seule occurrence, pas de répétition.
    }

    await _notifications.zonedSchedule(
      id: id,
      title: titre,
      body: message.isEmpty ? titre : message,
      scheduledDate: cible,
      notificationDetails: notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: composantes,
    );
  }

  /// Si la date demandée est déjà passée (ex: rappel quotidien créé après
  /// l'heure cible du jour), avance d'une période pour que la première
  /// occurrence programmée soit bien dans le futur.
  tz.TZDateTime _prochaineOccurrence(DateTime quand, String recurrence) {
    var cible = tz.TZDateTime(tz.local, quand.year, quand.month, quand.day, quand.hour, quand.minute);
    final maintenant = tz.TZDateTime.now(tz.local);
    if (!cible.isBefore(maintenant)) return cible;

    switch (recurrence) {
      case 'quotidien':
        while (cible.isBefore(maintenant)) {
          cible = cible.add(const Duration(days: 1));
        }
        return cible;
      case 'hebdomadaire':
        while (cible.isBefore(maintenant)) {
          cible = cible.add(const Duration(days: 7));
        }
        return cible;
      case 'mensuel':
        while (cible.isBefore(maintenant)) {
          cible = tz.TZDateTime(tz.local, cible.year, cible.month + 1, cible.day, cible.hour, cible.minute);
        }
        return cible;
      default:
        return cible; // 'aucune' déjà passée : laissé tel quel, l'appelant doit valider la date en amont.
    }
  }

  /**
   * Annule une notification
   */
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id: id);
  }

  /**
   * Annule toutes les notifications
   */
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /**
   * Obtient les notifications pending
   */
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  /**
   * Vérifie les permissions de notification
   */
  Future<bool> hasPermission() async {
    NotificationSettings settings = await _firebaseMessaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  /**
   * Ouvre les paramètres de notification de l'app
   */
  Future<void> openNotificationSettings() async {
    // Note: Ceci nécessiterait une implémentation spécifique à la plateforme
    if (Platform.isAndroid) {
      // Ouvrir les paramètres de notification Android
      // await _openAndroidNotificationSettings();
    } else if (Platform.isIOS) {
      // Ouvrir les paramètres de notification iOS
      // await _openIOSNotificationSettings();
    }
  }

  /**
   * Nettoie les ressources
   */
  void dispose() {
    _messageStreamController.close();
  }
}

/**
 * Handler pour les messages en arrière-plan (doit être top-level)
 */
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    print('📱 Message reçu en arrière-plan: ${message.notification?.title}');
  }
  
  // Initialiser les notifications pour le traitement en arrière-plan
  final FlutterLocalNotificationsPlugin notifications = 
      FlutterLocalNotificationsPlugin();
  
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'warms_background',
    "Wam's Background",
    channelDescription: "Notifications d'arrière-plan Wam's",
    importance: Importance.high,
    priority: Priority.high,
    icon: '@mipmap/ic_launcher',
    color: Color(0xFF1E4DB7),
  );

  const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  const NotificationDetails notificationDetails = NotificationDetails(
    android: androidDetails,
    iOS: iosDetails,
  );

  await notifications.show(
    id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
    title: message.notification?.title ?? "Wam's",
    body: message.notification?.body ?? 'Nouveau message',
    payload: 'notification',
    notificationDetails: notificationDetails,
  );
}
