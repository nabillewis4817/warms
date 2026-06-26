import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Illustration animée d'une dent (style de la maquette d'onboarding) :
/// silhouette dessinée en [_ToothPainter], anneau lumineux rotatif autour,
/// et léger mouvement de flottement vertical.
///
/// Dessinée entièrement en code (CustomPainter) plutôt qu'avec une image
/// bitmap : pas d'asset à fournir, et le rendu reste net sur tous les
/// écrans/densités.
class ToothIllustration extends StatefulWidget {
  final double taille;

  const ToothIllustration({super.key, this.taille = 220});

  @override
  State<ToothIllustration> createState() => _ToothIllustrationState();
}

class _ToothIllustrationState extends State<ToothIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        // Flottement vertical doux (va-et-vient sur un cycle complet).
        final flottement = math.sin(t * 2 * math.pi) * 8;

        return SizedBox(
          width: widget.taille,
          height: widget.taille,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Halo lumineux pulsant en arrière-plan.
              Container(
                width: widget.taille,
                height: widget.taille,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.35),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
              // Anneau lumineux rotatif.
              Transform.rotate(
                angle: t * 2 * math.pi,
                child: CustomPaint(
                  size: Size(widget.taille * 0.92, widget.taille * 0.92),
                  painter: _AnneauLumineuxPainter(),
                ),
              ),
              // Silhouette de la dent, avec flottement.
              Transform.translate(
                offset: Offset(0, flottement),
                child: CustomPaint(
                  size: Size(widget.taille * 0.55, widget.taille * 0.62),
                  painter: _ToothPainter(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Dessine la silhouette d'une dent (couronne à deux bosses + deux racines)
/// avec un léger dégradé blanc pour suggérer le volume.
class _ToothPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();

    // Couronne (sommet arrondi avec deux bosses, comme une molaire).
    path.moveTo(w * 0.5, h * 0.02);
    path.cubicTo(w * 0.85, h * 0.0, w * 1.0, h * 0.18, w * 0.92, h * 0.34);
    path.cubicTo(w * 0.88, h * 0.42, w * 0.82, h * 0.40, w * 0.76, h * 0.46);
    // Racine droite.
    path.cubicTo(w * 0.80, h * 0.62, w * 0.74, h * 0.92, w * 0.62, h * 0.98);
    path.cubicTo(w * 0.56, h * 1.0, w * 0.52, h * 0.92, w * 0.52, h * 0.80);
    path.cubicTo(w * 0.52, h * 0.70, w * 0.50, h * 0.70, w * 0.48, h * 0.80);
    path.cubicTo(w * 0.48, h * 0.92, w * 0.44, h * 1.0, w * 0.38, h * 0.98);
    // Racine gauche.
    path.cubicTo(w * 0.26, h * 0.92, w * 0.20, h * 0.62, w * 0.24, h * 0.46);
    path.cubicTo(w * 0.18, h * 0.40, w * 0.12, h * 0.42, w * 0.08, h * 0.34);
    path.cubicTo(w * 0.0, h * 0.18, w * 0.15, h * 0.0, w * 0.5, h * 0.02);
    path.close();

    final degrade = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white, const Color(0xFFE3F8FA)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    final ombre = Paint()
      ..color = const Color(0xFF0B5C63).withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);

    canvas.drawPath(path.shift(const Offset(0, 8)), ombre);
    canvas.drawPath(path, degrade);

    // Petit reflet pour suggérer le volume/la brillance.
    final reflet = Paint()..color = Colors.white.withValues(alpha: 0.7);
    canvas.drawOval(
      Rect.fromLTWH(w * 0.28, h * 0.10, w * 0.18, h * 0.10),
      reflet,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Anneau lumineux dégradé (effet "scan") tournant autour de la dent.
class _AnneauLumineuxPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final rayon = size.width / 2;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.9),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: centre, radius: rayon));

    canvas.drawCircle(centre, rayon, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
