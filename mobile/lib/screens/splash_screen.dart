import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../themes/warms_theme.dart';

/// Écran de démarrage (boot) de Wam's Mobile.
///
/// Remplace l'ancienne animation logo + texte "Wam's" par une courte vidéo
/// de marque (`assets/splashscreen/splashscreen-video.mp4`), plus légère et
/// plus rapide à l'écran. Affiché tant que [AppGate] restaure la session
/// (voir app.dart) : [onTermine] est appelé une seule fois, à la fin de la
/// vidéo ou après un délai de sécurité si elle ne peut pas être lue (fichier
/// manquant, codec non supporté...), pour ne jamais bloquer l'utilisateur
/// sur cet écran.
class SplashScreen extends StatefulWidget {
  final VoidCallback onTermine;

  const SplashScreen({super.key, required this.onTermine});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  VideoPlayerController? _controleur;
  bool _termine = false;

  @override
  void initState() {
    super.initState();
    _initialiserVideo();
  }

  Future<void> _initialiserVideo() async {
    final controleur = VideoPlayerController.asset('assets/splashscreen/splashscreen-video.mp4');
    _controleur = controleur;
    try {
      await controleur.initialize();
      if (!mounted) return;
      controleur.addListener(() {
        final valeur = controleur.value;
        if (valeur.position >= valeur.duration && valeur.duration > Duration.zero) {
          _finir();
        }
      });
      await controleur.setLooping(false);
      // Muet : les navigateurs (Flutter Web) bloquent l'autoplay d'une
      // vidéo non muette sans interaction utilisateur — la lecture
      // échouait silencieusement et l'écran restait bloqué sur la
      // première image jusqu'au garde-fou de 6s.
      await controleur.setVolume(0);
      await controleur.play();
      setState(() {});
      // Garde-fou : si la vidéo (durée inconnue, bloquée...) ne déclenche
      // jamais la fin détectée ci-dessus, on bascule quand même après un
      // délai raisonnable plutôt que de bloquer l'écran indéfiniment.
      Future.delayed(const Duration(seconds: 6), _finir);
    } catch (_) {
      _finir();
    }
  }

  void _finir() {
    if (_termine || !mounted) return;
    _termine = true;
    widget.onTermine();
  }

  @override
  void dispose() {
    _controleur?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controleur = _controleur;
    final pret = controleur != null && controleur.value.isInitialized;

    return Scaffold(
      backgroundColor: WarmsTheme.warmsNavy,
      body: GestureDetector(
        onTap: _finir,
        child: Center(
          child: pret
              ? AspectRatio(
                  aspectRatio: controleur.value.aspectRatio,
                  child: VideoPlayer(controleur),
                )
              : const CircularProgressIndicator(color: WarmsTheme.warmsAccent),
        ),
      ),
    );
  }
}
