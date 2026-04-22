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
  String roleUtilisateur = '';
  int? patientId;
  int onglet = 0;
  List<dynamic> patients = [];
  Map<String, dynamic>? stats;
  Map<String, dynamic> badges = {'rappel': 0, 'message': 0, 'critique': 0};
  List<dynamic> ordonnancesPatient = [];

  bool modeSombre = false;
  String langue = 'fr';
  bool notifEmail = true;
  bool notifSms = false;
  bool notifPush = true;
  bool rappelsAuto = true;
  bool _refreshEnCours = false;
  bool chargeOcrIa = false;

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
    final token = await _storage.read(key: 'warms_access');
    if (token == null || token.isEmpty) return;
    _dio.options.headers['Authorization'] = 'Bearer $token';
    final access = await _rafraichirAccessToken();
    if (access == null) {
      await _deconnexion();
      return;
    }
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
      final refresh = rep.data['refresh'] as String?;
      if (access == null || access.isEmpty) {
        setState(() => message = 'Token invalide reçu.');
        return;
      }
      await _storage.write(key: 'warms_access', value: access);
      if (refresh != null && refresh.isNotEmpty) {
        await _storage.write(key: 'warms_refresh', value: refresh);
      }
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
        roleUtilisateur = (data['role'] ?? '').toString();
        langue = (data['langue_interface'] as String?) == 'en' ? 'en' : 'fr';
        modeSombre = data['mode_sombre'] == true;
        notifEmail = prefs['email'] == null ? true : prefs['email'] == true;
        notifSms = prefs['sms'] == true;
        notifPush = prefs['push'] == null ? true : prefs['push'] == true;
        rappelsAuto = prefs['rappels_auto'] == null ? true : prefs['rappels_auto'] == true;
      });
      await _chargerBadges();
      if (roleUtilisateur == 'patient') {
        await Future.wait([_chargerProfilPatient(), _chargerOrdonnancesPatient()]);
      }
      await Future.wait([_chargerPatients(), _chargerStats()]);
    } on DioException {
      setState(() => message = 'Impossible de charger le profil.');
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
      final rep = await _dio.get('/patients/me/');
      final data = rep.data as Map<String, dynamic>;
      setState(() => patientId = data['id'] as int?);
    } on DioException {
      // non bloquant
    }
  }

  Future<void> _envoyerAvisPatient() async {
    if (patientId == null) return;
    try {
      await _dio.post('/avis/', data: {
        'patient': patientId,
        'note': 5,
        'commentaire': 'Merci pour la prise en charge.',
      });
      setState(() => message = 'Avis envoyé.');
    } on DioException {
      setState(() => message = 'Impossible d\'envoyer l\'avis.');
    }
  }

  Future<void> _chargerOrdonnancesPatient() async {
    try {
      final rep = await _dio.get('/prescriptions/me/');
      setState(() => ordonnancesPatient = rep.data as List<dynamic>);
    } on DioException {
      // non bloquant
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
    await _storage.delete(key: 'warms_refresh');
    _dio.options.headers.remove('Authorization');
    setState(() {
      connecte = false;
      prenomNom = '';
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
    } on DioException {
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
            onPressed: () async {
              final rep = await _dio.get('/statistiques/parcours-patient/');
              final d = rep.data as Map<String, dynamic>;
              setState(() => message = 'Warms: ${d['avant']} avant vous, ${d['apres']} après vous.');
            },
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Warms'),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            onPressed: () => setState(
              () => message = 'Conversation patient/chirurgien/infirmière disponible dans Messagerie.',
            ),
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
              } on DioException {
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
