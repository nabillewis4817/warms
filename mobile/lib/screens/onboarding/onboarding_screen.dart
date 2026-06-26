import 'package:flutter/material.dart';

import '../../themes/warms_theme.dart';
import '../../widgets/illustrations/tooth_illustration.dart';
import '../../widgets/primary_button.dart';
import '../auth/login_screen.dart';

/// Écran d'accueil/onboarding affiché avant la connexion lorsque
/// l'utilisateur n'a pas de session active.
///
/// Reproduit fidèlement la maquette de référence : fond plein écran en
/// dégradé turquoise, illustration de dent animée, carte blanche
/// arrondie en bas avec accroche + bouton "Get Started" menant à
/// l'écran de connexion.
class OnboardingScreen extends StatelessWidget {
  /// Transmis jusqu'à [LoginScreen] : appelé après une connexion réussie
  /// pour que [AppGate] charge le profil et bascule vers l'écran adapté.
  final VoidCallback onConnexionReussie;

  const OnboardingScreen({super.key, required this.onConnexionReussie});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: WarmsTheme.warmsHeroGradient),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.medical_services, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'WARMS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              const ToothIllustration(taille: 220),
              const Spacer(),
              // Carte blanche d'accroche, ancrée en bas de l'écran.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(28, 32, 28, 36),
                decoration: const BoxDecoration(
                  color: WarmsTheme.warmsCard,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Connectez-vous à des praticiens de confiance',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: WarmsTheme.warmsNavy,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Suivez vos ordonnances, échangez avec le cabinet et gérez votre suivi dentaire, où que vous soyez.',
                      style: TextStyle(fontSize: 14.5, color: WarmsTheme.warmsGray, height: 1.5),
                    ),
                    const SizedBox(height: 28),
                    PrimaryButton(
                      label: 'Get Started',
                      icone: Icons.arrow_forward_rounded,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => LoginScreen(onConnexionReussie: onConnexionReussie),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
