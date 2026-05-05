import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';

/**
 * Service de mode hors-ligne pour WARMS Mobile
 * 
 * Ce service gère le stockage local des données, la synchronisation,
 * et la détection de connectivité pour permettre une utilisation
 * complète de l'application même sans connexion Internet.
 * 
 * @author WARMS Team
 * @version 1.0.0
 */
class OfflineService {
  static final OfflineService _instance = OfflineService._internal();
  factory OfflineService() => _instance;
  OfflineService._internal() {
    _initializeOfflineService();
  }

  /// Nom de la box Hive pour les données
  static const String _dataBoxName = 'warms_offline_data';
  
  /// Nom de la box Hive pour les actions en attente
  static const String _actionsBoxName = 'warms_pending_actions';
  
  /// Box Hive pour les données
  late Box<Map<String, dynamic>> _dataBox;
  
  /// Box Hive pour les actions en attente
  late Box<Map<String, dynamic>> _actionsBox;
  
  /// Stream controller pour l'état de connectivité
  final StreamController<bool> _connectivityController = 
      StreamController<bool>.broadcast();
  
  /// Stream de l'état de connectivité
  Stream<bool> get connectivityStream => _connectivityController.stream;
  
  /// État actuel de la connectivité
  bool _isConnected = true;
  bool get isConnected => _isConnected;
  
  /// Stream subscription pour la connectivité
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  
  /// Timer pour la synchronisation automatique
  Timer? _syncTimer;

  /**
   * Initialise le service hors-ligne
   */
  Future<void> _initializeOfflineService() async {
    try {
      // Initialiser Hive
      final appDocDir = await getApplicationDocumentsDirectory();
      Hive.init(appDocDir.path);
      
      // Ouvrir les boxes
      _dataBox = await Hive.openBox<Map<String, dynamic>>(_dataBoxName);
      _actionsBox = await Hive.openBox<Map<String, dynamic>>(_actionsBoxName);
      
      // Configurer la surveillance de la connectivité
      await _setupConnectivityMonitoring();
      
      // Démarrer la synchronisation automatique
      _startAutoSync();
      
      if (kDebugMode) {
        print('📴 Service hors-ligne initialisé avec succès');
        print('📦 Box données: ${_dataBox.length} éléments');
        print('⏳ Box actions: ${_actionsBox.length} éléments');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur initialisation service hors-ligne: $e');
      }
    }
  }

