import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'models/utilisateur.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/personnel/personnel_home_screen.dart';
import 'screens/splash_screen.dart';
import 'services/auth_service.dart';
import 'services/patient_service.dart';
import 'services/profil_service.dart';
import 'themes/warms_theme.dart';

/// Mode clair/sombre courant, piloté par les préférences utilisateur et lu
/// par [WarmsApp].
///
/// Un [ValueNotifier] global et minimal plutôt qu'un gestionnaire d'état
/// complet (Riverpod, déclaré en dépendance mais pas adopté ailleurs dans
/// l'app) : un seul réglage à faire remonter jusqu'au [MaterialApp] racine,
/// ce qui ne justifie pas une dépendance supplémentaire.
class ThemeController {
  ThemeController._();
  static final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.system);
}

/// Racine de l'application : configure le thème, la localisation, et
/// délègue tout le reste de la navigation à [AppGate].
/// Clé de navigation globale de l'app.
///
/// [AppGate] est la route racine du [MaterialApp] ; les écrans patient/
/// personnel sont atteints par des `Navigator.push` empilés par-dessus
/// elle. Sans cette clé, une déconnexion déclenchée depuis un écran
/// empilé (ex: Profil ouvert depuis l'accueil patient) ne fait que
/// reconstruire la route racine en arrière-plan — l'écran empilé reste
/// affiché au-dessus et l'utilisateur a l'impression que le bouton ne
/// fait rien. Voir [_AppGateState._deconnexion].
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class WarmsApp extends StatelessWidget {
  const WarmsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (context, themeMode, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: "Wam's Mobile",
          debugShowCheckedModeBanner: false,
          theme: WarmsTheme.lightTheme,
          darkTheme: WarmsTheme.darkTheme,
          themeMode: themeMode,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('fr', 'FR'), Locale('en', 'US')],
          locale: const Locale('fr', 'FR'),
          home: const AppGate(),
        );
      },
    );
  }
}

/// État d'amorçage de l'application, après la vidéo de démarrage.
///
/// La restauration de session ([_demarrer]) tourne en parallèle de la
/// vidéo de démarrage (voir [_AppGateState._videoTerminee]) : le temps
/// que la vidéo se termine, l'état ci-dessous a déjà eu le temps de se
/// résoudre dans l'immense majorité des cas.
enum _EtatBoot { nonConnecte, connecte }

/// Portail unique de navigation : affiche directement l'écran de connexion
/// au démarrage, tente de restaurer une session existante en arrière-plan,
/// puis bascule vers l'accueil patient ou le profil personnel si elle est
/// valide. Centralise aussi la déconnexion.
class AppGate extends StatefulWidget {
  const AppGate({super.key});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  final _auth = AuthService.instance;
  final _profilService = ProfilService.instance;
  final _patientService = PatientService.instance;

  _EtatBoot _etat = _EtatBoot.nonConnecte;
  Utilisateur _utilisateur = Utilisateur.vide();
  int? _patientId;
  bool _videoTerminee = false;

  @override
  void initState() {
    super.initState();
    _demarrer();
  }

  Future<void> _demarrer() async {
    final sessionValide = await _auth.restaurerSession();
    if (!sessionValide) return; // déjà sur l'écran de connexion par défaut.
    await _chargerProfilEtBasculer();
  }

  /// Charge le profil depuis l'API, applique le mode sombre mémorisé, puis
  /// bascule vers l'écran d'accueil adapté au rôle. Appelé au démarrage
  /// (session restaurée) et juste après une connexion réussie.
  Future<void> _chargerProfilEtBasculer() async {
    try {
      final utilisateur = await _profilService.chargerProfil();
      ThemeController.mode.value = utilisateur.modeSombre ? ThemeMode.dark : ThemeMode.light;

      int? patientId;
      if (utilisateur.estPatient) {
        // Donnée secondaire : si elle échoue ou traîne (ex. backend lent),
        // ça ne doit jamais empêcher la bascule vers l'écran d'accueil.
        // PatientService échoue déjà silencieusement, mais on logge ici
        // pour repérer facilement ce genre de blocage en debug.
        patientId = await _patientService.chargerIdPatientConnecte();
        if (kDebugMode) {
          debugPrint("Wam's: id patient résolu = $patientId");
        }
      }

      if (!mounted) return;
      setState(() {
        _utilisateur = utilisateur;
        _patientId = patientId;
        _etat = _EtatBoot.connecte;
      });
      if (kDebugMode) {
        debugPrint("Wam's: bascule vers l'écran ${utilisateur.estPatient ? "accueil patient" : "profil"}");
      }
    } catch (e) {
      // Le token a beau être valide, le profil n'a pas pu être chargé
      // (backend indisponible, etc.) : on revient à un état propre plutôt
      // que de bloquer l'utilisateur sur un écran de chargement infini.
      if (kDebugMode) {
        debugPrint("Wam's: échec du chargement du profil, retour à la connexion: $e");
      }
      await _auth.deconnexion();
      if (mounted) setState(() => _etat = _EtatBoot.nonConnecte);
    }
  }

  Future<void> _deconnexion() async {
    await _auth.deconnexion();
    if (!mounted) return;
    setState(() {
      _utilisateur = Utilisateur.vide();
      _patientId = null;
      _etat = _EtatBoot.nonConnecte;
    });
    // Revient à la route racine (celle qui héberge AppGate) pour que
    // l'écran de connexion, désormais affiché par cette route, redevienne
    // visible immédiatement même si la déconnexion a été déclenchée depuis
    // un écran empilé (Profil, etc.).
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
  }

  void _onModeSombreChange(bool valeur) {
    ThemeController.mode.value = valeur ? ThemeMode.dark : ThemeMode.light;
  }

  @override
  Widget build(BuildContext context) {
    if (!_videoTerminee) {
      return SplashScreen(onTermine: () => setState(() => _videoTerminee = true));
    }

    switch (_etat) {
      case _EtatBoot.nonConnecte:
        return LoginScreen(onConnexionReussie: _chargerProfilEtBasculer);

      case _EtatBoot.connecte:
        if (_utilisateur.estPatient) {
          return HomeScreen(
            utilisateur: _utilisateur,
            patientId: _patientId,
            onDeconnexion: _deconnexion,
            onModeSombreChange: _onModeSombreChange,
          );
        }
        return PersonnelHomeScreen(
          utilisateur: _utilisateur,
          onDeconnexion: _deconnexion,
          onModeSombreChange: _onModeSombreChange,
        );
    }
  }
}
