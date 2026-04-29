import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:collection';
import 'dart:io';

class PerformanceService {
  static final PerformanceService _instance = PerformanceService._internal();
  factory PerformanceService() => _instance;
  PerformanceService._internal();

  final Map<String, DateTime> _apiCallTimestamps = {};
  final Map<String, int> _apiCallCounts = {};
  final Map<String, double> _apiCallTimes = {};
  
  final Queue<PerformanceMetric> _metrics = Queue();
  final int _maxMetricsCount = 1000;
  
  Timer? _cleanupTimer;
  Timer? _reportingTimer;
  
  bool _isMonitoring = false;

  void startMonitoring() {
    if (_isMonitoring) return;
    
    _isMonitoring = true;
    
    // Nettoyage périodique
    _cleanupTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _cleanupOldData();
    });
    
    // Rapport périodique
    _reportingTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _generatePerformanceReport();
    });
    
    print('🚀 Monitoring des performances démarré');
  }

  void stopMonitoring() {
    _isMonitoring = false;
    _cleanupTimer?.cancel();
    _reportingTimer?.cancel();
    print('⏹️ Monitoring des performances arrêté');
  }

  // Mesurer les performances des appels API
  T measureApiCall<T>(String apiName, T Function() apiCall) {
    if (!_isMonitoring) return apiCall();
    
    final stopwatch = Stopwatch()..start();
    final timestamp = DateTime.now();
    
    try {
      final result = apiCall();
      stopwatch.stop();
      
      _recordApiMetrics(apiName, stopwatch.elapsedMilliseconds, timestamp);
      return result;
    } catch (e) {
      stopwatch.stop();
      _recordApiMetrics(apiName, stopwatch.elapsedMilliseconds, timestamp, isError: true);
      rethrow;
    }
  }

  Future<T> measureAsyncApiCall<T>(String apiName, Future<T> Function() apiCall) async {
    if (!_isMonitoring) return apiCall();
    
    final stopwatch = Stopwatch()..start();
    final timestamp = DateTime.now();
    
    try {
      final result = await apiCall();
      stopwatch.stop();
      
      _recordApiMetrics(apiName, stopwatch.elapsedMilliseconds, timestamp);
      return result;
    } catch (e) {
      stopwatch.stop();
      _recordApiMetrics(apiName, stopwatch.elapsedMilliseconds, timestamp, isError: true);
      rethrow;
    }
  }

  void _recordApiMetrics(
    String apiName, 
    int elapsedMs, 
    DateTime timestamp, 
    {bool isError = false}
  ) {
    _apiCallTimestamps[apiName] = timestamp;
    _apiCallCounts[apiName] = (_apiCallCounts[apiName] ?? 0) + 1;
    
    // Moyenne mobile du temps de réponse
    final currentAvg = _apiCallTimes[apiName] ?? 0.0;
    final count = _apiCallCounts[apiName]!;
    _apiCallTimes[apiName] = ((currentAvg * (count - 1)) + elapsedMs) / count;
    
    // Ajouter aux métriques
    _metrics.add(PerformanceMetric(
      type: 'api_call',
      name: apiName,
      value: elapsedMs.toDouble(),
      timestamp: timestamp,
      isError: isError,
    ));
    
    // Limiter la taille de la queue
    if (_metrics.length > _maxMetricsCount) {
      _metrics.removeFirst();
    }
    
    // Alerter si les performances sont mauvaises
    if (elapsedMs > 2000) {
      _logPerformanceWarning('API', apiName, elapsedMs);
    }
  }

  // Mesurer les performances de rendu
  void measureRenderTime(String widgetName, VoidCallback renderFunction) {
    if (!_isMonitoring) {
      renderFunction();
      return;
    }
    
    final stopwatch = Stopwatch()..start();
    renderFunction();
    stopwatch.stop();
    
    _metrics.add(PerformanceMetric(
      type: 'render',
      name: widgetName,
      value: stopwatch.elapsedMicroseconds.toDouble(),
      timestamp: DateTime.now(),
    ));
    
    if (_metrics.length > _maxMetricsCount) {
      _metrics.removeFirst();
    }
    
    if (stopwatch.elapsedMilliseconds > 16) { // > 60fps
      _logPerformanceWarning('Render', widgetName, stopwatch.elapsedMilliseconds);
    }
  }

  // Mesurer l'utilisation mémoire
  MemoryUsage getMemoryUsage() {
    if (!kReleaseMode) {
      return MemoryUsage(
        total: 0,
        used: 0,
        percentage: 0.0,
      );
    }
    
    // Simulation - en production, utiliser des packages comme device_info_plus
    return MemoryUsage(
      total: 1024 * 1024 * 1024, // 1GB simulation
      used: 512 * 1024 * 1024, // 512MB simulation
      percentage: 50.0,
    );
  }

  // Optimisation des images
  Future<File> optimizeImage(File imageFile, {
    int maxWidth = 1024,
    int maxHeight = 1024,
    int quality = 85,
  }) async {
    // Simuler l'optimisation d'image
    // En production, utiliser des packages comme image
    
    final fileSize = await imageFile.length();
    final optimizedSize = (fileSize * quality / 100).round();
    
    print('🖼️ Image optimisée: ${fileSize} -> ${optimizedSize} bytes');
    
    // Retourner le fichier original (simulation)
    return imageFile;
  }

  // Cache intelligent
  final Map<String, CacheItem> _cache = {};
  final int _maxCacheSize = 100;
  final Duration _defaultCacheTTL = const Duration(minutes: 5);

  T? getCached<T>(String key) {
    final item = _cache[key];
    if (item == null) return null;
    
    if (DateTime.now().difference(item.timestamp) > item.ttl) {
      _cache.remove(key);
      return null;
    }
    
    item.hits++;
    return item.data as T;
  }

  void setCached<T>(String key, T data, {Duration? ttl}) {
    if (_cache.length >= _maxCacheSize) {
      _evictLeastUsed();
    }
    
    _cache[key] = CacheItem(
      data: data,
      timestamp: DateTime.now(),
      ttl: ttl ?? _defaultCacheTTL,
      hits: 0,
    );
  }

  void _evictLeastUsed() {
    if (_cache.isEmpty) return;
    
    String? leastUsedKey;
    int minHits = 999999;
    
    _cache.forEach((key, item) {
      if (item.hits < minHits) {
        minHits = item.hits;
        leastUsedKey = key;
      }
    });
    
    if (leastUsedKey != null) {
      _cache.remove(leastUsedKey);
    }
  }

  void clearCache() {
    _cache.clear();
  }

  // Rapport de performance
  PerformanceReport getPerformanceReport() {
    final now = DateTime.now();
    final oneMinuteAgo = now.subtract(const Duration(minutes: 1));
    
    final recentMetrics = _metrics.where((m) => m.timestamp.isAfter(oneMinuteAgo));
    
    final apiMetrics = recentMetrics.where((m) => m.type == 'api_call');
    final renderMetrics = recentMetrics.where((m) => m.type == 'render');
    
    return PerformanceReport(
      timestamp: now,
      memoryUsage: getMemoryUsage(),
      apiCallMetrics: ApiCallMetrics(
        totalCalls: apiMetrics.length,
        averageResponseTime: apiMetrics.isEmpty ? 0.0 : 
          apiMetrics.map((m) => m.value).reduce((a, b) => a + b) / apiMetrics.length,
        slowestCall: apiMetrics.isEmpty ? null : 
          apiMetrics.reduce((a, b) => a.value > b.value ? a : b),
        errorRate: apiMetrics.isEmpty ? 0.0 :
          apiMetrics.where((m) => m.isError).length / apiMetrics.length * 100,
      ),
      renderMetrics: RenderMetrics(
        totalRenders: renderMetrics.length,
        averageRenderTime: renderMetrics.isEmpty ? 0.0 :
          renderMetrics.map((m) => m.value).reduce((a, b) => a + b) / renderMetrics.length,
        slowestRender: renderMetrics.isEmpty ? null :
          renderMetrics.reduce((a, b) => a.value > b.value ? a : b),
      ),
      cacheMetrics: CacheMetrics(
        size: _cache.length,
        hitRate: _cache.isEmpty ? 0.0 :
          _cache.values.map((item) => item.hits).reduce((a, b) => a + b) / _cache.length,
        memoryUsage: _estimateCacheMemoryUsage(),
      ),
    );
  }

  double _estimateCacheMemoryUsage() {
    double totalSize = 0;
    
    _cache.forEach((key, item) {
      totalSize += key.length * 2; // Approximation
      if (item.data is String) {
        totalSize += (item.data as String).length * 2;
      }
    });
    
    return totalSize;
  }

  void _cleanupOldData() {
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(hours: 1));
    
    // Nettoyer les anciennes métriques
    while (_metrics.isNotEmpty && _metrics.first.timestamp.isBefore(cutoff)) {
      _metrics.removeFirst();
    }
    
    // Nettoyer le cache expiré
    _cache.removeWhere((key, item) => 
      now.difference(item.timestamp) > item.ttl
    );
    
    print('🧹 Nettoyage des anciennes données terminé');
  }

  void _generatePerformanceReport() {
    final report = getPerformanceReport();
    
    // Afficher les alertes de performance
    if (report.apiCallMetrics.averageResponseTime > 1000) {
      print('⚠️ Temps de réponse API moyen élevé: ${report.apiCallMetrics.averageResponseTime.toStringAsFixed(2)}ms');
    }
    
    if (report.renderMetrics.averageRenderTime > 16667) { // > 60fps
      print('⚠️ Temps de rendu moyen élevé: ${report.renderMetrics.averageRenderTime.toStringAsFixed(2)}μs');
    }
    
    if (report.memoryUsage.percentage > 80) {
      print('⚠️ Utilisation mémoire élevée: ${report.memoryUsage.percentage.toStringAsFixed(1)}%');
    }
    
    if (report.cacheMetrics.hitRate < 0.5) {
      print('⚠️ Taux de hit du cache faible: ${(report.cacheMetrics.hitRate * 100).toStringAsFixed(1)}%');
    }
  }

  void _logPerformanceWarning(String type, String name, int value) {
    print('🚨 Performance Warning - $type: $name = ${value}ms');
  }

  // Optimisation des listes
  List<T> optimizeList<T>(List<T> items, {
    int? maxItems,
    bool Function(T)? sortBy,
    bool Function(T)? filterBy,
  }) {
    List<T> result = items;
    
    // Filtrer
    if (filterBy != null) {
      result = result.where(filterBy).toList();
    }
    
    // Trier
    if (sortBy != null) {
      result = result..sort((a, b) => sortBy(a).compareTo(sortBy(b)));
    }
    
    // Limiter
    if (maxItems != null && result.length > maxItems) {
      result = result.take(maxItems).toList();
    }
    
    return result;
  }

  // Debouncing pour les recherches
  Timer? _debounceTimer;
  
  void debounce(VoidCallback callback, {Duration delay = const Duration(milliseconds: 300)}) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(delay, callback);
  }

  // Throttling pour les actions fréquentes
  bool _isThrottled = false;
  
  bool throttle(VoidCallback callback, {Duration delay = const Duration(seconds: 1)}) {
    if (_isThrottled) return false;
    
    _isThrottled = true;
    Timer(delay, () => _isThrottled = false);
    
    callback();
    return true;
  }

  void dispose() {
    stopMonitoring();
    _debounceTimer?.cancel();
    _cache.clear();
    _metrics.clear();
  }
}

