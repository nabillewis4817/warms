import 'package:flutter/material.dart';
import '../../services/patient_service.dart';
import '../../themes/warms_theme.dart';

class SuiviDouleurScreen extends StatefulWidget {
  final int? consultationId;
  const SuiviDouleurScreen({super.key, this.consultationId});

  @override
  State<SuiviDouleurScreen> createState() => _SuiviDouleurScreenState();
}

class _SuiviDouleurScreenState extends State<SuiviDouleurScreen> {
  final _service = PatientService.instance;
  int _intensite = 5;
  String _typeDouleur = 'autre';
  String _description = '';
  String _localisation = '';
  bool _traitementPris = false;
  bool _enCours = false;
  bool _success = false;

  static const _types = [
    ('autre', 'Autre'),
    ('lancinante', 'Lancinante'),
    ('sourde', 'Sourde'),
    ('pulsatile', 'Pulsatile'),
    ('brulure', 'Brûlure'),
  ];

  Color get _couleurIntensite {
    if (_intensite <= 3) return const Color(0xFF22C55E);
    if (_intensite <= 6) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  String get _labelIntensite {
    if (_intensite == 0) return 'Aucune douleur';
    if (_intensite <= 3) return 'Légère';
    if (_intensite <= 6) return 'Modérée';
    if (_intensite <= 8) return 'Sévère';
    return 'Très sévère';
  }

  Future<void> _soumettre() async {
    setState(() => _enCours = true);
    try {
      await _service.signalerDouleur(
        intensite: _intensite,
        typeDouleur: _typeDouleur,
        description: _description,
        localisation: _localisation,
        traitementPris: _traitementPris,
        consultationId: widget.consultationId,
      );
      if (mounted) setState(() { _success = true; _enCours = false; });
    } catch (_) {
      if (mounted) {
        setState(() => _enCours = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de l\'envoi. Réessayez.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WarmsTheme.warmsBg,
      appBar: AppBar(
        backgroundColor: WarmsTheme.warmsAccent,
        foregroundColor: Colors.white,
        title: const Text('Suivi post-soin', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
        elevation: 0,
      ),
      body: _success ? _succes() : _formulaire(),
    );
  }

  Widget _succes() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 48),
            ),
            const SizedBox(height: 20),
            const Text('Merci pour votre retour !',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: WarmsTheme.warmsNavy)),
            const SizedBox(height: 8),
            const Text(
              'Votre équipe soignante a été informée. N\'hésitez pas à nous contacter en cas d\'urgence.',
              textAlign: TextAlign.center,
              style: TextStyle(color: WarmsTheme.warmsGray, fontSize: 14),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: WarmsTheme.warmsAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
              child: const Text('Retour', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formulaire() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Niveau de douleur
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Niveau de douleur', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: WarmsTheme.warmsNavy)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$_intensite',
                      style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: _couleurIntensite)),
                    const Text('/10', style: TextStyle(fontSize: 20, color: WarmsTheme.warmsGray)),
                  ],
                ),
                Text(_labelIntensite,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _couleurIntensite, fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 12),
                Slider(
                  value: _intensite.toDouble(),
                  min: 0, max: 10, divisions: 10,
                  activeColor: _couleurIntensite,
                  onChanged: (v) => setState(() => _intensite = v.round()),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('0', style: TextStyle(fontSize: 12, color: WarmsTheme.warmsGray)),
                    Text('Aucune', style: TextStyle(fontSize: 12, color: WarmsTheme.warmsGray)),
                    Text('10', style: TextStyle(fontSize: 12, color: WarmsTheme.warmsGray)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Type de douleur
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Type de douleur', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: WarmsTheme.warmsNavy)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: _types.map((t) => ChoiceChip(
                    label: Text(t.$2),
                    selected: _typeDouleur == t.$1,
                    onSelected: (_) => setState(() => _typeDouleur = t.$1),
                    selectedColor: WarmsTheme.warmsAccent.withValues(alpha: 0.15),
                    labelStyle: TextStyle(
                      color: _typeDouleur == t.$1 ? WarmsTheme.warmsAccent : WarmsTheme.warmsGray,
                      fontWeight: _typeDouleur == t.$1 ? FontWeight.w700 : FontWeight.normal,
                    ),
                  )).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Localisation + description
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Localisation (optionnel)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: WarmsTheme.warmsNavy)),
                const SizedBox(height: 10),
                TextField(
                  onChanged: (v) => _localisation = v,
                  decoration: InputDecoration(
                    hintText: 'Ex: dent 36, côté gauche...',
                    hintStyle: const TextStyle(color: WarmsTheme.warmsGray),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Description (optionnel)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: WarmsTheme.warmsNavy)),
                const SizedBox(height: 10),
                TextField(
                  onChanged: (v) => _description = v,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Décrivez votre douleur...',
                    hintStyle: const TextStyle(color: WarmsTheme.warmsGray),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Checkbox(
                      value: _traitementPris,
                      onChanged: (v) => setState(() => _traitementPris = v ?? false),
                      activeColor: WarmsTheme.warmsAccent,
                    ),
                    const Expanded(child: Text('J\'ai pris un médicament contre la douleur', style: TextStyle(fontSize: 14, color: WarmsTheme.warmsNavy))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _enCours ? null : _soumettre,
              icon: _enCours
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded),
              label: const Text('Envoyer mon retour', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: WarmsTheme.warmsAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
