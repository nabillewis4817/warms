import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';

void main() {
  runApp(const WarmsMobileApp());
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

  bool modeSombre = false;
  String langue = 'fr';
  bool notifEmail = true;
  bool notifSms = false;
  bool notifPush = true;
  bool rappelsAuto = true;

  @override
  void initState() {
    super.initState();
    _restaurerSession();
  }

  Future<void> _restaurerSession() async {
    final token = await _storage.read(key: 'warms_access');
    if (token == null || token.isEmpty) return;
    _dio.options.headers['Authorization'] = 'Bearer $token';
    await _chargerProfil();
  }

  Future<void> _connexion() async {
    setState(() {
      chargement = true;
      message = '';
    });
    try {
      final rep = await _dio.post('/personnel/auth/token/', data: {
        'username': _usernameCtrl.text.trim(),
        'password': _passwordCtrl.text,
      });
      final access = rep.data['access'] as String?;
      if (access == null || access.isEmpty) {
        setState(() => message = 'Token invalide reçu.');
        return;
      }
      await _storage.write(key: 'warms_access', value: access);
      _dio.options.headers['Authorization'] = 'Bearer $access';
      await _chargerProfil();
    } on DioException {
      setState(() => message = 'Échec de connexion. Vérifie tes identifiants.');
    } finally {
      setState(() => chargement = false);
    }
  }

  Future<void> _chargerProfil() async {
    try {
      final rep = await _dio.get('/personnel/me/');
      final data = rep.data as Map<String, dynamic>;
      final prefs = (data['preferences_notifications'] as Map?)?.cast<String, dynamic>() ?? {};
      setState(() {
        connecte = true;
        prenomNom = '${data['prenom'] ?? ''} ${data['nom'] ?? ''}'.trim();
        langue = (data['langue_interface'] as String?) == 'en' ? 'en' : 'fr';
        modeSombre = data['mode_sombre'] == true;
        notifEmail = prefs['email'] == null ? true : prefs['email'] == true;
        notifSms = prefs['sms'] == true;
        notifPush = prefs['push'] == null ? true : prefs['push'] == true;
        rappelsAuto = prefs['rappels_auto'] == null ? true : prefs['rappels_auto'] == true;
      });
    } on DioException {
      setState(() => message = 'Impossible de charger le profil.');
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

  Future<void> _deconnexion() async {
    await _storage.delete(key: 'warms_access');
    _dio.options.headers.remove('Authorization');
    setState(() {
      connecte = false;
      prenomNom = '';
    });
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
      home: connecte ? _buildEcranPreferences() : _buildEcranConnexion(),
    );
  }

  Widget _buildEcranConnexion() {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Warm's Mobile - Connexion"),
        backgroundColor: const Color(0xFF0D1B3E),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _usernameCtrl,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passwordCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Mot de passe'),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: chargement ? null : _connexion,
                child: Text(chargement ? 'Connexion...' : 'Se connecter'),
              ),
            ),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(message, style: const TextStyle(color: Colors.red)),
            ],
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
          IconButton(onPressed: _deconnexion, icon: const Icon(Icons.logout)),
        ],
      ),
      body: ListView(
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
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Card(
      color: Colors.white,
      elevation: 4,
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
}

// #EbaJioloLewis
