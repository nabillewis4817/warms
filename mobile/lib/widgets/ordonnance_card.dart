import 'package:flutter/material.dart';

import '../models/ordonnance.dart';
import '../screens/prescription_detail_screen.dart';
import '../themes/warms_theme.dart';

/// Carte résumant une ordonnance : titre, statut, premier médicament et
/// date. Tap → écran de détail complet (lignes, conseils, recommandations,
/// téléchargement PDF).
class OrdonnanceCard extends StatelessWidget {
  final Prescription ordonnance;

  const OrdonnanceCard({super.key, required this.ordonnance});

  Color get _couleurStatut {
    switch (ordonnance.statut) {
      case 'terminee':
        return WarmsTheme.warmsBlue;
      case 'annulee':
        return WarmsTheme.warmsError;
      default:
        return WarmsTheme.warmsSuccess;
    }
  }

  @override
  Widget build(BuildContext context) {
    final premierMedicament = ordonnance.lignes.isNotEmpty ? ordonnance.lignes.first.medicament : '';
    final autresCount = ordonnance.lignes.length - 1;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PrescriptionDetailScreen(prescription: ordonnance)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: WarmsTheme.warmsCard,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: WarmsTheme.warmsBlue.withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: WarmsTheme.warmsAccent.withValues(alpha: 0.12),
              ),
              child: const Icon(Icons.medication_rounded, color: WarmsTheme.warmsAccent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          ordonnance.titre.isEmpty ? 'Ordonnance' : ordonnance.titre,
                          style: const TextStyle(fontWeight: FontWeight.w700, color: WarmsTheme.warmsNavy),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _couleurStatut.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          ordonnance.libelleStatut,
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _couleurStatut),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    premierMedicament.isEmpty
                        ? 'Aucun médicament listé'
                        : autresCount > 0
                            ? '$premierMedicament + $autresCount autre(s)'
                            : premierMedicament,
                    style: const TextStyle(fontSize: 12.5, color: WarmsTheme.warmsGray),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: WarmsTheme.warmsGray),
          ],
        ),
      ),
    );
  }
}
