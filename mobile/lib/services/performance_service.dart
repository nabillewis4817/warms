import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

/**
 * Service de performance pour WARMS Mobile
 * 
 * Ce service surveille et optimise les performances de l'application
 * en temps réel, incluant la mémoire, le CPU, les appels réseau,
 * et les temps de rendu.
 * 
 * @author WARMS Team
 * @version 1.0.0
 */
class PerformanceService {
  static final PerformanceService _instance = PerformanceService._internal();
  factory PerformanceService() => _instance;
  PerformanceService._internal() {
    _initializePerformanceMonitoring();
  }

  /// Stream controller pour les métriques de performance
  final StreamController<PerformanceMetrics> _metricsController = 
      StreamController<PerformanceMetrics>.broadcast();
  
  /// Stream des métriques de performance
  Stream<PerformanceMetrics> get metricsStream => _metricsController.stream;
  
  /// Métriques actuelles
  PerformanceMetrics _currentMetrics = PerformanceMetrics();
  PerformanceMetrics get currentMetrics => _currentMetrics;
  
  /// Timer pour la surveillance des performances
  Timer? _monitoringTimer;
  
  /// Cache pour les appels réseau
  final Map<String, CachedResponse> _cache = {};
  
  /// Historique des métriques
  final List<PerformanceMetrics> _metricsHistory = [];
  
  /// Informations sur l'appareil
  DeviceInfo? _deviceInfo;
  DeviceInfo? get deviceInfo => _deviceInfo;

  /**
   * Initialise la surveillance des performances
   */
  Future<void> _initializePerformanceMonitoring() async {
    try {
      // Obtenir les informations sur l'appareil
      await _loadDeviceInfo();
      
      // Démarrer la surveillance
      _startPerformanceMonitoring();
      
      // Configurer les optimisations système
      await _configureSystemOptimizations();
      
      if (kDebugMode) {
        print('⚡ Service de performance initialisé');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur initialisation performance: $e');
      }
    }
  }

  /**
   * Charge les informations sur l'appareil
   */
  Future<void> _loadDeviceInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final deviceInfo = DeviceInfoPlugin();
      
