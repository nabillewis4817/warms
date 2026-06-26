import 'package:flutter/material.dart';

import '../../models/utilisateur.dart';
import '../../themes/warms_theme.dart';
import '../../widgets/avatar_circle.dart';
import '../../widgets/primary_button.dart';

/// Étape de confirmation visuelle après une connexion réussie : affiche la
/// photo enregistrée de l'utilisateur et demande explicitement "Est-ce
/// bien vous ?" avant de finaliser l'accès — une vérification
/// supplémentaire au-delà du simple mot de passe.
///
/// Retourne `true` (confirmé) ou `false` (refusé) via [Navigator.pop].
class ConfirmationIdentiteScreen extends StatelessWidget {
  final Utilisateur utilisateur;

  const ConfirmationIdentiteScreen({super.key, required this.utilisateur});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WarmsTheme.warmsBg,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: WarmsTheme.warmsHeroGradient,
                        boxShadow: [
                          BoxShadow(
                            color: WarmsTheme.warmsAccent.withValues(alpha: 0.35),
                            blurRadius: 28,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: AvatarCircle(
                        initiales: utilisateur.initiales,
                        photoUrl: utilisateur.photoProfil,
                        taille: 168,
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Est-ce bien vous ?',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: WarmsTheme.warmsNavy),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      utilisateur.nomComplet.isEmpty ? 'Vérifiez votre identité' : utilisateur.nomComplet,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: WarmsTheme.warmsBlue),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pour votre sécurité, confirmez que cette photo correspond '
                      'bien à votre visage avant d\'accéder à votre espace WARMS.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13.5, color: WarmsTheme.warmsGray, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
              child: Column(
                children: [
                  PrimaryButton(
                    label: 'Oui, c\'est moi',
                    icone: Icons.check_circle_rounded,
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.cancel_outlined, color: WarmsTheme.warmsError),
                    label: const Text(
                      "Non, ce n'est pas moi",
                      style: TextStyle(color: WarmsTheme.warmsError, fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: WarmsTheme.warmsError),
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
