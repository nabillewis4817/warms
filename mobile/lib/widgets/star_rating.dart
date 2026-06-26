import 'package:flutter/material.dart';

import '../themes/warms_theme.dart';

/// Rangée de 5 étoiles, vides ou remplies selon [note], modifiable par
/// l'utilisateur (tap sur une étoile) quand [onChanged] est fourni.
class StarRating extends StatelessWidget {
  final int note;
  final ValueChanged<int>? onChanged;
  final double taille;

  const StarRating({
    super.key,
    required this.note,
    this.onChanged,
    this.taille = 36,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final valeur = index + 1;
        final remplie = valeur <= note;
        return GestureDetector(
          onTap: onChanged == null ? null : () => onChanged!(valeur),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              remplie ? Icons.star_rounded : Icons.star_border_rounded,
              color: remplie ? WarmsTheme.warmsStar : WarmsTheme.warmsGray.withValues(alpha: 0.5),
              size: taille,
            ),
          ),
        );
      }),
    );
  }
}
