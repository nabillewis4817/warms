import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../themes/warms_theme.dart';
import '../../services/carnet_service.dart';
import 'carnet_confirmation_screen.dart';

/// Écran de capture + OCR d'un carnet physique.
///
/// L'utilisateur prend une photo (caméra) ou sélectionne une image depuis
/// la galerie.  Au tap sur "Analyser", MLKit extrait le texte et navigue
/// vers [CarnetConfirmationScreen] avec les champs détectés.
class CarnetScannerScreen extends StatefulWidget {
  const CarnetScannerScreen({super.key});

  @override
  State<CarnetScannerScreen> createState() => _CarnetScannerScreenState();
}

class _CarnetScannerScreenState extends State<CarnetScannerScreen> {
  final _picker = ImagePicker();
  File? _image;
  bool _enAnalyse = false;

  Future<void> _choisirImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 1920,
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
      // Réinitialiser après retour
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
        title: const Text('Scanner un carnet'),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInstructions(),
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

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: WarmsTheme.warmsAccentTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WarmsTheme.warmsAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: WarmsTheme.warmsAccent, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Prenez une photo claire du carnet ouvert sur la page contenant '
              'les informations du patient (identité, groupe sanguin, allergies).',
              style: TextStyle(color: WarmsTheme.warmsBlue, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageZone() {
    if (_image != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Image.file(
              _image!,
              width: double.infinity,
              height: 320,
              fit: BoxFit.cover,
            ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => setState(() => _image = null),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: const Icon(Icons.close, color: Colors.white, size: 18),
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
        height: 220,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: WarmsTheme.warmsAccent.withValues(alpha: 0.3),
            width: 2,
            // dashed border via BoxDecoration n'est pas natif — on stylise avec couleur
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_rounded, size: 52, color: WarmsTheme.warmsAccent),
            SizedBox(height: 12),
            Text(
              'Appuyez pour prendre une photo',
              style: TextStyle(color: WarmsTheme.warmsGray, fontSize: 14),
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
            icon: const Icon(Icons.camera_alt_rounded),
            label: const Text('Caméra'),
            style: ElevatedButton.styleFrom(
              backgroundColor: WarmsTheme.warmsAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _choisirImage(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_rounded),
            label: const Text('Galerie'),
            style: OutlinedButton.styleFrom(
              foregroundColor: WarmsTheme.warmsAccent,
              side: const BorderSide(color: WarmsTheme.warmsAccent),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyseButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _analyser,
        icon: const Icon(Icons.document_scanner_rounded, size: 22),
        label: const Text(
          'Analyser et extraire les données',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: WarmsTheme.warmsBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 2,
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: WarmsTheme.warmsAccent, strokeWidth: 3),
              SizedBox(height: 16),
              Text(
                'Analyse OCR en cours…',
                style: TextStyle(
                  color: WarmsTheme.warmsNavy,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Extraction des champs du carnet',
                style: TextStyle(color: WarmsTheme.warmsGray, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
