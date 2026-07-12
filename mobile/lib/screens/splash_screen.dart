import 'package:flutter/material.dart';

import '../themes/warms_theme.dart';

/// Écran de démarrage Wam's — icône + dégradé, durée 2 secondes.
class SplashScreen extends StatefulWidget {
  final VoidCallback onTermine;
  const SplashScreen({super.key, required this.onTermine});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacite;
  late final Animation<double> _echelle;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _opacite = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _echelle = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );

    _ctrl.forward().whenComplete(() {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) widget.onTermine();
      });
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              WarmsTheme.warmsNavy,
              WarmsTheme.warmsBlue,
              WarmsTheme.warmsAccent,
            ],
          ),
        ),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, child) => Opacity(
            opacity: _opacite.value,
            child: Transform.scale(scale: _echelle.value, child: child),
          ),
          child: Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(34),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.4),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.health_and_safety_rounded,
                size: 68,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
