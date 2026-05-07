import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

// Import des écrans IA WARMS
import 'screens/ia_chat_screen.dart';
import 'screens/ia_recherche_screen.dart';
import 'screens/enhanced_chat_screen.dart';
import 'screens/splash_screen.dart';
import 'services/datetime_service.dart';

// Import du thème WARMS et composants
import 'themes/warms_theme.dart';
import 'widgets/warms_card.dart';

void main() {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  runApp(const WarmsMobileApp());
}

class WarmsMobileApp extends StatelessWidget {
  const WarmsMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WARMS Mobile',
      debugShowCheckedModeBanner: false,
      theme: WarmsTheme.lightTheme,
      darkTheme: WarmsTheme.darkTheme,
      themeMode: ThemeMode.system,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr', 'FR'),
        Locale('en', 'US'),
      ],
      locale: const Locale('fr', 'FR'),
      home: const SplashScreen(),
      routes: {
        '/main': (context) => const WarmsMobileAppBody(),
      },
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => const WarmsMobileAppBody(),
        );
      },
    );
  }
}

class WarmsMobileAppBody extends StatefulWidget {
  const WarmsMobileAppBody({super.key});

  @override
  State<WarmsMobileAppBody> createState() => _WarmsMobileAppBodyState();
}

class _WarmsMobileAppBodyState extends State<WarmsMobileAppBody> {
  final _storage = const FlutterSecureStorage();
  final _dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:8000/api/v1'));

  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  // Services WARMS
  final _dateTimeService = DateTimeService();

  bool connecte = false;
  bool chargement = false;
  bool showPassword = false;
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
  bool modeSombre = false;
  bool notifEmail = true;
  bool notifSms = true;
  bool notifPush = true;
  bool rappelsAuto = true;
  String langue = 'fr';
  final _warmsController = TextEditingController();

  // Variables du profil utilisateur
  String email = '';
  String telephone = '';
  String role = '';
  String qrCode = '';
  String photoProfil = '';

  @override
  void initState() {
    super.initState();
    _configurerIntercepteurAuth();
    _restaurerSession();
  }

  @override
  Widget build(BuildContext context) {
    return connecte
        ? (roleUtilisateur == 'patient' ? _buildEcranPatient() : _buildEcranPreferences())
        : _buildEcranConnexion();
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
      
      print('Session restaurée avec succès, chargement du profil...');
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
      
    } on DioException catch (e) {
      print('Erreur de connexion: ${e.response?.statusCode} - ${e.message}');
      print('Données d\'erreur: ${e.response?.data}');
      
      String messageErreur = 'Échec de connexion';
      if (e.response?.statusCode == 401) {
        messageErreur = 'Identifiants incorrects. Vérifiez votre username et mot de passe.';
      } else if (e.response?.statusCode == 404) {
        messageErreur = 'Service d\'authentification indisponible.';
      } else if (e.type == DioExceptionType.connectionTimeout) {
        messageErreur = 'Délai de connexion dépassé. Vérifiez votre connexion.';
      } else if (e.type == DioExceptionType.connectionError) {
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
    // ÉTAPE 1 — Affichage immédiat depuis le cache local
    final storedEmail = await _storage.read(key: 'user_email') ?? '';
    final storedPhone = await _storage.read(key: 'user_phone') ?? '';
    final storedRole = await _storage.read(key: 'user_role') ?? '';
    final storedQrCode = await _storage.read(key: 'user_qr_code') ?? '';
    final storedPhoto = await _storage.read(key: 'user_photo') ?? '';
    final storedName = await _storage.read(key: 'user_name') ?? '';
    
    setState(() {
      email = storedEmail;
      telephone = storedPhone;
      role = storedRole;
      qrCode = storedQrCode;
      photoProfil = storedPhoto;
      prenomNom = storedName;
    });

    // ÉTAPE 2 — Mise à jour depuis l'API
    print('Chargement du profil utilisateur...');
    final rep = await _dio.get('/personnel/me/');
    final data = rep.data as Map<String, dynamic>;

    print('Profil chargé: ${data['username']} - Role: ${data['role']}');

    final prefs = (data['preferences_notifications'] as Map?)
        ?.cast<String, dynamic>() ?? {};

    // Mettre à jour le cache local avec les nouvelles données
    await _storage.write(key: 'user_name', 
        value: '${data['prenom'] ?? ''} ${data['nom'] ?? ''}'.trim());
    await _storage.write(key: 'user_role', 
        value: (data['role'] ?? '').toString());
    await _storage.write(key: 'user_email', 
        value: (data['email'] ?? '').toString());

    setState(() {
      connecte = true;
      prenomNom = '${data['prenom'] ?? ''} ${data['nom'] ?? ''}'.trim();
      roleUtilisateur = (data['role'] ?? '').toString();
      langue = (data['langue_interface'] as String?) == 'en' ? 'en' : 'fr';
      modeSombre = data['mode_sombre'] == true;
      notifEmail = prefs['email'] == null ? true : prefs['email'] == true;
      notifSms = prefs['sms'] == true;
      notifPush = prefs['push'] == null ? true : prefs['push'] == true;
      rappelsAuto = prefs['rappels_auto'] == null 
          ? true : prefs['rappels_auto'] == true;
    });

    await _chargerBadges();

    if (roleUtilisateur == 'patient') {
      await Future.wait([
        _chargerProfilPatient(), 
        _chargerOrdonnancesPatient(),
      ]);
    }

    await Future.wait([_chargerPatients(), _chargerStats()]);

  } on DioException catch (e) {
    print('Erreur Dio: ${e.response?.statusCode} - ${e.message}');
    setState(() => message = 
        'Impossible de charger le profil (${e.response?.statusCode}).');
    await _deconnexion();
  } catch (e) {
    print('Erreur inattendue: $e');
    setState(() => message = 'Erreur lors du chargement du profil.');
    await _deconnexion();
  }
}

