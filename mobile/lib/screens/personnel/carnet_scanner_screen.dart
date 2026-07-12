import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../themes/warms_theme.dart';
import '../../services/carnet_service.dart';
import 'carnet_confirmation_screen.dart';

class CarnetScannerScreen extends StatefulWidget {
  const CarnetScannerScreen({super.key});

  @override
  State<CarnetScannerScreen> createState() => _CarnetScannerScreenState();
}

class _CarnetScannerScreenState extends State<CarnetScannerScreen>
    with SingleTickerProviderStateMixin {
  final _picker = ImagePicker();
  File? _image;
  bool _enAnalyse = false;
  late final AnimationController _scanCtrl;
  late final Animation<double> _scanAnim;

  @override
  void initState() {
    super.initState();
    _scanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _scanAnim = CurvedAnimation(parent: _scanCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _scanCtrl.dispose();
    super.dispose();
  }

  Future<void> _choisirImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 95,
        maxWidth: 2400,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (picked == null || !mounted) return;
      setState(() => _image = File(picked.path));
    } catch (e) {
      if (!mounted) return;
      final cible = source == ImageSource.camera ? 'la caméra' : 'la galerie';
      _snack("Impossible d'accéder à $cible.");
    }
  }

  Future<void> _analyser() async {
    if (_image == null) return;
    setState(() => _enAnalyse = true);
    try {
      final result = await CarnetService.instance.analyserCarnet(_image!);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CarnetConfirmationScreen(scanResult: result),
        ),
      );
      if (mounted) setState(() => _image = null);
    } catch (e) {
      if (!mounted) return;
      _snack('Erreur lors de l\'analyse OCR : $e');
    } finally {
      if (mounted) setState(() => _enAnalyse = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: WarmsTheme.warmsError),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WarmsTheme.warmsBg,
      appBar: AppBar(
        backgroundColor: WarmsTheme.warmsAccent,
        foregroundColor: Colors.white,
        title: const Text(
          'Scanner un carnet',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildConseils(),
                const SizedBox(height: 20),
                _buildImageZone(),
                const SizedBox(height: 20),
                _buildCaptureButtons(),
                if (_image != null) ...[
                  const SizedBox(height: 16),
                  _buildAnalyseButton(),
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
          if (_enAnalyse) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildConseils() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            WarmsTheme.warmsAccent.withValues(alpha: 0.08),
            WarmsTheme.warmsBlue.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WarmsTheme.warmsAccent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: WarmsTheme.warmsAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.tips_and_updates_rounded,
                    color: WarmsTheme.warmsAccent, size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'Conseils pour un bon scan',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: WarmsTheme.warmsNavy,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _conseil(Icons.light_mode_rounded, 'Bonne luminosité, évitez les reflets'),
          _conseil(Icons.crop_free_rounded, 'Cadrez la page complète du carnet'),
          _conseil(Icons.text_fields_rounded, 'Le texte doit être lisible et net'),
          _conseil(Icons.straighten_rounded, 'Tenez le document bien à plat'),
        ],
      ),
    );
  }

  Widget _conseil(IconData icon, String texte) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Icon(icon, size: 15, color: WarmsTheme.warmsAccent),
          const SizedBox(width: 8),
          Text(
            texte,
            style: const TextStyle(color: WarmsTheme.warmsGray, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  Widget _buildImageZone() {
    if (_image != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            Image.file(
              _image!,
              width: double.infinity,
              height: 340,
              fit: BoxFit.cover,
            ),
            // Overlay corners
            Positioned.fill(
              child: CustomPaint(painter: _CornersOverlayPainter()),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: () => setState(() => _image = null),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.all(7),
                  child: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
            ),
            Positioned(
              bottom: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded,
                        color: Colors.greenAccent, size: 14),
                    SizedBox(width: 5),
                    Text(
                      'Image prête à analyser',
                      style: TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => _choisirImage(ImageSource.camera),
      child: Container(
        width: double.infinity,
        height: 230,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: WarmsTheme.warmsAccent.withValues(alpha: 0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: WarmsTheme.warmsAccent.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: WarmsTheme.warmsAccent.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_a_photo_rounded,
                size: 36,
                color: WarmsTheme.warmsAccent,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Appuyez pour photographier le carnet',
              style: TextStyle(
                color: WarmsTheme.warmsNavy,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'ou utilisez le bouton Galerie ci-dessous',
              style: TextStyle(color: WarmsTheme.warmsGray, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaptureButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _choisirImage(ImageSource.camera),
            icon: const Icon(Icons.camera_alt_rounded, size: 20),
            label: const Text('Caméra',
                style: TextStyle(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: WarmsTheme.warmsAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _choisirImage(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_rounded, size: 20),
            label: const Text('Galerie',
                style: TextStyle(fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: WarmsTheme.warmsAccent,
              side: const BorderSide(color: WarmsTheme.warmsAccent, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyseButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [WarmsTheme.warmsBlue, WarmsTheme.warmsAccent],
        ),
        boxShadow: [
          BoxShadow(
            color: WarmsTheme.warmsAccent.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: _analyser,
        icon: const Icon(Icons.document_scanner_rounded, size: 22),
        label: const Text(
          'Analyser et extraire les données',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.65),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 24,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icône animée
              AnimatedBuilder(
                animation: _scanAnim,
                builder: (context, child) => Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: WarmsTheme.warmsAccent
                            .withValues(alpha: 0.08 + _scanAnim.value * 0.06),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const Icon(Icons.document_scanner_rounded,
                        size: 34, color: WarmsTheme.warmsAccent),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Analyse en cours…',
                style: TextStyle(
                  color: WarmsTheme.warmsNavy,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Reconnaissance et extraction des champs',
                style: TextStyle(color: WarmsTheme.warmsGray, fontSize: 12.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              const LinearProgressIndicator(
                color: WarmsTheme.warmsAccent,
                backgroundColor: Color(0xFFE8EBF4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Peint 4 coins en surimpression sur l'image pour guider le cadrage.
class _CornersOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = WarmsTheme.warmsAccent.withValues(alpha: 0.85)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 28.0;
    const r = 12.0;

    void corner(double x, double y, double dx, double dy) {
      canvas.drawLine(Offset(x + dx * r, y), Offset(x + dx * len, y), paint);
      canvas.drawLine(Offset(x, y + dy * r), Offset(x, y + dy * len), paint);
      // Arc coin
      final rect = Rect.fromLTWH(x - r, y - r, r * 2, r * 2);
      final startAngle = dy < 0
          ? (dx < 0 ? 0.0 : 3.14159)
          : (dx < 0 ? 4.71239 : 1.5708);
      canvas.drawArc(rect, startAngle * dx.sign, 1.5708, false, paint);
    }

    corner(12, 12, 1, 1);
    corner(size.width - 12, 12, -1, 1);
    corner(12, size.height - 12, 1, -1);
    corner(size.width - 12, size.height - 12, -1, -1);
  }

  @override
  bool shouldRepaint(_CornersOverlayPainter _) => false;
}
