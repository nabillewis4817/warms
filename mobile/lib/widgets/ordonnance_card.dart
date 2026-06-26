import 'package:flutter/material.dart';

import '../models/ordonnance.dart';
import '../themes/warms_theme.dart';

/// Carte présentant une ligne d'ordonnance (médicament + posologie), avec
/// la même structure visuelle que la carte "Upcoming Appointment" de la
/// maquette : icône à gauche, contenu central, accent coloré.
class OrdonnanceCard extends StatelessWidget {
  final Ordonnance ordonnance;

  const OrdonnanceCard({super.key, required this.ordonnance});

  @override
  Widget build(BuildContext context) {
    return Container(
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
                Text(
                  ordonnance.medicament.isEmpty ? 'Médicament' : ordonnance.medicament,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: WarmsTheme.warmsNavy),
                ),
                const SizedBox(height: 2),
                Text(
                  ordonnance.posologie.isEmpty ? 'Posologie non précisée' : ordonnance.posologie,
                  style: const TextStyle(fontSize: 12.5, color: WarmsTheme.warmsGray),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
