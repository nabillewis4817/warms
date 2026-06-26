import 'package:flutter/material.dart';

import '../themes/warms_theme.dart';

/// Icône ronde + libellé, utilisée dans la rangée "Nos services" de
/// l'écran d'accueil (mêmes proportions que la maquette : cercle dégradé,
/// libellé centré en dessous).
class ServiceChip extends StatelessWidget {
  final IconData icone;
  final String label;
  final VoidCallback? onTap;

  const ServiceChip({super.key, required this.icone, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    WarmsTheme.warmsAccent.withValues(alpha: 0.15),
                    WarmsTheme.warmsBlue.withValues(alpha: 0.08),
                  ],
                ),
              ),
              child: Icon(icone, color: WarmsTheme.warmsAccent, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: WarmsTheme.warmsNavy),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
