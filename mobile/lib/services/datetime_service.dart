import 'dart:async';
import 'package:flutter/foundation.dart';

/**
 * Service de gestion de la date et heure en temps réel pour WARMS Mobile
 * 
 * Ce service fournit une mise à jour automatique de la date et heure
 * avec différents formats pour s'adapter à l'interface utilisateur mobile.
 * 
 * @author WARMS Team
 * @version 1.0.0
 */
class DateTimeService {
  static final DateTimeService _instance = DateTimeService._internal();
  factory DateTimeService() => _instance;
  DateTimeService._internal() {
    _startDateTimeUpdates();
  }

  /// Intervalle de mise à jour en millisecondes (1 seconde)
  static const int _updateInterval = 1000;
  
  /// Stream controller pour diffuser les mises à jour de date/heure
  final StreamController<DateTime> _dateTimeController = 
      StreamController<DateTime>.broadcast();
  
  /// Stream public de la date/heure actuelle
  Stream<DateTime> get currentDateTimeStream => _dateTimeController.stream;
  
  /// Date/heure actuelle
  DateTime get currentDateTime => DateTime.now();
  
  /// Timer pour les mises à jour automatiques
  Timer? _updateTimer;

  /**
   * Démarre les mises à jour automatiques de la date/heure
   */
  void _startDateTimeUpdates() {
    // Mise à jour immédiate
    _updateDateTime();
    
    // Configuration de l'intervalle de mise à jour
    _updateTimer = Timer.periodic(
      const Duration(milliseconds: _updateInterval),
      (_) => _updateDateTime(),
    );
  }

  /**
   * Met à jour la date/heure actuelle
   */
  void _updateDateTime() {
    _dateTimeController.add(DateTime.now());
  }

  /**
   * Formate la date et heure pour un affichage compact
   * Format: "JJ/MM/AAAA HH:mm:ss"
   */
  String formatDateTime(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    final hours = date.hour.toString().padLeft(2, '0');
    final minutes = date.minute.toString().padLeft(2, '0');
    final seconds = date.second.toString().padLeft(2, '0');
    
    return '$day/$month/$year $hours:$minutes:$seconds';
  }

  /**
   * Formate la date et heure pour un affichage étendu avec le nom du jour
   * Format: "Lundi 27 Avril 2026 - 10:47:32"
   */
  String formatDateExtended(DateTime date) {
    const dayNames = ['Dimanche', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];
    const monthNames = ['Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 
                       'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'];
    
    final dayName = dayNames[date.weekday % 7];
    final day = date.day;
    final monthName = monthNames[date.month - 1];
    final year = date.year;
    final hours = date.hour.toString().padLeft(2, '0');
    final minutes = date.minute.toString().padLeft(2, '0');
    final seconds = date.second.toString().padLeft(2, '0');
    
    return '$dayName $day $monthName $year - $hours:$minutes:$seconds';
  }

  /**
   * Formate uniquement l'heure
   * Format: "HH:mm:ss"
   */
  String formatTime(DateTime date) {
    final hours = date.hour.toString().padLeft(2, '0');
    final minutes = date.minute.toString().padLeft(2, '0');
    final seconds = date.second.toString().padLeft(2, '0');
    
    return '$hours:$minutes:$seconds';
  }

  /**
   * Formate uniquement la date
   * Format: "JJ/MM/AAAA"
   */
  String formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    
    return '$day/$month/$year';
  }

  /**
   * Formate l'heure pour un affichage mobile compact
   * Format: "HH:mm"
   */
  String formatTimeCompact(DateTime date) {
    final hours = date.hour.toString().padLeft(2, '0');
    final minutes = date.minute.toString().padLeft(2, '0');
    
    return '$hours:$minutes';
  }

  /**
   * Formate la date pour un affichage mobile compact
   * Format: "DD/MM"
   */
  String formatDateCompact(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    
    return '$day/$month';
  }

  /**
   * Retourne le nom du jour actuel
   */
  String getCurrentDayName() {
    const dayNames = ['Dimanche', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];
    return dayNames[DateTime.now().weekday % 7];
  }

  /**
   * Retourne une représentation relative du temps (ex: "Il y a 5 minutes")
   */
  String getRelativeTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    final diffInMinutes = diff.inMinutes;
    final diffInHours = diff.inHours;
    final diffInDays = diff.inDays;

    if (diffInMinutes < 1) {
      return 'À l\'instant';
    } else if (diffInMinutes < 60) {
      return 'Il y a ${diffInMinutes} minute${diffInMinutes > 1 ? 's' : ''}';
    } else if (diffInHours < 24) {
      return 'Il y a ${diffInHours} heure${diffInHours > 1 ? 's' : ''}';
    } else if (diffInDays < 7) {
      return 'Il y a ${diffInDays} jour${diffInDays > 1 ? 's' : ''}';
    } else {
      return formatDate(date);
    }
  }

  /**
   * Vérifie si l'heure actuelle est dans la plage de travail (9h-18h)
   */
  bool isWorkingHours() {
    final currentHour = DateTime.now().hour;
    return currentHour >= 9 && currentHour <= 18;
  }

  /**
   * Retourne un message contextuel basé sur l'heure
   */
  String getTimeBasedGreeting() {
    final currentHour = DateTime.now().hour;
    
    if (currentHour < 12) {
      return '☀️ Bonjour';
    } else if (currentHour < 18) {
      return '🌤️ Bon après-midi';
    } else {
      return '🌙 Bonsoir';
    }
  }

  /**
   * Retourne une icône basée sur l'heure
   */
  String getTimeBasedIcon() {
    final currentHour = DateTime.now().hour;
    
    if (currentHour >= 6 && currentHour < 12) {
      return '🌅'; // Matin
    } else if (currentHour >= 12 && currentHour < 18) {
      return '☀️'; // Après-midi
    } else if (currentHour >= 18 && currentHour < 21) {
      return '🌆'; // Soir
    } else {
      return '🌙'; // Nuit
    }
  }

  /**
   * Retourne une couleur de thème basée sur l'heure
   */
  String getTimeBasedColor() {
    final currentHour = DateTime.now().hour;
    
    if (currentHour >= 6 && currentHour < 12) {
      return '#FFA726'; // Orange matinal
    } else if (currentHour >= 12 && currentHour < 18) {
      return '#42A5F5'; // Bleu diurne
    } else if (currentHour >= 18 && currentHour < 21) {
      return '#FF7043'; // Orange crépusculaire
    } else {
      return '#5C6BC0'; // Bleu nuit
    }
  }

  /**
   * Détruit le service et nettoie les ressources
   */
  void dispose() {
    _updateTimer?.cancel();
    _dateTimeController.close();
  }
}
