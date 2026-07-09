import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/patient_service.dart';
import '../../themes/warms_theme.dart';

class QrIdentiteScreen extends StatefulWidget {
  const QrIdentiteScreen({super.key});

  @override
  State<QrIdentiteScreen> createState() => _QrIdentiteScreenState();
}

class _QrIdentiteScreenState extends State<QrIdentiteScreen> {
  final _service = PatientService.instance;
  String? _token;
  String? _nomPatient;
  String? _numeroDossier;
  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() { _chargement = true; _erreur = null; });
    try {
      // Appelle GET /api/v1/qr/carnets/mon-qr/
      final data = await _service.chargerMonQr();
      if (!mounted) return;
      setState(() {
        _token = data['token'] as String?;
        final patient = data['patient'] as Map<String, dynamic>?;
        final dossier = data['dossier'] as Map<String, dynamic>?;
        _nomPatient = patient != null ? '${patient['prenom']} ${patient['nom']}' : null;
        _numeroDossier = dossier?['numero_dossier'] as String?;
        _chargement = false;
      });
    } catch (e) {
      if (!mounted) return;
      // 404 = aucun QR actif créé pour ce patient (normal si le dossier est
      // récent et que la réception n'a pas encore scanné/activé le carnet).
      String message = 'Impossible de charger votre QR code.';
      if (e is Exception && e.toString().contains('404') ||
          e.toString().contains('404')) {
        message = 'Votre QR code n\'est pas encore disponible.\n'
            'Contactez la réception pour qu\'elle active votre carnet.';
      }
      setState(() {
        _erreur = message;
        _chargement = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WarmsTheme.warmsBg,
      appBar: AppBar(
        backgroundColor: WarmsTheme.warmsAccent,
        foregroundColor: Colors.white,
        title: const Text('Mon QR Code', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _charger,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator(color: WarmsTheme.warmsAccent))
          : _erreur != null
              ? _etatErreur()
              : _contenu(),
    );
  }

  Widget _contenu() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 8),
          // Instruction
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: WarmsTheme.warmsAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: WarmsTheme.warmsAccent.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: WarmsTheme.warmsAccent, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Présentez ce code à la réception\nlors de votre arrivée au cabinet.',
                    style: TextStyle(fontSize: 13, color: WarmsTheme.warmsBlue, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // QR Code
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: WarmsTheme.warmsAccent.withValues(alpha: 0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                if (_token != null)
                  // QR code visuel
                  // Si qr_flutter est disponible, utilise : QrImageView(data: _token!, size: 220)
                  // Sinon affiche un placeholder avec le token tronqué :
                  _qrWidget(),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                // Infos patient
                if (_nomPatient != null)
                  Text(
                    _nomPatient!,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: WarmsTheme.warmsNavy,
                    ),
                  ),
                if (_numeroDossier != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_outlined, size: 16, color: WarmsTheme.warmsGray),
                      const SizedBox(width: 4),
                      Text(
                        'Dossier N° $_numeroDossier',
                        style: const TextStyle(fontSize: 13, color: WarmsTheme.warmsGray),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Bouton copier token (debug/secours)
          if (_token != null)
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _token!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Token copié'), duration: Duration(seconds: 2)),
                );
              },
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copier le code manuellement'),
              style: TextButton.styleFrom(foregroundColor: WarmsTheme.warmsGray),
            ),
        ],
      ),
    );
  }

  Widget _qrWidget() {
    return QrImageView(
      data: _token!,
      version: QrVersions.auto,
      size: 220,
      backgroundColor: Colors.white,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: WarmsTheme.warmsNavy,
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: WarmsTheme.warmsNavy,
      ),
    );
  }

  Widget _etatErreur() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 56, color: WarmsTheme.warmsGray.withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            Text(_erreur!, textAlign: TextAlign.center, style: const TextStyle(color: WarmsTheme.warmsGray)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _charger,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: WarmsTheme.warmsAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