  Future<void> _chargerPatients() async {
    try {
      final rep = await _dio.get('/patients/');
      setState(() => patients = rep.data as List<dynamic>);
    } on DioException {
      // silencieux pour éviter de bloquer l'app en cas d'erreur ponctuelle
    }
  }

  Future<void> _chargerStats() async {
    try {
      final rep = await _dio.get('/statistiques/vue-generale/');
      setState(() => stats = (rep.data as Map<String, dynamic>));
    } on DioException {
      // silencieux, le dashboard affichera un message de fallback
    }
  }

  Future<void> _chargerBadges() async {
    try {
      final rep = await _dio.get('/notifications/badges/');
      setState(() => badges = (rep.data as Map<String, dynamic>));
    } on DioException {
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
    } on DioException catch (e) {
      print('Erreur lors du chargement du profil patient: ${e.response?.statusCode} - ${e.message}');
      // Ne pas bloquer l'application, mais logger l'erreur
    } catch (e) {
      print('Erreur inattendue lors du chargement du profil patient: $e');
    }
  }

  Future<void> _chargerOrdonnancesPatient() async {
    try {
      print('Chargement des ordonnances patient...');
      final rep = await _dio.get('/prescriptions/me/');
      final ordonnances = rep.data as List<dynamic>;
      
      print('Ordonnances patient chargées: ${ordonnances.length} ordonnance(s)');
      setState(() => ordonnancesPatient = ordonnances);
    } on DioException catch (e) {
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
    } on DioException {
      setState(() => message = langue == 'fr' ? 'Erreur de sauvegarde.' : 'Save failed.');
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
    } on DioException catch (e) {
      setState(() => message = 'Impossible d\'envoyer l\'avis (${e.response?.statusCode}).');
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
    } on DioException catch (e) {
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
    } on DioException catch (e) {
      setState(() => message = 'Erreur lors de la création de la conversation (${e.response?.statusCode}).');
    } catch (e) {
      setState(() => message = 'Erreur inattendue lors de la création de la conversation.');
    }
  }

