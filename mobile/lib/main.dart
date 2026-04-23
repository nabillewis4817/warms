import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  runApp(const MaterialApp(
    home: WarmsMobileApp(),
    debugShowCheckedModeBanner: false,
    localizationsDelegates: [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: [
      const Locale('fr', 'FR'),
      const Locale('en', 'US'),
    ],
  ));
}

class WarmsMobileApp extends StatefulWidget {
  const WarmsMobileApp({super.key});

  @override
  State<WarmsMobileApp> createState() => _WarmsMobileAppState();
}

class _WarmsMobileAppState extends State<WarmsMobileApp> {
  final _storage = const FlutterSecureStorage();
  final _dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:8000/api/v1'));

  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool connecte = false;
  bool chargement = false;
  String message = '';
  String prenomNom = '';
  String roleUtilisateur = '';
  int? patientId;
  int onglet = 0;
  List<dynamic> patients = [];
  Map<String, dynamic>? stats;
  Map<String, dynamic> badges = {'rappel': 0, 'message': 0, 'critique': 0};
  List<dynamic> ordonnancesPatient = [];
  
  // Variables pour le chat WARMS mobile
  List<String> warmsMessages = [];
  List<String> warmsResponses = [];
  final TextEditingController _warmsController = TextEditingController();

  bool modeSombre = false;
  String langue = 'fr';
  bool notifEmail = true;
  bool notifSms = false;
  bool notifPush = true;
  bool rappelsAuto = true;
  bool _refreshEnCours = false;
  bool chargeOcrIa = false;
  List<Map<String, dynamic>> messages = [];

  @override
  void initState() {
    super.initState();
    _configurerIntercepteurAuth();
    _restaurerSession();
  }