      String deviceModel = 'Unknown';
      String osVersion = 'Unknown';
      int totalMemory = 0;
      
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceModel = '${androidInfo.brand} ${androidInfo.model}';
        osVersion = 'Android ${androidInfo.version.release}';
        totalMemory = 4096; // Estimation par défaut
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceModel = iosInfo.model;
        osVersion = 'iOS ${iosInfo.systemVersion}';
        totalMemory = 6144; // Estimation par défaut
      }
      
      _deviceInfo = DeviceInfo(
        model: deviceModel,
        osVersion: osVersion,
        totalMemory: totalMemory,
        appVersion: packageInfo.version,
        buildNumber: packageInfo.buildNumber,
      );
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur chargement infos appareil: $e');
      }
    }
  }

  /**
   * Démarre la surveillance des performances
   */
  void _startPerformanceMonitoring() {
    _monitoringTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _collectPerformanceMetrics();
    });
  }

  /**
   * Collecte les métriques de performance
   */
  Future<void> _collectPerformanceMetrics() async {
    try {
      
      // Métriques de base
      final memoryUsage = await _getMemoryUsage();
      final cpuUsage = await _getCpuUsage();
      final networkLatency = await _measureNetworkLatency();
      final renderTime = await _measureRenderTime();
      
      // Métriques de l'application
      final cacheSize = _cache.length;
      final historySize = _metricsHistory.length;
      
      // Créer les métriques
      final metrics = PerformanceMetrics(
        timestamp: DateTime.now(),
        memoryUsage: memoryUsage,
        cpuUsage: cpuUsage,
        networkLatency: networkLatency,
        renderTime: renderTime,
        cacheSize: cacheSize,
        historySize: historySize,
        isPerformant: _isPerformant(memoryUsage, cpuUsage, networkLatency),
      );
      
      // Mettre à jour les métriques actuelles
      _currentMetrics = metrics;
      
      // Ajouter à l'historique
      _metricsHistory.add(metrics);
      
      // Limiter l'historique à 100 éléments
      if (_metricsHistory.length > 100) {
        _metricsHistory.removeAt(0);
      }
      
      // Diffuser les métriques
      _metricsController.add(metrics);
      
      // Optimisations automatiques si nécessaire
      if (!metrics.isPerformant) {
        await _applyAutomaticOptimizations(metrics);
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur collecte métriques: $e');
      }
    }
  }

  /**
   * Obtient l'utilisation de la mémoire
   */
  Future<double> _getMemoryUsage() async {
    try {
      // Simuler l'utilisation de la mémoire (en pourcentage)
      // Dans une vraie implémentation, utiliser device_info_plus ou d'autres packages
      return 30.0 + (DateTime.now().millisecond % 40);
    } catch (e) {
      return 0.0;
    }
  }

  /**
   * Obtient l'utilisation du CPU
   */
  Future<double> _getCpuUsage() async {
    try {
      // Simuler l'utilisation du CPU (en pourcentage)
      return 10.0 + (DateTime.now().millisecond % 30);
    } catch (e) {
      return 0.0;
    }
  }

  /**
   * Mesure la latence réseau
   */
  Future<double> _measureNetworkLatency() async {
    try {
      final startTime = DateTime.now();
      
      // Simuler un ping réseau
      await Future.delayed(const Duration(milliseconds: 50));
      
      final endTime = DateTime.now();
      return endTime.difference(startTime).inMilliseconds.toDouble();
    } catch (e) {
      return 999.0; // Latence élevée en cas d'erreur
    }
  }

  /**
   * Mesure le temps de rendu
   */
  Future<double> _measureRenderTime() async {
    try {
      final startTime = DateTime.now();
      
      // Simuler une opération de rendu
      await Future.delayed(const Duration(milliseconds: 16)); // ~60 FPS
      
      final endTime = DateTime.now();
      return endTime.difference(startTime).inMilliseconds.toDouble();
    } catch (e) {
      return 33.0; // ~30 FPS par défaut
    }
  }

  /**
   * Détermine si les performances sont acceptables
   */
  bool _isPerformant(double memoryUsage, double cpuUsage, double networkLatency) {
    return memoryUsage < 80.0 && // < 80% de mémoire
           cpuUsage < 70.0 &&     // < 70% de CPU
           networkLatency < 500.0; // < 500ms de latence
  }

  /**
   * Applique des optimisations automatiques
   */
  Future<void> _applyAutomaticOptimizations(PerformanceMetrics metrics) async {
    try {
      if (metrics.memoryUsage > 80.0) {
        await _optimizeMemory();
      }
      
      if (metrics.cacheSize > 100) {
        await _cleanupCache();
      }
      
      if (metrics.historySize > 50) {
        await _cleanupHistory();
      }
      
      if (kDebugMode) {
        print('🔧 Optimisations automatiques appliquées');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur optimisations: $e');
      }
    }
  }

  /**
   * Optimise la mémoire
   */
  Future<void> _optimizeMemory() async {
    try {
      // Nettoyer le cache
      await _cleanupCache();
      
      // Nettoyer l'historique
      await _cleanupHistory();
      
      // Forcer le garbage collection (si disponible)
      // Note: System.gc() n'est pas disponible en Flutter
      
      if (kDebugMode) {
        print('🧹 Mémoire optimisée');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur optimisation mémoire: $e');
      }
    }
  }

  /**
   * Nettoie le cache
   */
  Future<void> _cleanupCache() async {
    try {
      // Supprimer les entrées les plus anciennes
      final entries = _cache.entries.toList();
      entries.sort((a, b) => a.value.timestamp.compareTo(b.value.timestamp));
      
      // Garder seulement les 50 plus récentes
      for (int i = 0; i < entries.length - 50; i++) {
        _cache.remove(entries[i].key);
      }
      
      if (kDebugMode) {
        print('🗑️ Cache nettoyé: ${_cache.length} éléments restants');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur nettoyage cache: $e');
      }
    }
  }

  /**
   * Nettoie l'historique des métriques
   */
  Future<void> _cleanupHistory() async {
    try {
      // Garder seulement les 25 plus récentes
      if (_metricsHistory.length > 25) {
        _metricsHistory.removeRange(0, _metricsHistory.length - 25);
      }
      
      if (kDebugMode) {
        print('📊 Historique nettoyé: ${_metricsHistory.length} éléments');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur nettoyage historique: $e');
      }
    }
  }

  /**
   * Configure les optimisations système
   */
  Future<void> _configureSystemOptimizations() async {
    try {
      // Configurer l'orientation préférée
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      
      // Configurer l'UI System
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: [
          SystemUiOverlay.top,
          SystemUiOverlay.bottom,
        ],
      );
      
      // Configurer la barre de statut
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          systemNavigationBarColor: Color(0xFF1E4DB7),
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      );
      
      if (kDebugMode) {
        print('⚙️ Optimisations système configurées');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur configuration système: $e');
      }
    }
  }

  /**
   * Met en cache une réponse réseau
   */
  void cacheResponse(String key, dynamic data, {Duration? ttl}) {
    _cache[key] = CachedResponse(
      data: data,
      timestamp: DateTime.now(),
      ttl: ttl ?? const Duration(minutes: 5),
    );
  }

  /**
   * Récupère une réponse depuis le cache
   */
  T? getCachedResponse<T>(String key) {
    final cached = _cache[key];
    if (cached == null) return null;
    
    // Vérifier si le cache est expiré
    if (DateTime.now().difference(cached.timestamp) > cached.ttl) {
      _cache.remove(key);
      return null;
    }
    
    return cached.data as T?;
  }

  /**
   * Mesure le temps d'exécution d'une fonction
   */
  T measureExecutionTime<T>(String operationName, T Function() operation) {
    final startTime = DateTime.now();
    try {
      final result = operation();
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      
      if (kDebugMode) {
        print('⏱️ $operationName: ${duration.inMilliseconds}ms');
      }
      
      return result;
    } catch (e) {
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      
      if (kDebugMode) {
        print('❌ $operationName (échec): ${duration.inMilliseconds}ms');
      }
      
      rethrow;
    }
  }

  /**
   * Obtient un rapport de performance
   */
  PerformanceReport getPerformanceReport() {
    if (_metricsHistory.isEmpty) {
      return PerformanceReport(
        overallScore: 0.0,
        averageMemoryUsage: 0.0,
        averageCpuUsage: 0.0,
        averageNetworkLatency: 0.0,
        averageRenderTime: 0.0,
        recommendations: ['Pas assez de données pour analyser'],
      );
    }
    
    final memoryUsages = _metricsHistory.map((m) => m.memoryUsage).toList();
    final cpuUsages = _metricsHistory.map((m) => m.cpuUsage).toList();
    final networkLatencies = _metricsHistory.map((m) => m.networkLatency).toList();
    final renderTimes = _metricsHistory.map((m) => m.renderTime).toList();
    
    final avgMemory = memoryUsages.reduce((a, b) => a + b) / memoryUsages.length;
    final avgCpu = cpuUsages.reduce((a, b) => a + b) / cpuUsages.length;
    final avgLatency = networkLatencies.reduce((a, b) => a + b) / networkLatencies.length;
    final avgRenderTime = renderTimes.reduce((a, b) => a + b) / renderTimes.length;
    
    // Calculer le score global (0-100)
    final memoryScore = (100 - avgMemory).clamp(0.0, 100.0);
    final cpuScore = (100 - avgCpu).clamp(0.0, 100.0);
    final latencyScore = avgLatency < 100 ? 100 : (100 - (avgLatency - 100) / 10).clamp(0.0, 100.0);
    final renderScore = avgRenderTime < 16 ? 100 : (100 - (avgRenderTime - 16) * 2).clamp(0.0, 100.0);
    
    final overallScore = (memoryScore + cpuScore + latencyScore + renderScore) / 4;
    
    // Générer des recommandations
    final recommendations = <String>[];
    if (avgMemory > 70) recommendations.add('Optimiser l\'utilisation de la mémoire');
    if (avgCpu > 60) recommendations.add('Réduire la charge CPU');
    if (avgLatency > 200) recommendations.add('Optimiser les appels réseau');
    if (avgRenderTime > 16) recommendations.add('Améliorer les performances de rendu');
    
    return PerformanceReport(
      overallScore: overallScore,
      averageMemoryUsage: avgMemory,
      averageCpuUsage: avgCpu,
      averageNetworkLatency: avgLatency,
      averageRenderTime: avgRenderTime,
      recommendations: recommendations.isEmpty ? ['Performance optimale'] : recommendations,
    );
  }

  /**
   * Détruit le service et nettoie les ressources
   */
  void dispose() {
    _monitoringTimer?.cancel();
    _metricsController.close();
    _cache.clear();
    _metricsHistory.clear();
  }
}

