import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../../models/carnet_scan_result.dart';
import '../../services/carnet_service.dart';
import '../../themes/warms_theme.dart';

/// Écran de confirmation des données extraites d'un carnet physique.
///
/// Deux sections :
/// 1. **Données extraites** — champs détectés par OCR, tous éditables.
/// 2. **Champs manquants** — champs non trouvés dans le texte OCR ; l'agent
///    peut les remplir avant de valider.
///
/// Au tap "Valider et enregistrer", les données sont envoyées à
/// POST /patients/importer-carnet/ et les identifiants temporaires générés
/// sont affichés dans une modale de succès.
class CarnetConfirmationScreen extends StatefulWidget {
  final CarnetScanResult scanResult;

  const CarnetConfirmationScreen({super.key, required this.scanResult});

  @override
  State<CarnetConfirmationScreen> createState() => _CarnetConfirmationScreenState();
}

class _CarnetConfirmationScreenState extends State<CarnetConfirmationScreen> {
  final Map<String, TextEditingController> _ctrl = {};
  bool _enregistrement = false;
  bool _manquantsOuverts = true;

  @override
  void initState() {
    super.initState();
    for (final champ in ChampsCarnet.tous) {
      _ctrl[champ] = TextEditingController(
        text: widget.scanResult.champsExtraits[champ] ?? '',
      );
    }
  }

