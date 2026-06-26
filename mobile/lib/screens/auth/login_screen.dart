import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/profil_service.dart';
import '../../themes/warms_theme.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/illustrations/tooth_illustration.dart';
import '../../widgets/primary_button.dart';
import 'confirmation_identite_screen.dart';

/// Écran de connexion.
///
/// Reprend le langage visuel de l'onboarding (en-tête en dégradé turquoise
/// avec l'illustration de dent, réduite) au-dessus d'une carte blanche
/// contenant le formulaire identifiant/mot de passe.
///
/// [onConnexionReussie] est appelé après une authentification réussie ;
/// c'est à l'appelant (AppGate) de charger le profil et de basculer vers
/// l'écran adapté au rôle de l'utilisateur.
class LoginScreen extends StatefulWidget {
  final VoidCallback? onConnexionReussie;

  const LoginScreen({super.key, this.onConnexionReussie});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _auth = AuthService.instance;

  bool _motDePasseVisible = false;
  bool _enCours = false;
  String _erreur = '';

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _seConnecter() async {
    setState(() {
      _enCours = true;
      _erreur = '';
    });
    try {
      await _auth.connexion(_usernameCtrl.text.trim(), _passwordCtrl.text);
      final utilisateur = await ProfilService.instance.chargerProfil();
      if (!mounted) return;

      // Pas de photo enregistrée (compte créé avant cette fonctionnalité,
      // ou backend indisponible) : impossible de demander une confirmation
      // visuelle, on n'empêche pas la connexion pour autant.
      if (utilisateur.photoProfil.isEmpty) {
        widget.onConnexionReussie?.call();
        return;
      }

      final confirme = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => ConfirmationIdentiteScreen(utilisateur: utilisateur)),
      );

      if (confirme == true) {
        widget.onConnexionReussie?.call();
      } else {
        await _auth.deconnexion();
        if (mounted) setState(() => _erreur = 'Vérifiez vos identifiants.');
      }
    } on AuthException catch (e) {
      setState(() => _erreur = e.message);
    } catch (_) {
      setState(() => _erreur = 'Connexion impossible. Réessayez.');
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WarmsTheme.warmsBg,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // En-tête en dégradé turquoise, reprenant l'illustration d'onboarding.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 64, bottom: 28),
              decoration: const BoxDecoration(
                gradient: WarmsTheme.warmsHeroGradient,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
              ),
              child: Column(
                children: [
                  const ToothIllustration(taille: 130),
                  const SizedBox(height: 12),
                  const Text(
                    'WARMS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Espace cabinet dentaire',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Connexion',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: WarmsTheme.warmsNavy),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Connectez-vous pour accéder à votre espace WARMS.',
                    style: TextStyle(color: WarmsTheme.warmsGray, fontSize: 14),
                  ),
                  const SizedBox(height: 28),

                  AppTextField(
                    controller: _usernameCtrl,
                    label: "Nom d'utilisateur",
                    icone: Icons.person_outline,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _passwordCtrl,
                    label: 'Mot de passe',
                    icone: Icons.lock_outline,
                    motDePasse: true,
                    motDePasseVisible: _motDePasseVisible,
                    onToggleVisibilite: () => setState(() => _motDePasseVisible = !_motDePasseVisible),
                  ),

                  if (_erreur.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: WarmsTheme.warmsError.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: WarmsTheme.warmsError, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_erreur, style: const TextStyle(color: WarmsTheme.warmsError, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 28),
                  PrimaryButton(
                    label: _enCours ? 'Connexion...' : 'Se connecter',
                    icone: Icons.login_rounded,
                    enChargement: _enCours,
                    onPressed: _seConnecter,
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
