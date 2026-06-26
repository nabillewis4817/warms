import 'package:flutter/material.dart';

import '../themes/warms_theme.dart';

/// Bouton "pilule" en dégradé turquoise, utilisé pour les actions
/// principales (Se connecter, Get Started, Booking, Join Now...).
///
/// Reproduit le style des boutons de la maquette : forme totalement
/// arrondie, dégradé, ombre colorée, état de chargement intégré.
class PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icone;
  final VoidCallback? onPressed;
  final bool enChargement;
  final bool pleineLargeur;
  final Color? couleurDebut;
  final Color? couleurFin;

  const PrimaryButton({
    super.key,
    required this.label,
    this.icone,
    this.onPressed,
    this.enChargement = false,
    this.pleineLargeur = true,
    this.couleurDebut,
    this.couleurFin,
  });

  @override
  Widget build(BuildContext context) {
    final desactive = onPressed == null || enChargement;

    return SizedBox(
      width: pleineLargeur ? double.infinity : null,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              couleurDebut ?? WarmsTheme.warmsAccent,
              couleurFin ?? WarmsTheme.warmsBlue,
            ],
          ),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: (couleurFin ?? WarmsTheme.warmsBlue).withValues(alpha: desactive ? 0.0 : 0.35),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: desactive ? null : onPressed,
            child: Opacity(
              opacity: desactive && !enChargement ? 0.6 : 1,
              child: Center(
                child: enChargement
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (icone != null) ...[
                            Icon(icone, color: Colors.white, size: 20),
                            const SizedBox(width: 10),
                          ],
                          Text(
                            label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