  void _configurerIntercepteurAuth() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) async {
          final status = error.response?.statusCode;
          final dejaRetente = error.requestOptions.extra['retry401'] == true;
          if (status != 401 || dejaRetente) {
            return handler.next(error);
          }
          final nouveauAccess = await _rafraichirAccessToken();
          if (nouveauAccess == null) {
            return handler.next(error);
          }
          final opts = error.requestOptions;
          opts.headers['Authorization'] = 'Bearer $nouveauAccess';
          opts.extra['retry401'] = true;
          final rep = await _dio.fetch(opts);
          return handler.resolve(rep);
        },
      ),
    );
  }

  Future<void> _restaurerSession() async {
    try {
      final token = await _storage.read(key: 'warms_access');
      if (token == null || token.isEmpty) {
        print('Aucun token trouvé, reste sur écran de connexion');
        return;
      }
      
      print('Token trouvé, tentative de restauration de session');
      _dio.options.headers['Authorization'] = 'Bearer $token';
      
      // Vérifier si le token est valide en essayant de rafraîchir
      final access = await _rafraichirAccessToken();
      if (access == null) {
        print('Token invalide, déconnexion');
        await _deconnexion();
        return;
      }
      
      print('Session restaurée avec succès, chargement du profil');
      await _chargerProfil();
    } catch (e) {
      print('Erreur lors de la restauration de session: $e');
      await _deconnexion();
    }
  }

  Future<void> _connexion() async {
    setState(() {
      chargement = true;
      message = '';
    });
    
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text;
    
    print('Tentative de connexion avec: $username');
    
    try {
      print('Envoi de la requête d\'authentification...');
      final rep = await _dio.post('/personnel/auth/token/', data: {
        'username': username,
        'password': password,
      });
      
      print('Réponse reçue: ${rep.statusCode}');
      print('Données: ${rep.data}');
      
      final access = rep.data['access'] as String?;
      final refresh = rep.data['refresh'] as String?;
      
      if (access == null || access.isEmpty) {
        setState(() => message = 'Token d\'accès invalide reçu du serveur.');
        return;
      }
      
      await _storage.write(key: 'warms_access', value: access);
      if (refresh != null && refresh.isNotEmpty) {
        await _storage.write(key: 'warms_refresh', value: refresh);
      }
      
      _dio.options.headers['Authorization'] = 'Bearer $access';
      print('Authentification réussie, chargement du profil...');
      await _chargerProfil();
      
    } on DioError catch (e) {
      print('Erreur de connexion: ${e.response?.statusCode} - ${e.message}');
      print('Données d\'erreur: ${e.response?.data}');
      
      String messageErreur = 'Échec de connexion';
      if (e.response?.statusCode == 401) {
        messageErreur = 'Identifiants incorrects. Vérifiez votre username et mot de passe.';
      } else if (e.response?.statusCode == 404) {
        messageErreur = 'Service d\'authentification indisponible.';
      } else if (e.type == DioErrorType.connectionTimeout) {
        messageErreur = 'Délai de connexion dépassé. Vérifiez votre connexion.';
      } else if (e.type == DioErrorType.connectionError) {
        messageErreur = 'Impossible de se connecter au serveur. Vérifiez que le backend est démarré.';
      }
      
      setState(() => message = messageErreur);
    } catch (e) {
      print('Erreur inattendue lors de la connexion: $e');
      setState(() => message = 'Erreur inattendue lors de la connexion.');
    } finally {
      setState(() => chargement = false);
    }
  }

  Future<void> _chargerProfil() async {
    try {
      print('Chargement du profil utilisateur...');
      final rep = await _dio.get('/personnel/me/');
      final data = rep.data as Map<String, dynamic>;
      
      print('Profil chargé: ${data['username']} - Role: ${data['role']}');
      
      final prefs = (data['preferences_notifications'] as Map?)?.cast<String, dynamic>() ?? {};
      setState(() {
        connecte = true;
        prenomNom = '${data['prenom'] ?? ''} ${data['nom'] ?? ''}'.trim();
        roleUtilisateur = (data['role'] ?? '').toString();
        langue = (data['langue_interface'] as String?) == 'en' ? 'en' : 'fr';
        modeSombre = data['mode_sombre'] == true;
        notifEmail = prefs['email'] == null ? true : prefs['email'] == true;
        notifSms = prefs['sms'] == true;
        notifPush = prefs['push'] == null ? true : prefs['push'] == true;
        rappelsAuto = prefs['rappels_auto'] == null ? true : prefs['rappels_auto'] == true;
      });
      
      print('Chargement des badges...');
      await _chargerBadges();
      
      if (roleUtilisateur == 'patient') {
        print('Chargement des données spécifiques au patient...');
        await Future.wait([_chargerProfilPatient(), _chargerOrdonnancesPatient()]);
      }
      
      print('Chargement des données générales...');
      await Future.wait([_chargerPatients(), _chargerStats()]);
      
      print('Profil et données chargés avec succès');
    } on DioError catch (e) {
      print('Erreur Dio lors du chargement du profil: ${e.response?.statusCode} - ${e.message}');
      setState(() => message = 'Impossible de charger le profil (${e.response?.statusCode}).');
      await _deconnexion();
    } catch (e) {
      print('Erreur inattendue lors du chargement du profil: $e');
      setState(() => message = 'Erreur lors du chargement du profil.');
      await _deconnexion();
    }
  }

  Future<void> _chargerPatients() async {
    try {
      final rep = await _dio.get('/patients/');
      setState(() => patients = rep.data as List<dynamic>);
    } on DioError {
      // silencieux pour éviter de bloquer l'app en cas d'erreur ponctuelle
    }
  }

  Future<void> _chargerStats() async {
    try {
      final rep = await _dio.get('/statistiques/vue-generale/');
      setState(() => stats = (rep.data as Map<String, dynamic>));
    } on DioError {
      // silencieux, le dashboard affichera un message de fallback
    }
  }

  Future<void> _chargerBadges() async {
    try {
      final rep = await _dio.get('/notifications/badges/');
      setState(() => badges = (rep.data as Map<String, dynamic>));
    } on DioError {
      // non bloquant
    }
  }

  Future<void> _chargerProfilPatient() async {
    try {
      print('Chargement du profil patient...');
      final rep = await _dio.get('/patients/me/');
      final data = rep.data as Map<String, dynamic>;
      
      print('Profil patient chargé: ID ${data['id']} - Dossier: ${data['numero_dossier']}');
      setState(() => patientId = data['id'] as int?);
    } on DioError catch (e) {
      print('Erreur lors du chargement du profil patient: ${e.response?.statusCode} - ${e.message}');
      // Ne pas bloquer l'application, mais logger l'erreur
    } catch (e) {
      print('Erreur inattendue lors du chargement du profil patient: $e');
    }
  }

  Future<void> _envoyerAvisPatient() async {
    if (patientId == null) return;
    
    // Confirmation avec alert Flutter
    bool confirme = false;
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Envoyer un avis'),
          content: const Text('Voulez-vous envoyer un avis de satisfaction pour votre prise en charge ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Envoyer'),
            ),
          ],
        );
      },
    ).then((value) => confirme = value ?? false);
    
    if (!confirme) return;
    
    try {
      await _dio.post('/avis/', data: {
        'patient': patientId,
        'note': 5,
        'commentaire': 'Merci pour la prise en charge.',
      });
      setState(() => message = 'Avis envoyé avec succès !');
    } on DioError catch (e) {
      setState(() => message = 'Impossible d\'envoyer l\'avis (${e.response?.statusCode}).');
    }
  }

  Future<void> _chargerOrdonnancesPatient() async {
    try {
      print('Chargement des ordonnances patient...');
      final rep = await _dio.get('/prescriptions/me/');
      final ordonnances = rep.data as List<dynamic>;
      
      print('Ordonnances patient chargées: ${ordonnances.length} ordonnance(s)');
      setState(() => ordonnancesPatient = ordonnances);
    } on DioError catch (e) {
      print('Erreur lors du chargement des ordonnances patient: ${e.response?.statusCode} - ${e.message}');
      // Ne pas bloquer l'application, mais logger l'erreur
    } catch (e) {
      print('Erreur inattendue lors du chargement des ordonnances patient: $e');
    }
  }

  Future<void> _sauvegarderPreferences() async {
    try {
      await _dio.patch('/personnel/me/preferences/', data: {
        'langue_interface': langue,
        'mode_sombre': modeSombre,
        'preferences_notifications': {
          'email': notifEmail,
          'sms': notifSms,
          'push': notifPush,
          'rappels_auto': rappelsAuto,
        }
      });
      setState(() => message = langue == 'fr' ? 'Préférences enregistrées.' : 'Preferences saved.');
    } on DioError {
      setState(() => message = langue == 'fr' ? 'Erreur de sauvegarde.' : 'Save failed.');
    }
  }

  Future<void> _afficherConversations() async {
    try {
      setState(() => message = 'Chargement des conversations...');
      
      // Récupérer les conversations du patient
      final response = await _dio.get('/conversations/');
      final conversations = response.data as List<dynamic>;
      
      // Si aucune conversation, en créer une automatiquement
      if (conversations.isEmpty) {
        await _creerConversationAuto();
        return;
      }
      
      // Ouvrir directement la première conversation
      final conversation = conversations.first as Map<String, dynamic>;
      await _afficherMessagesConversation(conversation['id']);
      
      setState(() => message = 'Conversation ouverte avec succès.');
    } on DioError catch (e) {
      setState(() => message = 'Erreur lors du chargement des conversations (${e.response?.statusCode}).');
    } catch (e) {
      setState(() => message = 'Erreur inattendue lors du chargement des conversations.');
    }
  }

  Future<void> _creerConversationAuto() async {
    try {
      setState(() => message = 'Création de votre conversation...');
      
      // Créer une conversation automatiquement pour le patient
      final response = await _dio.post('/conversations/', data: {
        'titre': 'Ma conversation avec le cabinet',
        'type_conversation': 'patient'
      });
      
      final conversation = response.data as Map<String, dynamic>;
      await _afficherMessagesConversation(conversation['id']);
      
      setState(() => message = 'Conversation créée et ouverte avec succès.');
    } on DioError catch (e) {
      setState(() => message = 'Erreur lors de la création de la conversation (${e.response?.statusCode}).');
    } catch (e) {
      setState(() => message = 'Erreur inattendue lors de la création de la conversation.');
    }
  }

  Future<void> _afficherMessagesConversation(int conversationId) async {
    try {
      setState(() => message = 'Chargement des messages...');
      
      // Récupérer les messages de la conversation
      final response = await _dio.get('/conversations/$conversationId/messages/');
      final messages = response.data as List<dynamic>;
      
      // Marquer les messages comme lus
      try {
        await _dio.post('/conversations/$conversationId/marquer_lus/');
      } catch (e) {
        print('Erreur lors du marquage des messages comme lus: $e');
      }
      
      // Afficher les messages dans une fenêtre de dialogue
      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.8,
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.chat, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Conversation',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  // Messages
                  Expanded(
                    child: ListView.builder(
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isMe = message['envoyeur'] == 'moi';
                        final timestamp = message['timestamp'] as DateTime;
                        final estLu = message['est_lu'] ?? false;
                        final estRecu = message['est_recu'] ?? false;
                        
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: Row(
                            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                            children: [
                              if (!isMe) ...[
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.blue.shade100,
                                  child: Icon(Icons.person, color: Colors.blue.shade800, size: 16),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isMe ? Colors.blue.shade600 : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        message['contenu'] ?? '',
                                        style: TextStyle(
                                          color: isMe ? Colors.white : Colors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: isMe ? Colors.white70 : Colors.black54,
                                            ),
                                          ),
                                          if (!isMe) ...[
                                            const SizedBox(width: 8),
                                            Icon(
                                              estLu ? Icons.done_all : Icons.done,
                                              size: 16,
                                              color: isMe ? Colors.white70 : Colors.black54,
                                            ),
                                          ],
                                          if (isMe) ...[
                                            const SizedBox(width: 4),
                                            Icon(
                                              estRecu ? Icons.done_all : Icons.done,
                                              size: 12,
                                              color: Colors.white70,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (isMe) ...[
                                const SizedBox(width: 8),
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.blue.shade800,
                                  child: Icon(Icons.person, color: Colors.white, size: 16),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
      
      setState(() => message = 'Messages chargés avec succès.');
    } on DioError catch (e) {
      setState(() => message = 'Erreur lors du chargement des messages (${e.response?.statusCode}).');
    } catch (e) {
      setState(() => message = 'Erreur inattendue lors du chargement des messages.');
    }
  }

  Future<void> _mettreAJourBadges() async {
    try {
      final response = await _dio.get('/notifications/badges/');
      final newBadges = response.data as Map<String, dynamic>;
      setState(() => badges = newBadges);
    } on DioError catch (e) {
      print('Erreur lors de la mise à jour des badges: ${e.response?.statusCode}');
    } catch (e) {
      print('Erreur inattendue lors de la mise à jour des badges: $e');
    }
  }

  Future<void> _ouvrirWarmsMobile() async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.blue),
              SizedBox(width: 8),
              Text('WARMS IA Assistant'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 500,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.blue.shade50, Colors.purple.shade50],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        // Header
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.blue,
                                child: Icon(Icons.smart_toy, color: Colors.white),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('WARMS', style: TextStyle(fontWeight: FontWeight.bold)),
                                    Text('Votre assistant médical intelligent', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Messages
                        Expanded(
                          child: ListView(
                            padding: EdgeInsets.all(16),
                            children: [
                              _buildWarmsMessage('Bonjour ! Je suis WARMS, votre assistant médical. Comment puis-je vous aider aujourd\'hui ?'),
                              if (warmsMessages.isNotEmpty) ...[
                                for (int i = 0; i < warmsMessages.length; i++) ...[
                                  _buildUserMessage(warmsMessages[i]),
                                  if (i < warmsResponses.length)
                                    _buildWarmsMessage(warmsResponses[i] ?? 'Je réfléchis à votre question...'),
                                ],
                              ],
                            ],
                          ),
                        ),
                        
                        // Input
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _warmsController,
                                  decoration: InputDecoration(
                                    hintText: 'Posez votre question médicale...',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(25),
                                    ),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              IconButton(
                                onPressed: () => _envoyerMessageWarms(),
                                icon: Icon(Icons.send, color: Colors.blue),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWarmsMessage(String message) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.blue,
            child: Icon(Icons.smart_toy, color: Colors.white, size: 16),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(message),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserMessage(String message) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(message),
            ),
          ),
          SizedBox(width: 8),
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.green,
            child: Icon(Icons.person, color: Colors.white, size: 16),
          ),
        ],
      ),
    );
  }

  Future<void> _envoyerMessageWarms() async {
    final message = _warmsController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      warmsMessages.add(message);
      warmsResponses.add('Recherche en cours...');
    });
    _warmsController.clear();

    // Simuler une recherche web et réponse de l'IA
    await Future.delayed(Duration(seconds: 2));
    
    String response = await _simulerReponseWarms(message);
    
    setState(() {
      warmsResponses[warmsResponses.length - 1] = response;
    });
  }

  Future<String> _simulerReponseWarms(String question) async {
    // Simuler une recherche web basée sur les mots-clés
    question = question.toLowerCase();
    
    if (question.contains('rendez-vous') || question.contains('rdv')) {
      return 'Pour vos rendez-vous, vous pouvez consulter votre agenda dans l\'application. Les prochains rendez-vous apparaissent avec les détails du praticien et l\'heure. En cas d\'urgence, n\'hésitez pas à contacter le cabinet directement au numéro indiqué dans vos contacts.';
    } else if (question.contains('symptôme') || question.contains('mal') || question.contains('douleur')) {
      return 'Les symptômes que vous décrivez peuvent avoir plusieurs causes. Je vous recommande de consulter votre médecin traitant pour un diagnostic précis. En attendant, vous pouvez prendre du repos et surveiller l\'évolution de vos symptômes. En cas d\'urgence, contactez les services d\'urgence.';
    } else if (question.contains('médicament') || question.contains('traitement')) {
      return 'Concernant vos médicaments, il est important de suivre la prescription de votre médecin. Ne modifiez jamais votre traitement sans avis médical. Si vous avez des effets secondaires, contactez votre médecin ou votre pharmacien.';
    } else if (question.contains('avant') || question.contains('après')) {
      return 'Selon les statistiques du cabinet, il y a généralement quelques patients en attente avant votre rendez-vous. Après votre consultation, n\'hésitez pas à poser toutes vos questions au praticien. Vous pouvez également demander une ordonnance si nécessaire.';
    } else if (question.contains('maladie') || question.contains('pathologie')) {
      return 'Chaque maladie est spécifique et nécessite une prise en charge personnalisée. Votre médecin pourra vous donner des informations précises sur votre état de santé. N\'hésitez pas à lui poser des questions lors de votre prochain rendez-vous.';
    } else {
      return 'Je comprends votre question. Pour une réponse précise et adaptée à votre situation, je vous recommande de consulter votre médecin traitant. Il pourra vous donner des conseils personnalisés. N\'hésitez pas à noter vos questions pour votre prochain rendez-vous.';
    }
  }

  Future<void> _deconnexion() async {
    // Confirmation avec alert Flutter
    bool confirme = false;
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Déconnexion'),
          content: const Text('Voulez-vous vraiment vous déconnecter ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Se déconnecter'),
            ),
          ],
        );
      },
    ).then((value) => confirme = value ?? false);
    
    if (!confirme) return;
    
    await _storage.delete(key: 'warms_access');
    await _storage.delete(key: 'warms_refresh');
    _dio.options.headers.remove('Authorization');
    setState(() {
      connecte = false;
      prenomNom = '';
      message = 'Déconnecté avec succès';
    });
  }

  Future<String?> _rafraichirAccessToken() async {
    if (_refreshEnCours) return null;
    _refreshEnCours = true;
    try {
      final refresh = await _storage.read(key: 'warms_refresh');
      if (refresh == null || refresh.isEmpty) return null;
      final rep = await _dio.post('/personnel/auth/token/refresh/', data: {
        'refresh': refresh,
      });
      final access = rep.data['access'] as String?;
      if (access == null || access.isEmpty) return null;
      await _storage.write(key: 'warms_access', value: access);
      _dio.options.headers['Authorization'] = 'Bearer $access';
      return access;
    } on DioError {
      return null;
    } finally {
      _refreshEnCours = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1E4DB7),
      brightness: modeSombre ? Brightness.dark : Brightness.light,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Warm's Mobile",
      theme: ThemeData(
        colorScheme: colorScheme,
        scaffoldBackgroundColor: modeSombre ? const Color(0xFF0D1B3E) : const Color(0xFFF0F4FF),
        useMaterial3: true,
      ),
      home: connecte
          ? (roleUtilisateur == 'patient' ? _buildEcranPatient() : _buildEcranPreferences())
          : _buildEcranConnexion(),
    );
  }

  Widget _buildEcranPatient() {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Espace patient"),
        backgroundColor: const Color(0xFF0D1B3E),
        foregroundColor: Colors.white,
        actions: [
          if ((badges['message'] ?? 0) > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: Text('Msg ${badges['message']}'),
                backgroundColor: const Color(0xFF22C55E),
              ),
            ),
          IconButton(onPressed: _deconnexion, icon: const Icon(Icons.logout)),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            onPressed: () => _ouvrirWarmsMobile(),
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Warms'),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            onPressed: () => _afficherConversations(),
            icon: const Icon(Icons.forum),
            label: const Text('Conversation'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionCard(
            title: 'Mon suivi',
            children: [
              ListTile(title: Text('Patient: $prenomNom')),
              if ((badges['rappel'] ?? 0) > 0)
                ListTile(
                  leading: const Icon(Icons.notifications_active, color: Colors.amber),
                  title: Text('Rappels: ${badges['rappel']}'),
                ),
              if ((badges['critique'] ?? 0) > 0)
                ListTile(
                  leading: const Icon(Icons.warning, color: Colors.red),
                  title: Text('Critiques: ${badges['critique']}'),
                ),
              if (message.isNotEmpty) Padding(padding: const EdgeInsets.all(8), child: Text(message)),
            ],
          ),
          const SizedBox(height: 12),
          _sectionCard(
            title: 'Ordonnances PDF',
            children: ordonnancesPatient.isEmpty
                ? [const ListTile(title: Text('Aucune ordonnance.'))]
                : ordonnancesPatient
                    .map(
                      (o) => ListTile(
                        leading: const Icon(Icons.picture_as_pdf, color: Color(0xFFB91C1C)),
                        title: Text((o['titre'] ?? 'Ordonnance').toString()),
                        subtitle: Text((o['cree_le'] ?? '').toString()),
                        trailing: const Icon(Icons.open_in_new),
                      ),
                    )
                    .toList(),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _envoyerAvisPatient,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: const LinearGradient(colors: [Color(0xFF93C5FD), Color(0xFF60A5FA)]),
              ),
              child: const Text("Qu'en pensez vous", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEcranConnexion() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF6F9FF), Color(0xFFEAF0FF), Color(0xFFDCE8FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -40,
              right: -30,
              child: _decorativeCircle(130, const Color(0x221E4DB7)),
            ),
            Positioned(
              bottom: 80,
              left: -20,
              child: _decorativeCircle(90, const Color(0x221A2E6B)),
            ),
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    width: 430,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x2A0D1B3E),
                          blurRadius: 28,
                          offset: Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_hospital_rounded, size: 44, color: Color(0xFF1A2E6B)),
                        const SizedBox(height: 8),
                        const Text(
                          "Warm's Mobile",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A2E6B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text("Connexion sécurisée", style: TextStyle(color: Color(0xFF4A5568))),
                        const SizedBox(height: 18),
                        TextField(
                          controller: _usernameCtrl,
                          decoration: _inputDecoration('Username', Icons.person_outline),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passwordCtrl,
                          obscureText: true,
                          decoration: _inputDecoration('Mot de passe', Icons.lock_outline),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: chargement ? null : _connexion,
                            icon: const Icon(Icons.login),
                            label: Text(chargement ? 'Connexion...' : 'Se connecter'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF1E4DB7),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        if (message.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(message, style: const TextStyle(color: Color(0xFFB00020))),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEcranPreferences() {
    return Scaffold(
      appBar: AppBar(
        title: Text(langue == 'fr' ? "Paramètres et personnalisation" : 'Settings and personalization'),
        backgroundColor: const Color(0xFF0D1B3E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () async {
              await Future.wait([_chargerPatients(), _chargerStats()]);
              setState(() => message = langue == 'fr' ? 'Données actualisées.' : 'Data refreshed.');
            },
            icon: const Icon(Icons.refresh, color: Color(0xFF22C55E)),
          ),
          IconButton(onPressed: _deconnexion, icon: const Icon(Icons.logout)),
        ],
      ),
      body: IndexedStack(
        index: onglet,
        children: [
          _buildDashboard(),
          _buildPatients(),
          _buildPreferences(),
        ],
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'ocr',
            onPressed: () async {
              setState(() => chargeOcrIa = true);
              await Future.delayed(const Duration(milliseconds: 450));
              setState(() {
                chargeOcrIa = false;
                message = langue == 'fr'
                    ? 'OCR ouvert: choisissez upload ou caméra.'
                    : 'OCR opened: choose upload or camera.';
              });
            },
            icon: const Icon(Icons.document_scanner),
            label: const Text('OCR'),
          ),
          const SizedBox(width: 10),
          FloatingActionButton.extended(
            heroTag: 'warms-ia',
            onPressed: () async {
              setState(() => chargeOcrIa = true);
              try {
                final rep = await _dio.get('/statistiques/vue-generale/');
                final k = (rep.data['kpis'] as Map<String, dynamic>? ?? {});
                setState(() {
                  message =
                      'Warms: ${k['rendez_vous_30j'] ?? 0} RDV / ${k['consultations_30j'] ?? 0} consultations.';
                });
              } on DioError {
                setState(() => message = langue == 'fr' ? 'Warms indisponible temporairement.' : 'Warms temporarily unavailable.');
              } finally {
                setState(() => chargeOcrIa = false);
              }
            },
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Warms'),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: onglet,
        onDestinationSelected: (index) => setState(() => onglet = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.people), label: 'Patients'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Paramètres'),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    final kpis = (stats?['kpis'] as Map<String, dynamic>?) ?? {};
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionCard(
          title: langue == 'fr' ? 'Tableau de bord' : 'Dashboard',
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _chargerStats,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF22C55E)),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.medical_services_outlined, color: Color(0xFF1E4DB7)),
              title: Text(langue == 'fr' ? 'Consultations (30j)' : 'Consultations (30d)'),
              trailing: Text('${kpis['consultations_30j'] ?? '-'}'),
            ),
            ListTile(
              leading: const Icon(Icons.event_available_outlined, color: Color(0xFF1E4DB7)),
              title: Text(langue == 'fr' ? 'Rendez-vous (30j)' : 'Appointments (30d)'),
              trailing: Text('${kpis['rendez_vous_30j'] ?? '-'}'),
            ),
            ListTile(
              leading: const Icon(Icons.event_busy_outlined, color: Color(0xFF1E4DB7)),
              title: Text(langue == 'fr' ? 'Absences (30j)' : 'No-shows (30d)'),
              trailing: Text('${kpis['absents_30j'] ?? '-'}'),
            ),
            ListTile(
              leading: const Icon(Icons.analytics_outlined, color: Color(0xFF1E4DB7)),
              title: Text(langue == 'fr' ? 'Taux absentéisme' : 'No-show rate'),
              trailing: Text('${kpis['taux_absenteisme_30j'] ?? '-'}%'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPatients() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionCard(
          title: langue == 'fr' ? 'Patients' : 'Patients',
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _chargerPatients,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF22C55E)),
                ),
              ),
            ),
            if (patients.isEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(langue == 'fr' ? 'Aucun patient chargé.' : 'No patients loaded.'),
              )
            else
              ...patients.take(40).map((p) {
                final nom = '${p['prenom'] ?? ''} ${p['nom'] ?? ''}'.trim();
                return ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0x1A1E4DB7),
                    child: Icon(Icons.person_outline, color: Color(0xFF1A2E6B)),
                  ),
                  title: Text(nom.isEmpty ? 'Patient' : nom),
                  subtitle: Text('${p['telephone'] ?? '-'}  •  ${p['email'] ?? '-'}'),
                );
              }),
          ],
        ),
      ],
    );
  }

  Widget _buildPreferences() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (prenomNom.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              '${langue == 'fr' ? 'Connecté: ' : 'Signed in: '}$prenomNom',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        _sectionCard(
          title: langue == 'fr' ? 'Interface' : 'Interface',
          children: [
            SwitchListTile(
              title: Text(langue == 'fr' ? 'Mode sombre' : 'Dark mode'),
              value: modeSombre,
              onChanged: (v) => setState(() => modeSombre = v),
            ),
            ListTile(
              title: Text(langue == 'fr' ? "Langue d'interface" : 'Interface language'),
              trailing: DropdownButton<String>(
                value: langue,
                items: const [
                  DropdownMenuItem(value: 'fr', child: Text('Français')),
                  DropdownMenuItem(value: 'en', child: Text('English')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => langue = value);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: langue == 'fr' ? 'Notifications et rappels' : 'Notifications and reminders',
          children: [
            SwitchListTile(
              title: const Text('Email'),
              value: notifEmail,
              onChanged: (v) => setState(() => notifEmail = v),
            ),
            SwitchListTile(
              title: const Text('SMS'),
              value: notifSms,
              onChanged: (v) => setState(() => notifSms = v),
            ),
            SwitchListTile(
              title: const Text('Push'),
              value: notifPush,
              onChanged: (v) => setState(() => notifPush = v),
            ),
            SwitchListTile(
              title: Text(langue == 'fr' ? 'Rappels automatiques' : 'Automatic reminders'),
              value: rappelsAuto,
              onChanged: (v) => setState(() => rappelsAuto = v),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ElevatedButton(onPressed: _sauvegarderPreferences, child: Text(langue == 'fr' ? 'Enregistrer' : 'Save')),
        if (message.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(message, style: const TextStyle(color: Colors.green)),
        ],
        if (chargeOcrIa) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
        ],
      ],
    );
  }

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Card(
      color: Colors.white.withValues(alpha: 0.97),
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A2E6B),
                ),
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _decorativeCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF1A2E6B)),
      filled: true,
      fillColor: const Color(0xFFF8FAFF),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFC7D6F7)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFC7D6F7)),
      ),
    );
  }
}

// #EbaJioloLewis
