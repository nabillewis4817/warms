import 'package:flutter/material.dart';

import '../themes/warms_theme.dart';

/// Écran de démarrage (boot) de WARMS Mobile.
///
/// Affiche une animation élégante avec le logo WARMS et le texte "WARMS"
/// qui apparaît lettre par lettre, avec un fond en dégradé turquoise animé.
/// Affiché tant que [AppGate] restaure la session (voir app.dart) — la
/// navigation vers l'écran suivant est pilotée par l'appelant, pas par ce
/// widget (pas de minuteur interne ni de `pushReplacementNamed`).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _waveController;
  late Animation<double> _logoScale;
  late Animation<double> _textOpacity;
  late Animation<double> _waveOffset;
  late Animation<double> _letterSpacing;
  late Animation<double> _waveOpacity;

  @override
  void initState() {
    super.initState();
    
    // Animation du logo
    _logoController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    
    // Animation du texte
    _textController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    // Animation des ondes
    _waveController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    // Configurer les animations
    _logoScale = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    ));
    
    _textOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeInOut,
    ));
    
    _waveOffset = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _waveController,
      curve: Curves.easeInOut,
    ));
    
    _letterSpacing = Tween<double>(
      begin: -5.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeInOutBack,
    ));
    
    _waveOpacity = Tween<double>(
      begin: 0.3,
      end: 0.1,
    ).animate(CurvedAnimation(
      parent: _waveController,
      curve: Curves.easeInOut,
    ));
    
    // Démarrer les animations
    _logoController.forward();
    _textController.forward();
    _waveController.repeat();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WarmsTheme.warmsBg,
      body: Stack(
        children: [
          // Ondes animées en arrière-plan
          AnimatedBuilder(
            animation: _waveController,
            builder: (context, child) {
              return Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        WarmsTheme.warmsAccent.withOpacity(_waveOpacity.value ?? 0.3),
                        WarmsTheme.warmsBlue.withOpacity(_waveOpacity.value ?? 0.1),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          
          // Contenu principal
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo WARMS animé
                AnimatedBuilder(
                  animation: _logoController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _logoScale.value,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: WarmsTheme.warmsBlue.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            Icons.medical_services,
                            size: 60,
                            color: WarmsTheme.warmsAccent,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 40),
                
                // Texte "WARMS" animé lettre par lettre
                AnimatedBuilder(
                  animation: _textController,
                  builder: (context, child) {
                    return _buildAnimatedText();
                  },
                ),
                
                const SizedBox(height: 20),
                
                // Texte de chargement
                AnimatedBuilder(
                  animation: _textController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _textOpacity.value,
                      child: Text(
                        'Santé connectée',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.8),
                          fontWeight: FontWeight.w300,
                          letterSpacing: 1.2,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedText() {
    const String text = 'WARMS';
    // Important (Flutter Web / petits écrans):
    // Le Row peut overflow si la largeur est trop faible. On scale le texte
    // pour garantir un layout sans exception (sinon écran blanc).
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: text.split('').asMap().entries.map((entry) {
          final index = entry.key;
          final letter = entry.value;

          return AnimatedBuilder(
            animation: _textController,
            builder: (context, child) {
              final delay = index * 100; // Délai progressif pour chaque lettre
              final animationValue = (_textController.value - (delay / 1500)).clamp(0.0, 1.0);

              return Transform.translate(
                offset: Offset(
                  0,
                  animationValue * 20 * (index % 2 == 0 ? -1 : 1), // Effet de vague
                ),
                child: Opacity(
                  opacity: animationValue,
                  child: Text(
                    letter,
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: _letterSpacing.value,
                      shadows: [
                        Shadow(
                          color: WarmsTheme.warmsNavy.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }).toList(),
      ),
    );
  }
}
