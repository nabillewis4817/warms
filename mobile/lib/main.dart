import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'services/api_client.dart';

/// Point d'entrée de WARMS Mobile.
///
/// Toute la logique applicative vit désormais dans des fichiers dédiés :
/// - [WarmsApp] / [AppGate] (lib/app.dart) pilotent le thème et la navigation ;
/// - lib/services/ contient l'authentification et les appels API ;
/// - lib/screens/ contient les écrans, lib/widgets/ les composants partagés.
///
/// `main.dart` ne fait plus que démarrer le binding Flutter, configurer le
/// gestionnaire d'erreurs global, puis lancer [WarmsApp].
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase est configuré pour Android (google-services.json).
  // Sur web, pas de config Firebase donc on n'initialise pas.
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp();
    } catch (_) {}
  }
  // Charge l'URL serveur configurée au runtime avant le premier appel réseau.
  await ApiClient.instance.initialiser();

  ErrorWidget.builder = (details) => Material(
        color: const Color(0xFFF2FBFC),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              "Erreur Wam's:\n${details.exceptionAsString()}",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFB91C1C)),
            ),
          ),
        ),
      );

  runZonedGuarded(
    () => runApp(const WarmsApp()),
    (error, stack) {
      if (kDebugMode) {
        debugPrint('WARMS: $error\n$stack');
      }
    },
  );
}