/**
 * Métriques de performance
 */
class PerformanceMetrics {
  final DateTime timestamp;
  final double memoryUsage;      // %
  final double cpuUsage;         // %
  final double networkLatency;   // ms
  final double renderTime;       // ms
  final int cacheSize;
  final int historySize;
  final bool isPerformant;

  PerformanceMetrics({
    DateTime? timestamp,
    this.memoryUsage = 0.0,
    this.cpuUsage = 0.0,
    this.networkLatency = 0.0,
    this.renderTime = 0.0,
    this.cacheSize = 0,
    this.historySize = 0,
    this.isPerformant = true,
  }) : timestamp = timestamp ?? DateTime.now();
}

/**
 * Informations sur l'appareil
 */
class DeviceInfo {
  final String model;
  final String osVersion;
  final int totalMemory;      // MB
  final String appVersion;
  final String buildNumber;

  DeviceInfo({
    required this.model,
    required this.osVersion,
    required this.totalMemory,
    required this.appVersion,
    required this.buildNumber,
  });
}

/**
 * Réponse mise en cache
 */
class CachedResponse {
  final dynamic data;
  final DateTime timestamp;
  final Duration ttl;

  CachedResponse({
    required this.data,
    required this.timestamp,
    required this.ttl,
  });
}

/**
 * Rapport de performance
 */
class PerformanceReport {
  final double overallScore;           // 0-100
  final double averageMemoryUsage;     // %
  final double averageCpuUsage;        // %
  final double averageNetworkLatency;  // ms
  final double averageRenderTime;      // ms
  final List<String> recommendations;

  PerformanceReport({
    required this.overallScore,
    required this.averageMemoryUsage,
    required this.averageCpuUsage,
    required this.averageNetworkLatency,
    required this.averageRenderTime,
    required this.recommendations,
  });
  
  /// Évaluation de la performance
  String get performanceGrade {
    if (overallScore >= 90) return 'A+';
    if (overallScore >= 80) return 'A';
    if (overallScore >= 70) return 'B';
    if (overallScore >= 60) return 'C';
    if (overallScore >= 50) return 'D';
    return 'F';
  }
  
  /// Couleur associée au grade
  String get gradeColor {
    switch (performanceGrade) {
      case 'A+':
      case 'A':
        return '#4CAF50'; // Vert
      case 'B':
        return '#FFC107'; // Jaune
      case 'C':
        return '#FF9800'; // Orange
      case 'D':
        return '#F44336'; // Rouge
      default:
        return '#9E9E9E'; // Gris
    }
  }
}
