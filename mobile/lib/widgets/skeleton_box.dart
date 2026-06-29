import 'package:flutter/material.dart';

import '../themes/warms_theme.dart';

/// Placeholder rectangulaire animé (pulsation d'opacité) utilisé pendant le
/// chargement d'une liste ou d'une carte, à la place d'un simple spinner
/// central : donne une idée immédiate de la mise en page finale et réduit
/// la sensation d'attente ("skeleton loading").
class SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const SkeletonBox({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius,
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _controleur;

  @override
  void initState() {
    super.initState();
    _controleur = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controleur,
      builder: (context, _) {
        final opacite = 0.35 + (_controleur.value * 0.3);
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: WarmsTheme.warmsGray.withValues(alpha: opacite * 0.4),
            borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
          ),
        );
      },
    );
  }
}

/// Squelette d'une carte de type "OrdonnanceCard" / "RendezVousCard" :
/// icône circulaire + deux lignes de texte de largeurs différentes.
class SkeletonCarte extends StatelessWidget {
  const SkeletonCarte({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: WarmsTheme.warmsCard,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const SkeletonBox(width: 46, height: 46, borderRadius: BorderRadius.all(Radius.circular(23))),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonBox(width: 140, height: 13),
                SizedBox(height: 8),
                SkeletonBox(width: 90, height: 11),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Empile [count] [SkeletonCarte] — pratique pour remplacer un
/// `CircularProgressIndicator` central pendant le chargement d'une liste.
class SkeletonListe extends StatelessWidget {
  final int count;

  const SkeletonListe({super.key, this.count = 3});

  @override
  Widget build(BuildContext context) {
    return Column(children: List.generate(count, (_) => const SkeletonCarte()));
  }
}

/// Squelette d'une bulle de conversation (alignée à gauche ou à droite),
/// pour remplacer un `CircularProgressIndicator` pendant le chargement
/// d'une liste de messages.
class SkeletonBulle extends StatelessWidget {
  final bool aDroite;
  final double largeur;

  const SkeletonBulle({super.key, this.aDroite = false, this.largeur = 180});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: aDroite ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: SkeletonBox(width: largeur, height: 42, borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}

/// Empile quelques [SkeletonBulle] en alternant les côtés, pour simuler
/// une conversation pendant son chargement.
class SkeletonBulles extends StatelessWidget {
  final int count;

  const SkeletonBulles({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) {
    const largeurs = [170.0, 130.0, 200.0, 150.0, 190.0];
    return Column(
      children: List.generate(
        count,
        (i) => SkeletonBulle(aDroite: i.isOdd, largeur: largeurs[i % largeurs.length]),
      ),
    );
  }
}