  /**
   * Configure la surveillance de la connectivité
   */
  Future<void> _setupConnectivityMonitoring() async {
    // Vérifier la connectivité initiale
    final initialResult = await Connectivity().checkConnectivity();
    _updateConnectivityStatus(initialResult);
    
    // Surveiller les changements de connectivité
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _updateConnectivityStatus,
    );
  }

  /**
   * Met à jour le statut de connectivité
   */
  void _updateConnectivityStatus(ConnectivityResult result) {
    final wasConnected = _isConnected;
    _isConnected = result != ConnectivityResult.none;
    
    if (wasConnected != _isConnected) {
      _connectivityController.add(_isConnected);
      
      if (kDebugMode) {
        print('🌐 Connectivité changée: $_isConnected');
      }
      
      // Si la connexion est rétablie, synchroniser les actions en attente
      if (_isConnected) {
        _syncPendingActions();
      }
    }
  }

  /**
   * Démarre la synchronisation automatique
   */
  void _startAutoSync() {
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (_isConnected) {
        _syncPendingActions();
      }
    });
  }

  /**
   * Sauvegarde des données localement
   */
  Future<void> saveDataLocally({
    required String key,
    required Map<String, dynamic> data,
    String? endpoint,
  }) async {
    try {
      final enrichedData = {
        ...data,
        'timestamp': DateTime.now().toIso8601String(),
        'endpoint': endpoint,
        'synced': false,
      };
      
      await _dataBox.put(key, enrichedData);
      
      if (kDebugMode) {
        print('💾 Données sauvegardées localement: $key');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur sauvegarde locale: $e');
      }
    }
  }

  /**
   * Récupère des données locales
   */
  Map<String, dynamic>? getLocalData(String key) {
    try {
      return _dataBox.get(key);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur récupération données locales: $e');
      }
      return null;
    }
  }

  /**
   * Ajoute une action en attente de synchronisation
   */
  Future<void> addPendingAction({
    required String actionId,
    required String method,
    required String endpoint,
    required Map<String, dynamic> data,
    Map<String, dynamic>? headers,
  }) async {
    try {
      final action = {
        'id': actionId,
        'method': method,
        'endpoint': endpoint,
        'data': data,
        'headers': headers ?? {},
        'timestamp': DateTime.now().toIso8601String(),
        'retryCount': 0,
        'maxRetries': 3,
      };
      
      await _actionsBox.put(actionId, action);
      
      if (kDebugMode) {
        print('⏳ Action en attente ajoutée: $actionId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur ajout action en attente: $e');
      }
    }
  }

  /**
   * Synchronise les actions en attente
   */
  Future<void> _syncPendingActions() async {
    if (!_isConnected) return;
    
    final actions = _actionsBox.values.toList();
    
    if (kDebugMode) {
      print('🔄 Synchronisation de ${actions.length} actions en attente');
    }
    
    final dio = Dio();
    
    for (final action in actions) {
      try {
        await _executePendingAction(dio, action);
        await _actionsBox.delete(action['id']);
        
        if (kDebugMode) {
          print('✅ Action synchronisée: ${action['id']}');
        }
      } catch (e) {
        await _handleSyncFailure(action, e);
      }
    }
  }

  /**
   * Exécute une action en attente
   */
  Future<void> _executePendingAction(Dio dio, Map<String, dynamic> action) async {
    final method = action['method'].toString().toLowerCase();
    final endpoint = action['endpoint'].toString();
    final data = action['data'] as Map<String, dynamic>;
    final headers = action['headers'] as Map<String, dynamic>;
    
      switch (method) {
        case 'post':
          await dio.post(endpoint, data: data, options: Options(headers: headers));
          break;
        case 'put':
          await dio.put(endpoint, data: data, options: Options(headers: headers));
          break;
        case 'patch':
          await dio.patch(endpoint, data: data, options: Options(headers: headers));
          break;
        case 'delete':
          await dio.delete(endpoint, options: Options(headers: headers));
          break;
        default:
          throw UnsupportedError('Méthode non supportée: $method');
      }
  }

  /**
   * Gère les échecs de synchronisation
   */
  Future<void> _handleSyncFailure(Map<String, dynamic> action, dynamic error) async {
    final retryCount = (action['retryCount'] as int? ?? 0) + 1;
    final maxRetries = action['maxRetries'] as int? ?? 3;
    
    if (retryCount >= maxRetries) {
      // Supprimer l'action après le nombre maximum de tentatives
      await _actionsBox.delete(action['id']);
      
      if (kDebugMode) {
        print('❌ Action abandonnée après $maxRetries tentatives: ${action['id']}');
      }
    } else {
      // Mettre à jour le compteur de tentatives
      action['retryCount'] = retryCount;
      await _actionsBox.put(action['id'], action);
      
      if (kDebugMode) {
        print('⚠️ Échec synchronisation ($retryCount/$maxRetries): ${action['id']}');
      }
    }
  }

  /**
   * Synchronise manuellement toutes les données
   */
  Future<SyncResult> syncAllData() async {
    if (!_isConnected) {
      return SyncResult(
        success: false,
        message: 'Pas de connexion Internet',
        syncedCount: 0,
        failedCount: 0,
      );
    }
    
    int syncedCount = 0;
    int failedCount = 0;
    
    try {
      final actions = _actionsBox.values.toList();
      final dio = Dio();
      
      for (final action in actions) {
        try {
          await _executePendingAction(dio, action);
          await _actionsBox.delete(action['id']);
          syncedCount++;
        } catch (e) {
          await _handleSyncFailure(action, e);
          failedCount++;
        }
      }
      
      return SyncResult(
        success: true,
        message: 'Synchronisation terminée',
        syncedCount: syncedCount,
        failedCount: failedCount,
      );
    } catch (e) {
      return SyncResult(
        success: false,
        message: 'Erreur lors de la synchronisation: $e',
        syncedCount: syncedCount,
        failedCount: failedCount,
      );
    }
  }

  /**
   * Vide toutes les données locales
   */
  Future<void> clearAllLocalData() async {
    try {
      await _dataBox.clear();
      await _actionsBox.clear();
      
      if (kDebugMode) {
        print('🗑️ Toutes les données locales ont été effacées');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors du nettoyage des données: $e');
      }
    }
  }

  /**
   * Obtient des statistiques sur les données locales
   */
  OfflineStats getOfflineStats() {
    final dataCount = _dataBox.length;
    final pendingActions = _actionsBox.length;
    final totalSize = _calculateTotalSize();
    
    return OfflineStats(
      dataCount: dataCount,
      pendingActions: pendingActions,
      totalSizeBytes: totalSize,
      isConnected: _isConnected,
    );
  }

  /**
   * Calcule la taille totale des données locales
   */
  int _calculateTotalSize() {
    int totalSize = 0;
    
    // Taille des données
    for (final data in _dataBox.values) {
      totalSize += json.encode(data).length;
    }
    
    // Taille des actions
    for (final action in _actionsBox.values) {
      totalSize += json.encode(action).length;
    }
    
    return totalSize;
  }

  /**
   * Exporte les données locales pour la sauvegarde
   */
  Future<Map<String, dynamic>> exportLocalData() async {
    final data = <String, dynamic>{};
    
    // Exporter les données
    data['data'] = {};
    for (final key in _dataBox.keys) {
      data['data'][key] = _dataBox.get(key);
    }
    
    // Exporter les actions
    data['actions'] = {};
    for (final key in _actionsBox.keys) {
      data['actions'][key] = _actionsBox.get(key);
    }
    
    data['exportDate'] = DateTime.now().toIso8601String();
    data['stats'] = getOfflineStats().toJson();
    
    return data;
  }

  /**
   * Importe des données depuis une sauvegarde
   */
  Future<void> importLocalData(Map<String, dynamic> exportData) async {
    try {
      // Importer les données
      final data = exportData['data'] as Map<String, dynamic>?;
      if (data != null) {
        for (final entry in data.entries) {
          await _dataBox.put(entry.key, entry.value as Map<String, dynamic>);
        }
      }
      
      // Importer les actions
      final actions = exportData['actions'] as Map<String, dynamic>?;
      if (actions != null) {
        for (final entry in actions.entries) {
          await _actionsBox.put(entry.key, entry.value as Map<String, dynamic>);
        }
      }
      
      if (kDebugMode) {
        print('📥 Import des données terminé avec succès');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de l\'import des données: $e');
      }
      rethrow;
    }
  }

  /**
   * Nettoie les anciennes données (plus de 30 jours)
   */
  Future<void> cleanupOldData() async {
    try {
      final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
      final cutoffIso = cutoffDate.toIso8601String();
      
      // Nettoyer les anciennes données
      final dataKeysToDelete = <String>[];
      for (final key in _dataBox.keys) {
        final value = _dataBox.get(key);
        if (value != null) {
          final timestamp = value['timestamp'] as String?;
          if (timestamp != null && timestamp.compareTo(cutoffIso) < 0) {
            dataKeysToDelete.add(key);
          }
        }
      }
      
      for (final key in dataKeysToDelete) {
        await _dataBox.delete(key);
      }
      
      // Nettoyer les anciennes actions
      final actionKeysToDelete = <String>[];
      for (final key in _actionsBox.keys) {
        final value = _actionsBox.get(key);
        if (value != null) {
          final timestamp = value['timestamp'] as String?;
          if (timestamp != null && timestamp.compareTo(cutoffIso) < 0) {
            actionKeysToDelete.add(key);
          }
        }
      }
      
      for (final key in actionKeysToDelete) {
        await _actionsBox.delete(key);
      }
      
      if (kDebugMode) {
        print('🧹 Nettoyage terminé: ${dataKeysToDelete.length} données et ${actionKeysToDelete.length} actions supprimées');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors du nettoyage: $e');
      }
    }
  }

  /**
   * Détruit le service et nettoie les ressources
   */
  void dispose() {
    _connectivitySubscription?.cancel();
    _syncTimer?.cancel();
    _connectivityController.close();
    
    // Fermer les boxes Hive
    _dataBox.close();
    _actionsBox.close();
  }
}

/**
 * Résultat de synchronisation
 */
class SyncResult {
  final bool success;
  final String message;
  final int syncedCount;
  final int failedCount;

  SyncResult({
    required this.success,
    required this.message,
    required this.syncedCount,
    required this.failedCount,
  });
}

/**
 * Statistiques hors-ligne
 */
class OfflineStats {
  final int dataCount;
  final int pendingActions;
  final int totalSizeBytes;
  final bool isConnected;

  OfflineStats({
    required this.dataCount,
    required this.pendingActions,
    required this.totalSizeBytes,
    required this.isConnected,
  });

  /// Taille formatée pour l'affichage
  String get formattedSize {
    if (totalSizeBytes < 1024) return '${totalSizeBytes}B';
    if (totalSizeBytes < 1024 * 1024) return '${(totalSizeBytes / 1024).toStringAsFixed(1)}KB';
    return '${(totalSizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  Map<String, dynamic> toJson() {
    return {
      'dataCount': dataCount,
      'pendingActions': pendingActions,
      'totalSizeBytes': totalSizeBytes,
      'formattedSize': formattedSize,
      'isConnected': isConnected,
    };
  }
}