  Future<void> _afficherMessagesConversation(int conversationId) async {
    try {
      setState(() => message = 'Chargement des messages...');
      
      // Récupérer les messages de la conversation avec gestion d'erreur améliorée
      final response = await _dio.get(
        '/conversations/$conversationId/messages/',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );
      
      if (response.statusCode != 200) {
        throw Exception('Erreur HTTP: ${response.statusCode}');
      }
      
      final messages = response.data as List<dynamic>? ?? [];
      
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
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue[600],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.medical_services,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'WARMS IA',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                          ),
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
                        final timestamp = message['timestamp'] != null 
                            ? DateTime.parse(message['timestamp'].toString()) 
                            : DateTime.now();
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
    } on DioException catch (e) {
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
    } on DioException catch (e) {
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
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
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
                            padding: const EdgeInsets.all(16),
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
                          padding: const EdgeInsets.all(16),
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
                                      borderSide: BorderSide.none,
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[100],
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                child: IconButton(
                                  onPressed: _envoyerMessageWarms,
                                  icon: const Icon(Icons.send, color: Colors.white),
                                ),
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
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWarmsMessage(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.blue.shade100,
            child: Icon(Icons.smart_toy, color: Colors.blue.shade800, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade600,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.right,
              ),
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            backgroundColor: Colors.blue.shade800,
            child: Icon(Icons.person, color: Colors.white, size: 20),
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
    
    try {
      final response = await _dio.post('/ia/chat/', data: {
        'message': message,
        'patient_id': patientId,
      });
      
      final responseData = response.data as Map<String, dynamic>;
      warmsResponses[warmsResponses.length - 1] = responseData['reponse'] ?? 'Désolé, je n\'ai pas pu traiter votre demande.';
      setState(() {});
    } catch (e) {
      warmsResponses[warmsResponses.length - 1] = 'Erreur de connexion. Veuillez réessayer.';
      setState(() {});
    }
  }

  Future<void> _ouvrirChatIA() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EnhancedChatScreen()),
    );
  }

  Future<void> _ouvrirRechercheIA() async {
    if (kDebugMode) {
      print('Ouverture de l\'écran de recherche IA');
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => IARechercheScreen(),
      ),
    );
  }

  Future<void> _deconnexion() async {
    try {
      await _storage.delete(key: 'warms_access');
      await _storage.delete(key: 'warms_refresh');
      _dio.options.headers.remove('Authorization');
      setState(() {
        connecte = false;
        prenomNom = '';
        message = 'Déconnecté avec succès';
      });
    } catch (e) {
      print('Erreur lors de la déconnexion: $e');
    }
  }

  Future<String?> _rafraichirAccessToken() async {
    try {
      final refresh = await _storage.read(key: 'warms_refresh');
      if (refresh == null || refresh.isEmpty) return null;
      
      final rep = await _dio.post('/personnel/auth/token/refresh/', data: {
        'refresh': refresh,
      });
      
      final access = rep.data['access'] as String?;
      if (access != null) {
        await _storage.write(key: 'warms_access', value: access);
        _dio.options.headers['Authorization'] = 'Bearer $access';
      }
      
      return access;
    } catch (e) {
      return null;
    }
  }

  /// Construit la barre d'application
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue[600],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.medical_services,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'WARMS IA',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
        ],
      ),
      backgroundColor: Colors.white,
      elevation: 0,
      actions: [
        // Widget Date/Heure en temps réel
        _buildDateTimeWidget(),
        const SizedBox(width: 8),
        // Bouton d'options
        IconButton(
          onPressed: _showOptions,
          icon: const Icon(Icons.more_vert),
          tooltip: 'Options',
        ),
      ],
    );
  }

  /// Construit le widget de date/heure stylisée pour l'app mobile
  Widget _buildDateTimeWidget() {
    return StreamBuilder<DateTime>(
      stream: _dateTimeService.currentDateTimeStream,
      builder: (context, snapshot) {
        final now = snapshot.data ?? DateTime.now();
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.blue[600]!,
                Colors.blue[400]!,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icône animée
              TweenAnimationBuilder(
                duration: const Duration(seconds: 2),
                tween: Tween<double>(begin: 0.8, end: 1.2),
                builder: (context, double scale, child) {
                  return Transform.scale(
                    scale: scale,
                    child: Icon(
                      Icons.access_time,
                      color: Colors.white,
                      size: 16,
                    ),
                  );
                },
              ),
              
              const SizedBox(width: 6),
              
              // Heure compacte
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _dateTimeService.formatTimeCompact(now),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _dateTimeService.formatDateCompact(now),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Affiche les options de l'application
  void _showOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Options'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Paramètres'),
              onTap: () {
                Navigator.pop(context);
                // Naviguer vers les paramètres
              },
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('À propos'),
              onTap: () {
                Navigator.pop(context);
                // Afficher les informations
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Déconnexion'),
              onTap: () {
                Navigator.pop(context);
                _deconnexion();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  /// Affiche un message à l'utilisateur
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green[600],
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildEcranConnexion() {
    return Scaffold(
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
            // Logo et titre
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.blue[600],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.medical_services,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'WARMS',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E4DB7),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Web & Mobile Administration Réseau de Santé',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 48),
            
            // Formulaire de connexion
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width - 64,
              ),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                    const Text(
                      'Connexion',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Champ username
                    TextField(
                      controller: _usernameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nom d\'utilisateur',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Champ password
                    TextField(
                      controller: _passwordCtrl,
                      obscureText: !showPassword,
                      decoration: InputDecoration(
                        labelText: 'Mot de passe',
                        prefixIcon: Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility),
                          onPressed: () {
                            setState(() => showPassword = !showPassword);
                          },
                        ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Bouton de connexion
                    Tooltip(
                      message: 'Connectez-vous pour accéder à votre compte WARMS',
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: chargement ? null : _connexion,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: WarmsTheme.warmsAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 8,
                            shadowColor: WarmsTheme.warmsBlue.withOpacity(0.3),
                          ),
                          child: Text(
                            chargement ? 'Connexion...' : 'Se connecter',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Message d'erreur
                    if (message.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                message,
                                style: const TextStyle(color: Color(0xFFB00020)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildEcranPatient() {
    return Scaffold(
      appBar: _buildAppBar(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Carte profil patient
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.blue[600],
                        child: const Icon(Icons.person, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Patient: $prenomNom',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if ((badges['rappel'] ?? 0) > 0)
                              Chip(
                                label: Text('Rappels: ${badges['rappel']}'),
                                backgroundColor: Colors.orange[100],
                              ),
                            if ((badges['critique'] ?? 0) > 0)
                              Chip(
                                label: Text('Critiques: ${badges['critique']}'),
                                backgroundColor: Colors.red[100],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Actions rapides
                  Wrap(
                    spacing: 8,
                    children: [
                      Tooltip(
                        message: 'Partagez votre expérience sur la prise en charge',
                        child: ElevatedButton.icon(
                          onPressed: _envoyerAvisPatient,
                          icon: const Icon(Icons.rate_review),
                          label: const Text('Envoyer un avis'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: WarmsTheme.warmsSuccess,
                            foregroundColor: Colors.white,
                            elevation: 8,
                            shadowColor: WarmsTheme.warmsSuccess.withOpacity(0.3),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'Consultez vos conversations et messages médicaux',
                        child: ElevatedButton.icon(
                          onPressed: _afficherConversations,
                          icon: const Icon(Icons.chat),
                          label: const Text('Messages'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: WarmsTheme.warmsInfo,
                            foregroundColor: Colors.white,
                            elevation: 8,
                            shadowColor: WarmsTheme.warmsInfo.withOpacity(0.3),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Ordonnances
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Mes ordonnances',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  if (ordonnancesPatient.isEmpty)
                    const Text('Aucune ordonnance trouvée')
                  else
                    ...ordonnancesPatient.take(5).map((ordonnance) => ListTile(
                      leading: const Icon(Icons.medication),
                      title: Text(ordonnance['medicament'] ?? 'Médicament'),
                      subtitle: Text(ordonnance['posologie'] ?? 'Posologie'),
                    )),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Boutons flottants d'actions
          Column(
            children: [
              // Bouton Chat IA amélioré avec Claude
              Tooltip(
                message: 'Discutez avec notre assistant médical IA propulsé par Claude',
                child: FloatingActionButton.extended(
                  onPressed: () => _ouvrirChatIA(),
                  icon: const Icon(Icons.smart_toy),
                  label: const Text('Chat IA'),
                  backgroundColor: WarmsTheme.warmsAccent,
                  heroTag: "chat_ia_claude",
                ),
              ),
              const SizedBox(height: 10),
              
              // Bouton Recherche IA
              Tooltip(
                message: 'Recherchez des informations médicales fiables et actualisées',
                child: FloatingActionButton.extended(
                  onPressed: () => _ouvrirRechercheIA(),
                  icon: const Icon(Icons.search),
                  label: const Text('Recherche IA'),
                  backgroundColor: WarmsTheme.warmsBlue,
                  heroTag: "recherche_ia",
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEcranPreferences() {
    return Scaffold(
      appBar: _buildAppBar(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Carte profil
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    langue == 'fr' ? "Paramètres et personnalisation" : 'Settings and personalization',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Profil utilisateur complet avec photo et QR code
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          WarmsTheme.warmsAccent.withOpacity(0.1),
                          WarmsTheme.warmsBlue.withOpacity(0.05),

                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: WarmsTheme.warmsAccent.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        // Photo de profil et informations
                        Row(
                          children: [
                            // Photo de profil
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: WarmsTheme.warmsBg,
                                border: Border.all(
                                  color: WarmsTheme.warmsAccent,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: WarmsTheme.warmsBlue.withOpacity(0.2),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 35,
                                    backgroundImage: photoProfil.isNotEmpty
                                        ? NetworkImage(photoProfil)
                                        : null,
                                    backgroundColor: WarmsTheme.warmsGray,
                                    child: photoProfil.isEmpty
                                        ? Icon(
                                            Icons.person,
                                            size: 40,
                                            color: Colors.white,
                                          )
                                        : null,
                                  ),
                                  // Bouton pour modifier la photo
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: GestureDetector(
                                      onTap: () {
                                        // TODO: Implémenter la modification de photo
                                      },
                                      child: Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.2),
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.camera_alt,
                                          size: 14,
                                          color: WarmsTheme.warmsAccent,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Informations utilisateur
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$prenomNom',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: WarmsTheme.warmsNavy,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    role,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: WarmsTheme.warmsGray,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    email,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: WarmsTheme.warmsGray,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    telephone,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: WarmsTheme.warmsGray,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        
                        // QR Code
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: WarmsTheme.warmsAccent.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.qr_code,
                                    color: WarmsTheme.warmsAccent,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    langue == 'fr' ? 'Mon QR Code' : 'My QR Code',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: WarmsTheme.warmsNavy,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  color: WarmsTheme.warmsBg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: WarmsTheme.warmsGray.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: qrCode.isNotEmpty
                                    ? Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.qr_code_scanner,
                                            size: 48,
                                            color: WarmsTheme.warmsAccent,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            langue == 'fr' ? 'Scannez pour accéder à votre carnet' : 'Scan to access your notebook',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: WarmsTheme.warmsGray,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.qr_code_2,
                                            size: 48,
                                            color: WarmsTheme.warmsGray.withOpacity(0.5),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            langue == 'fr' ? 'QR Code non disponible' : 'QR Code not available',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: WarmsTheme.warmsGray,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Bouton d'actualisation
                  Tooltip(
                    message: 'Actualiser les données patients et statistiques',
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await Future.wait([_chargerPatients(), _chargerStats()]);
                        setState(() => message = langue == 'fr' ? 'Données actualisées.' : 'Data refreshed.');
                      },
                      icon: const Icon(Icons.refresh),
                      label: Text(langue == 'fr' ? 'Actualiser' : 'Refresh'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: WarmsTheme.warmsBlue,
                        foregroundColor: Colors.white,
                        elevation: 8,
                        shadowColor: WarmsTheme.warmsBlue.withOpacity(0.3),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Message de succès
                  if (message.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        message,
                        style: const TextStyle(color: Colors.green),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Carte préférences
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    langue == 'fr' ? 'Interface' : 'Interface',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Mode sombre
                  SwitchListTile(
                    title: Text(langue == 'fr' ? 'Mode sombre' : 'Dark mode'),
                    value: modeSombre,
                    onChanged: (value) => setState(() => modeSombre = value),
                  ),
                  
                  // Langue
                  ListTile(
                    title: Text(langue == 'fr' ? "Langue d'interface" : 'Interface language'),
                    subtitle: Text(langue == 'fr' ? 'Français' : 'English'),
                    trailing: DropdownButton<String>(
                      value: langue,
                      items: const [
                        DropdownMenuItem(value: 'fr', child: Text('Français')),
                        DropdownMenuItem(value: 'en', child: Text('English')),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => langue = value!);
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Notifications
                  Text(
                    langue == 'fr' ? 'Notifications et rappels' : 'Notifications and reminders',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  SwitchListTile(
                    title: Text(langue == 'fr' ? 'Email' : 'Email'),
                    value: notifEmail,
                    onChanged: (value) => setState(() => notifEmail = value),
                  ),
                  SwitchListTile(
                    title: Text(langue == 'fr' ? 'SMS' : 'SMS'),
                    value: notifSms,
                    onChanged: (value) => setState(() => notifSms = value),
                  ),
                  SwitchListTile(
                    title: Text(langue == 'fr' ? 'Push' : 'Push'),
                    value: notifPush,
                    onChanged: (value) => setState(() => notifPush = value),
                  ),
                  SwitchListTile(
                    title: Text(langue == 'fr' ? 'Rappels automatiques' : 'Automatic reminders'),
                    value: rappelsAuto,
                    onChanged: (value) => setState(() => rappelsAuto = value),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Bouton de sauvegarde
                  Tooltip(
                    message: langue == 'fr' 
                      ? 'Enregistrer vos préférences et paramètres' 
                      : 'Save your preferences and settings',
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _sauvegarderPreferences,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: WarmsTheme.warmsAccent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 8,
                          shadowColor: WarmsTheme.warmsBlue.withOpacity(0.3),
                        ),
                        child: Text(
                          langue == 'fr' ? 'Enregistrer' : 'Save',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}