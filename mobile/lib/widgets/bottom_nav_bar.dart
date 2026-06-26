import 'package:flutter/material.dart';

import '../themes/warms_theme.dart';

/// Une destination de la barre de navigation inférieure.
class BottomNavDestination {
  final IconData icone;
  final String label;

  const BottomNavDestination({required this.icone, required this.label});
}

/// Barre de navigation inférieure flottante, avec un bouton central
/// circulaire surélevé — reproduit le motif de la maquette (Home / Message
/// / + / Calendar / Profile).
///
/// La destination centrale (index [destinations.length ~/ 2]) est toujours
/// rendue comme le bouton rond surélevé.
class BottomNavBar extends StatelessWidget {
  final List<BottomNavDestination> destinations;
  final int indexActif;
  final ValueChanged<int> onTap;

  const BottomNavBar({
    super.key,
    required this.destinations,
    required this.indexActif,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final indexCentral = destinations.length ~/ 2;

    return SizedBox(
      height: 78,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // Barre arrondie en fond.
          Container(
            margin: const EdgeInsets.only(top: 18),
            decoration: BoxDecoration(
              color: WarmsTheme.warmsCard,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: WarmsTheme.warmsBlue.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(destinations.length, (index) {
                if (index == indexCentral) {
                  // Espace réservé : le bouton central flotte par-dessus.
                  return const SizedBox(width: 56);
                }
                return _BoutonNav(
                  destination: destinations[index],
                  actif: index == indexActif,
                  onTap: () => onTap(index),
                );
              }),
            ),
          ),
          // Bouton central surélevé.
          Positioned(
            top: 0,
            child: GestureDetector(
              onTap: () => onTap(indexCentral),
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [WarmsTheme.warmsAccent, WarmsTheme.warmsBlue],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: WarmsTheme.warmsAccent.withValues(alpha: 0.45),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                  border: Border.all(color: WarmsTheme.warmsCard, width: 4),
                ),
                child: Icon(destinations[indexCentral].icone, color: Colors.white, size: 26),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BoutonNav extends StatelessWidget {
  final BottomNavDestination destination;
  final bool actif;
  final VoidCallback onTap;

  const _BoutonNav({required this.destination, required this.actif, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final couleur = actif ? WarmsTheme.warmsAccent : WarmsTheme.warmsGray;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(destination.icone, color: couleur, size: 24),
      ),
    );
  }
}
