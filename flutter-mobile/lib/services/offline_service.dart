import 'dart:convert';
import 'dart:io';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/conversation_ia.dart';
import '../models/recherche_ia.dart';
import '../models/analyse_medicale.dart';
import '../models/document_ocr.dart';

part 'offline_service.g.dart';

@HiveType(typeId: 0)
class OfflineConversation extends HiveObject {
  @HiveField(0)
  late String id;
  
  @HiveField(1)
  late String plateforme;
  
  @HiveField(2)
  late DateTime creeLe;
  
  @HiveField(3)
  late DateTime modifieLe;
  
  @HiveField(4)
  late Map<String, dynamic> contexte;
  
  @HiveField(5)
  List<OfflineMessage> messages = [];
  
  @HiveField(6)
  bool synchronized = false;
  
  @HiveField(7)
  DateTime? lastSync;
}

@HiveType(typeId: 1)
class OfflineMessage extends HiveObject {
  @HiveField(0)
  late String contenu;
  
  @HiveField(1)
  late String typeMessage;
  
  @HiveField(2)
  late DateTime timestamp;
  
  @HiveField(3)
  Map<String, dynamic> metadonnees = {};
  
  @HiveField(4)
  bool synchronized = false;
}

@HiveType(typeId: 2)
class OfflineRecherche extends HiveObject {
  @HiveField(0)
  late String query;
  
  @HiveField(1)
  late String plateforme;
  
  @HiveField(2)
  late DateTime timestamp;
  
  @HiveField(3)
  Map<String, dynamic> contexte = {};
  
  @HiveField(4)
  Map<String, dynamic> resultat = {};
  
  @HiveField(5)
  bool synchronized = false;
}

@HiveType(typeId: 3)
class OfflineDocument extends HiveObject {
  @HiveField(0)
  late String texteExtrait;
  
  @HiveField(1)
  Map<String, dynamic> metadonnees = {};
  
  @HiveField(2)
  late double confiance;
  
  @HiveField(3)
  late String plateforme;
  
  @HiveField(4)
  late DateTime creeLe;
  
  @HiveField(5)
  String? localImagePath;
  
  @HiveField(6)
  bool synchronized = false;
}

class OfflineService {
  static final OfflineService _instance = OfflineService._internal();
  factory OfflineService() => _instance;
  OfflineService._internal();

  late Box<OfflineConversation> _conversationsBox;
  late Box<OfflineRecherche> _recherchesBox;
  late Box<OfflineDocument> _documentsBox;
  
  bool _isInitialized = false;
  bool _isOnline = true;
  
  // Écouteurs de connectivité
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialiser Hive
      final appDocumentDir = await getApplicationDocumentsDirectory();
      Hive.initFlutter(appDocumentDir.path);

