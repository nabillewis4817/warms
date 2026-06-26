import 'package:flutter/material.dart';

import '../../models/avis.dart';
import '../../services/avis_service.dart';
import '../../themes/warms_theme.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/star_rating.dart';

/// Ouvre le modal de dépôt d'avis (étoiles + commentaire) en bas d'écran.
Future<void> ouvrirModalAvis(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const AvisModal(),
  );
}

/// Contenu du modal : 5 étoiles remplissables, type d'avis, titre,
/// commentaire et remarques, envoyés à `POST /avis/avis/`.
class AvisModal extends StatefulWidget {
  const AvisModal({super.key});

  @override
  State<AvisModal> createState() => _AvisModalState();
}

class _AvisModalState extends State<AvisModal> {
  final _titreCtrl = TextEditingController();
  final _commentaireCtrl = TextEditingController();
  final _remarquesCtrl = TextEditingController();

  int _note = 0;
  String _type = TypeAvis.general;
  bool _envoiEnCours = false;
  String _erreur = '';

  @override
  void dispose() {
    _titreCtrl.dispose();
    _commentaireCtrl.dispose();
    _remarquesCtrl.dispose();
    super.dispose();
  }

  Future<void> _envoyer() async {
    if (_note == 0) {
      setState(() => _erreur = 'Merci de choisir une note (1 à 5 étoiles).');
      return;
    }
    if (_titreCtrl.text.trim().isEmpty || _commentaireCtrl.text.trim().isEmpty) {
      setState(() => _erreur = 'Le titre et le commentaire sont obligatoires.');
      return;
    }

    setState(() {
      _envoiEnCours = true;
      _erreur = '';
    });

    try {
      await AvisService.instance.envoyerAvis(
        typeAvis: _type,
        note: _note,
        titre: _titreCtrl.text.trim(),
        commentaire: _commentaireCtrl.text.trim(),
        pointsNegatifs: _remarquesCtrl.text.trim().isEmpty ? const [] : [_remarquesCtrl.text.trim()],
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Merci pour votre avis !')),
      );
    } catch (_) {
      setState(() => _erreur = "Échec de l'envoi de l'avis. Réessayez.");
    } finally {
      if (mounted) setState(() => _envoiEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: WarmsTheme.warmsCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: WarmsTheme.warmsGray.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Votre avis compte',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: WarmsTheme.warmsNavy),
              ),
              const SizedBox(height: 4),
              Text(
                'Notez votre expérience avec le cabinet',
                textAlign: TextAlign.center,
                style: TextStyle(color: WarmsTheme.warmsGray, fontSize: 13),
              ),
              const SizedBox(height: 20),

              StarRating(note: _note, onChanged: (v) => setState(() => _note = v)),
              const SizedBox(height: 20),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: TypeAvis.libelles.entries.map((entry) {
                  final selectionne = entry.key == _type;
                  return ChoiceChip(
                    label: Text(entry.value),
                    selected: selectionne,
                    onSelected: (_) => setState(() => _type = entry.key),
                    selectedColor: WarmsTheme.warmsAccent,
                    labelStyle: TextStyle(
                      color: selectionne ? Colors.white : WarmsTheme.warmsNavy,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                    backgroundColor: WarmsTheme.warmsBg,
                    side: BorderSide.none,
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              TextField(
                controller: _titreCtrl,
                style: const TextStyle(color: WarmsTheme.warmsNavy, fontWeight: FontWeight.w500),
                decoration: _decorationChamp('Titre de votre avis'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _commentaireCtrl,
                maxLines: 3,
                style: const TextStyle(color: WarmsTheme.warmsNavy),
                decoration: _decorationChamp('Votre commentaire'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _remarquesCtrl,
                maxLines: 2,
                style: const TextStyle(color: WarmsTheme.warmsNavy),
                decoration: _decorationChamp('Points à améliorer (optionnel)'),
              ),

              if (_erreur.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(_erreur, style: const TextStyle(color: WarmsTheme.warmsError, fontSize: 13)),
              ],

              const SizedBox(height: 22),
              PrimaryButton(
                label: _envoiEnCours ? 'Envoi...' : 'Envoyer mon avis',
                icone: Icons.send_rounded,
                enChargement: _envoiEnCours,
                onPressed: _envoyer,
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _decorationChamp(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: WarmsTheme.warmsBg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: WarmsTheme.warmsAccent, width: 2),
      ),
    );
  }
}