  @override
  void dispose() {
    for (final c in _ctrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _enregistrer() async {
    final prenom = _ctrl[ChampsCarnet.prenom]!.text.trim();
    final nom    = _ctrl[ChampsCarnet.nom]!.text.trim();

    if (prenom.isEmpty || nom.isEmpty) {
      _snack('Le prénom et le nom sont obligatoires.', error: true);
      return;
    }

    setState(() => _enregistrement = true);
    try {
      final donnees = <String, String>{};
      for (final champ in ChampsCarnet.tous) {
        final val = _ctrl[champ]!.text.trim();
        if (val.isNotEmpty) {
          // Normalisation : date jj/mm/aaaa → aaaa-mm-jj pour Django
          if (champ == ChampsCarnet.dateNaissance) {
            donnees[champ] = _normaliserDate(val);
          } else if (champ == ChampsCarnet.sexe) {
            donnees[champ] = _normaliserSexe(val);
          } else {
            donnees[champ] = val;
          }
        }
      }

      final result = await CarnetService.instance.importerPatient(donnees);
      if (!mounted) return;

      final identifiants = result['identifiants_patient'] as Map<String, dynamic>?;
      await _afficherSucces(identifiants);

      if (!mounted) return;
      // Retour à la racine après succès
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on DioException catch (e) {
      if (!mounted) return;
      final detail = (e.response?.data as Map?)?.entries
          .map((entry) =>
              entry.value is List
                  ? (entry.value as List).join(' ')
                  : '${entry.value}')
          .join('\n');
      _snack(detail ?? e.message ?? 'Erreur réseau.', error: true);
    } catch (e) {
      if (!mounted) return;
      _snack('Erreur : $e', error: true);
    } finally {
      if (mounted) setState(() => _enregistrement = false);
    }
  }

  Future<void> _afficherSucces(Map<String, dynamic>? ids) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: WarmsTheme.warmsSuccess, size: 28),
            SizedBox(width: 8),
            Text('Patient enregistré', style: TextStyle(fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Le dossier digital a été créé avec succès.'),
            if (ids != null) ...[
              const SizedBox(height: 14),
              const Text(
                'Identifiants temporaires',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              _CredentialsBox(username: ids['username'] as String, password: ids['password'] as String),
              const SizedBox(height: 8),
              const Text(
                'Un e-mail a été envoyé si une adresse était fournie. '
                'Le patient devra changer son mot de passe à la première connexion.',
                style: TextStyle(fontSize: 11, color: WarmsTheme.warmsGray),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: WarmsTheme.warmsAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? WarmsTheme.warmsError : WarmsTheme.warmsSuccess,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final nbExtraits = widget.scanResult.champsExtraits.length;
    final nbManquants = widget.scanResult.champsManquants.length;

    return Scaffold(
      backgroundColor: WarmsTheme.warmsBg,
      appBar: AppBar(
        backgroundColor: WarmsTheme.warmsAccent,
        foregroundColor: Colors.white,
        title: const Text('Confirmer les données'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- Bandeau résumé ----
            _BandeauOcr(nbExtraits: nbExtraits, nbManquants: nbManquants),
            const SizedBox(height: 16),

            // ---- Données extraites ----
            if (nbExtraits > 0) ...[
              _sectionTitre(
                'Données extraites',
                Icons.check_circle_outline_rounded,
                WarmsTheme.warmsSuccess,
              ),
              const SizedBox(height: 8),
              for (final champ in ChampsCarnet.tous)
                if (widget.scanResult.champsExtraits.containsKey(champ))
                  _buildChampField(champ, extrait: true),
              const SizedBox(height: 16),
            ],

            // ---- Champs manquants ----
            if (nbManquants > 0) ...[
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _manquantsOuverts = !_manquantsOuverts),
                child: Row(
                  children: [
                    _sectionTitre(
                      'Champs non extraits ($nbManquants)',
                      Icons.add_circle_outline_rounded,
                      WarmsTheme.warmsWarning,
                    ),
                    const Spacer(),
                    Icon(
                      _manquantsOuverts ? Icons.expand_less : Icons.expand_more,
                      color: WarmsTheme.warmsGray,
                    ),
                  ],
                ),
              ),
              if (_manquantsOuverts) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBF0),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: WarmsTheme.warmsWarning.withValues(alpha: 0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Renseignez les informations manquantes si vous les connaissez.',
                        style: TextStyle(fontSize: 12, color: WarmsTheme.warmsGray),
                      ),
                      const SizedBox(height: 10),
                      for (final champ in widget.scanResult.champsManquants)
                        _buildChampField(champ, extrait: false),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],

            // ---- Bouton valider ----
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _enregistrement ? null : _enregistrer,
                icon: _enregistrement
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.check_rounded, size: 22),
                label: Text(
                  _enregistrement ? 'Enregistrement…' : 'Valider et enregistrer',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: WarmsTheme.warmsAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                ),
              ),
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitre(String titre, IconData icon, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 6),
        Text(
          titre,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: WarmsTheme.warmsNavy,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildChampField(String champ, {required bool extrait}) {
    final accentColor = extrait ? WarmsTheme.warmsAccent : WarmsTheme.warmsWarning;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: _ctrl[champ],
        keyboardType: _typeClavier(champ),
        textCapitalization: champ == ChampsCarnet.nom || champ == ChampsCarnet.prenom
            ? TextCapitalization.words
            : TextCapitalization.none,
        style: const TextStyle(color: WarmsTheme.warmsNavy, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: ChampsCarnet.label(champ),
          prefixIcon: Icon(_icone(champ), color: accentColor, size: 20),
          filled: true,
          fillColor: extrait ? Colors.white : const Color(0xFFFFFBF0),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: accentColor.withValues(alpha: 0.35)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: accentColor, width: 1.5),
          ),
          labelStyle: TextStyle(color: accentColor.withValues(alpha: 0.8), fontSize: 13),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  TextInputType _typeClavier(String champ) {
    switch (champ) {
      case ChampsCarnet.telephone:     return TextInputType.phone;
      case ChampsCarnet.email:         return TextInputType.emailAddress;
      case ChampsCarnet.dateNaissance: return TextInputType.datetime;
      default:                         return TextInputType.text;
    }
  }

  IconData _icone(String champ) {
    switch (champ) {
      case ChampsCarnet.prenom:        return Icons.person_rounded;
      case ChampsCarnet.nom:           return Icons.badge_rounded;
      case ChampsCarnet.dateNaissance: return Icons.cake_rounded;
      case ChampsCarnet.sexe:          return Icons.wc_rounded;
      case ChampsCarnet.telephone:     return Icons.phone_rounded;
      case ChampsCarnet.email:         return Icons.email_rounded;
      case ChampsCarnet.adresse:       return Icons.location_on_rounded;
      case ChampsCarnet.groupeSanguin: return Icons.bloodtype_rounded;
      case ChampsCarnet.allergies:     return Icons.medical_services_rounded;
      default:                         return Icons.info_rounded;
    }
  }

  /// Normalise une date saisie librement vers YYYY-MM-DD (attendu par Django).
  /// Accepte jj/mm/aaaa, jj-mm-aaaa, aaaa-mm-jj.  Retourne la valeur brute
  /// si le format n'est pas reconnu (le backend renverra une erreur claire).
  String _normaliserDate(String val) {
    // Déjà au format ISO
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(val)) return val;
    // DD/MM/YYYY ou DD-MM-YYYY
    final m = RegExp(r'^(\d{2})[\/\-\.](\d{2})[\/\-\.](\d{4})$').firstMatch(val);
    if (m != null) return '${m.group(3)}-${m.group(2)}-${m.group(1)}';
    return val;
  }

  /// Normalise le champ sexe vers 'M' ou 'F'.
  String _normaliserSexe(String val) {
    final v = val.trim().toUpperCase();
    if (v.startsWith('F')) return 'F';
    return 'M';
  }
}

// ---------------------------------------------------------------------------
// Sous-widgets
// ---------------------------------------------------------------------------

class _BandeauOcr extends StatelessWidget {
  final int nbExtraits;
  final int nbManquants;

  const _BandeauOcr({required this.nbExtraits, required this.nbManquants});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: WarmsTheme.warmsAccentTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WarmsTheme.warmsAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.document_scanner_rounded, color: WarmsTheme.warmsAccent),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: WarmsTheme.warmsBlue, fontSize: 13),
                children: [
                  TextSpan(
                    text: '$nbExtraits champ(s) extrait(s)',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text: nbManquants > 0
                        ? ' — $nbManquants non détecté(s). Vérifiez et complétez si nécessaire.'
                        : '. Vérifiez les informations avant de valider.',
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

class _CredentialsBox extends StatelessWidget {
  final String username;
  final String password;

  const _CredentialsBox({required this.username, required this.password});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: WarmsTheme.warmsBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: WarmsTheme.warmsAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _credLine('Login', username, Icons.person_outline),
          const SizedBox(height: 4),
          _credLine('Mot de passe', password, Icons.key_rounded),
        ],
      ),
    );
  }

  Widget _credLine(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: WarmsTheme.warmsAccent),
        const SizedBox(width: 6),
        Text('$label : ', style: const TextStyle(fontSize: 12, color: WarmsTheme.warmsGray)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: WarmsTheme.warmsNavy,
            ),
          ),
        ),
      ],
    );
  }
}