      // Enregistrer les adapters
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(OfflineConversationAdapter());
        Hive.registerAdapter(OfflineMessageAdapter());
        Hive.registerAdapter(OfflineRechercheAdapter());
        Hive.registerAdapter(OfflineDocumentAdapter());
      }

      // Ouvrir les boxes
      _conversationsBox = await Hive.openBox<OfflineConversation>('conversations');
      _recherchesBox = await Hive.openBox<OfflineRecherche>('recherches');
      _documentsBox = await Hive.openBox<OfflineDocument>('documents');

      // Écouter la connectivité
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_updateConnectivityStatus);

      _isInitialized = true;
      print('✅ Service hors-ligne initialisé');
    } catch (e) {
      print('❌ Erreur initialisation service hors-ligne: $e');
    }
  }

  void _updateConnectivityStatus(ConnectivityResult result) {
    final wasOnline = _isOnline;
    _isOnline = result != ConnectivityResult.none;

    if (!wasOnline && _isOnline) {
      print('🌐 Retour en ligne - Synchronisation...');
      _synchronizeAll();
    } else if (wasOnline && !_isOnline) {
      print('📫 Passage en mode hors-ligne');
    }
  }

  // Gestion des conversations hors-ligne
  Future<void> saveConversationOffline(ConversationIA conversation) async {
    try {
      final offlineConv = OfflineConversation()
        ..id = conversation.id
        ..plateforme = conversation.plateforme
        ..creeLe = conversation.creeLe
        ..modifieLe = conversation.modifieLe
        ..contexte = conversation.contexte
        ..synchronized = false
        ..lastSync = DateTime.now();

      // Convertir les messages
      for (final message in conversation.messages) {
        final offlineMsg = OfflineMessage()
          ..contenu = message.contenu
          ..typeMessage = message.typeMessage
          ..timestamp = message.timestamp
          ..metadonnees = message.metadonnees
          ..synchronized = false;
        
        offlineConv.messages.add(offlineMsg);
      }

      await _conversationsBox.put(conversation.id, offlineConv);
      print('💾 Conversation sauvegardée hors-ligne: ${conversation.id}');
    } catch (e) {
      print('❌ Erreur sauvegarde conversation hors-ligne: $e');
    }
  }

  Future<List<ConversationIA>> getConversationsOffline() async {
    try {
      final conversations = <ConversationIA>[];
      
      for (final key in _conversationsBox.keys) {
        final offlineConv = _conversationsBox.get(key);
        if (offlineConv != null) {
          final messages = offlineConv.messages.map((msg) => MessageIA(
            contenu: msg.contenu,
            typeMessage: msg.typeMessage,
            timestamp: msg.timestamp,
            metadonnees: msg.metadonnees,
          )).toList();

          final conversation = ConversationIA(
            id: offlineConv.id,
            plateforme: offlineConv.plateforme,
            creeLe: offlineConv.creeLe,
            modifieLe: offlineConv.modifieLe,
            contexte: offlineConv.contexte,
            messages: messages,
          );
          
          conversations.add(conversation);
        }
      }
      
      return conversations;
    } catch (e) {
      print('❌ Erreur récupération conversations hors-ligne: $e');
      return [];
    }
  }

  // Gestion des recherches hors-ligne
  Future<void> saveRechercheOffline(RechercheIA recherche) async {
    try {
      final offlineRech = OfflineRecherche()
        ..query = recherche.query
        ..plateforme = recherche.plateforme
        ..timestamp = recherche.timestamp
        ..contexte = recherche.contexte
        ..resultat = {
          'results': recherche.resultat.map((r) => r.toJson()).toList()
        }
        ..synchronized = false;

      await _recherchesBox.put(recherche.id.toString(), offlineRech);
      print('💾 Recherche sauvegardée hors-ligne: ${recherche.id}');
    } catch (e) {
      print('❌ Erreur sauvegarde recherche hors-ligne: $e');
    }
  }

  Future<List<RechercheIA>> getRecherchesOffline() async {
    try {
      final recherches = <RechercheIA>[];
      
      for (final key in _recherchesBox.keys) {
        final offlineRech = _recherchesBox.get(key);
        if (offlineRech != null) {
          final results = (offlineRech.resultat['results'] as List<dynamic>)
              .map((r) => RechercheResult.fromJson(r as Map<String, dynamic>))
              .toList();

          final recherche = RechercheIA(
            id: int.tryParse(key),
            query: offlineRech.query,
            plateforme: offlineRech.plateforme,
            timestamp: offlineRech.timestamp,
            contexte: offlineRech.contexte,
            resultat: results,
          );
          
          recherches.add(recherche);
        }
      }
      
      return recherches;
    } catch (e) {
      print('❌ Erreur récupération recherches hors-ligne: $e');
      return [];
    }
  }

  // Gestion des documents OCR hors-ligne
  Future<void> saveDocumentOffline(DocumentOCR document, {String? localImagePath}) async {
    try {
      final offlineDoc = OfflineDocument()
        ..texteExtrait = document.texteExtrait
        ..metadonnees = document.metadonnees
        ..confiance = document.confiance
        ..plateforme = document.plateforme
        ..creeLe = document.creeLe
        ..localImagePath = localImagePath
        ..synchronized = false;

      await _documentsBox.put(document.id.toString(), offlineDoc);
      print('💾 Document sauvegardé hors-ligne: ${document.id}');
    } catch (e) {
      print('❌ Erreur sauvegarde document hors-ligne: $e');
    }
  }

  Future<List<DocumentOCR>> getDocumentsOffline() async {
    try {
      final documents = <DocumentOCR>[];
      
      for (final key in _documentsBox.keys) {
        final offlineDoc = _documentsBox.get(key);
        if (offlineDoc != null) {
          final document = DocumentOCR(
            id: int.tryParse(key),
            texteExtrait: offlineDoc.texteExtrait,
            metadonnees: offlineDoc.metadonnees,
            confiance: offlineDoc.confiance,
            plateforme: offlineDoc.plateforme,
            creeLe: offlineDoc.creeLe,
            fichierOriginalUrl: offlineDoc.localImagePath,
          );
          
          documents.add(document);
        }
      }
      
      return documents;
    } catch (e) {
      print('❌ Erreur récupération documents hors-ligne: $e');
      return [];
    }
  }

  // Synchronisation
  Future<void> _synchronizeAll() async {
    if (!_isOnline) return;

    try {
      await _synchronizeConversations();
      await _synchronizeRecherches();
      await _synchronizeDocuments();
      
      print('✅ Synchronisation terminée');
    } catch (e) {
      print('❌ Erreur synchronisation: $e');
    }
  }

  Future<void> _synchronizeConversations() async {
    // TODO: Implémenter la synchronisation avec le serveur
    print('🔄 Synchronisation des conversations...');
  }

  Future<void> _synchronizeRecherches() async {
    // TODO: Implémenter la synchronisation avec le serveur
    print('🔄 Synchronisation des recherches...');
  }

  Future<void> _synchronizeDocuments() async {
    // TODO: Implémenter la synchronisation avec le serveur
    print('🔄 Synchronisation des documents...');
  }

  // Nettoyage des données hors-ligne
  Future<void> clearOfflineData() async {
    try {
      await _conversationsBox.clear();
      await _recherchesBox.clear();
      await _documentsBox.clear();
      
      print('🗑️ Données hors-ligne supprimées');
    } catch (e) {
      print('❌ Erreur suppression données hors-ligne: $e');
    }
  }

  // Statistiques hors-ligne
  Map<String, int> getOfflineStats() {
    return {
      'conversations': _conversationsBox.length,
      'recherches': _recherchesBox.length,
      'documents': _documentsBox.length,
    };
  }

  // Vérification du statut
  bool get isOnline => _isOnline;
  bool get isInitialized => _isInitialized;

  // Dispose
  void dispose() {
    _connectivitySubscription.cancel();
    _conversationsBox.close();
    _recherchesBox.close();
    _documentsBox.close();
  }
}
