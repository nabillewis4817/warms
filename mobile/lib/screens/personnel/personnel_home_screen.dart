import 'package:flutter/material.dart';

import '../../models/utilisateur.dart';
import '../../themes/warms_theme.dart';
import '../profil/profil_screen.dart';
import 'carnet_scanner_screen.dart';

/// Écran d'accueil pour le personnel (infirmière, secrétaire, assistant…).
///
/// Remplace le bare [ProfilScreen] qui était affiché à tous les non-patients.
/// Propose un tableau de bord simple :
/// – Carte "Scanner un carnet" → [CarnetScannerScreen]
/// – Carte "Mon profil"        → [ProfilScreen]
/// – Déconnexion dans l'AppBar
class PersonnelHomeScreen extends StatelessWidget {
  final Utilisateur utilisateur;
  final VoidCallback onDeconnexion;
  final ValueChanged<bool>? onModeSombreChange;

  const PersonnelHomeScreen({
    super.key,
    required this.utilisateur,
    required this.onDeconnexion,
    this.onModeSombreChange,
  });

  String get _roleLabel {
    const labels = {
      'chirurgien_dentiste': 'Chirurgien-Dentiste',
      'secretaire':          'Secrétaire',
      'infirmiere':          'Infirmière',
      'assistant':           'Assistant(e)',
      'admin':               'Administrateur',
    };
    return labels[utilisateur.role] ?? utilisateur.role;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WarmsTheme.warmsBg,
      appBar: AppBar(
        backgroundColor: WarmsTheme.warmsAccent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Wam's",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Déconnexion',
            onPressed: onDeconnexion,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _WelcomeCard(utilisateur: utilisateur, roleLabel: _roleLabel),
            const SizedBox(height: 28),
            const Text(
              'Actions rapides',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: WarmsTheme.warmsNavy,
              ),
            ),
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.document_scanner_rounded,
              title: 'Scanner un carnet patient',
              subtitle: 'Numérisez un carnet physique par OCR et créez le dossier digital',
              color: WarmsTheme.warmsAccent,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CarnetScannerScreen()),
              ),
            ),
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.person_rounded,
              title: 'Mon profil',
              subtitle: 'Modifier mes informations, préférences et sécurité',
              color: WarmsTheme.warmsBlue,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfilScreen(
                    utilisateur: utilisateur,
                    onDeconnexion: onDeconnexion,
                    onModeSombreChange: onModeSombreChange,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sous-widgets privés
// ---------------------------------------------------------------------------

class _WelcomeCard extends StatelessWidget {
  final Utilisateur utilisateur;
  final String roleLabel;

  const _WelcomeCard({required this.utilisateur, required this.roleLabel});

  @override
  Widget build(BuildContext context) {
    final initiales =
        ((utilisateur.prenom.isNotEmpty ? utilisateur.prenom[0] : '') +
                (utilisateur.nom.isNotEmpty ? utilisateur.nom[0] : ''))
            .toUpperCase();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [WarmsTheme.warmsAccent, WarmsTheme.warmsBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: WarmsTheme.warmsAccent.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white.withValues(alpha: 0.25),
            backgroundImage: utilisateur.photoProfil.isNotEmpty
                ? NetworkImage(utilisateur.photoProfil)
                : null,
            child: utilisateur.photoProfil.isEmpty
                ? Text(
                    initiales,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bonjour, ${utilisateur.prenom} !',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  roleLabel,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: WarmsTheme.warmsNavy,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: WarmsTheme.warmsGray,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }
}