// Classes de support
class PerformanceMetric {
  final String type;
  final String name;
  final double value;
  final DateTime timestamp;
  final bool isError;

  PerformanceMetric({
    required this.type,
    required this.name,
    required this.value,
    required this.timestamp,
    this.isError = false,
  });
}

class CacheItem {
  final dynamic data;
  final DateTime timestamp;
  final Duration ttl;
  int hits;

  CacheItem({
    required this.data,
    required this.timestamp,
    required this.ttl,
    this.hits = 0,
  });
}

class MemoryUsage {
  final int total;
  final int used;
  final double percentage;

  MemoryUsage({
    required this.total,
    required this.used,
    required this.percentage,
  });
}

class ApiCallMetrics {
  final int totalCalls;
  final double averageResponseTime;
  final PerformanceMetric? slowestCall;
  final double errorRate;

  ApiCallMetrics({
    required this.totalCalls,
    required this.averageResponseTime,
    this.slowestCall,
    required this.errorRate,
  });
}

class RenderMetrics {
  final int totalRenders;
  final double averageRenderTime;
  final PerformanceMetric? slowestRender;

  RenderMetrics({
    required this.totalRenders,
    required this.averageRenderTime,
    this.slowestRender,
  });
}

class CacheMetrics {
  final int size;
  final double hitRate;
  final double memoryUsage;

  CacheMetrics({
    required this.size,
    required this.hitRate,
    required this.memoryUsage,
  });
}

class PerformanceReport {
  final DateTime timestamp;
  final MemoryUsage memoryUsage;
  final ApiCallMetrics apiCallMetrics;
  final RenderMetrics renderMetrics;
  final CacheMetrics cacheMetrics;

  PerformanceReport({
    required this.timestamp,
    required this.memoryUsage,
    required this.apiCallMetrics,
    required this.renderMetrics,
    required this.cacheMetrics,
  });
}
