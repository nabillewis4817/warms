import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../models/ordonnance.dart';
import '../services/api_client.dart';
import '../services/pdf_downloader.dart';
import '../themes/warms_theme.dart';
import '../widgets/primary_button.dart';

/// Détail complet d'une ordonnance : branding du cabinet, praticien,
/// liste des médicaments, conseils, recommandations, et téléchargement du
/// PDF généré par le backend.
class PrescriptionDetailScreen extends StatefulWidget {
  final Prescription prescription;

  const PrescriptionDetailScreen({super.key, required this.prescription});

  @override
  State<PrescriptionDetailScreen> createState() => _PrescriptionDetailScreenState();
}

class _PrescriptionDetailScreenState extends State<PrescriptionDetailScreen> {
  bool _ouvertureEnCours = false;

  Color get _couleurStatut {
    switch (widget.prescription.statut) {
      case 'terminee':
        return WarmsTheme.warmsBlue;
      case 'annulee':
        return WarmsTheme.warmsError;
      default:
        return WarmsTheme.warmsSuccess;
    }
  }

  /// Télécharge le PDF via le client HTTP authentifié de l'app (et non via
  /// [launchUrl] en mode externe, qui ouvre l'URL dans le navigateur du
  /// système SANS l'en-tête `Authorization` — le backend exige une session
  /// connectée sur cette route, donc cette ouverture externe échouait
  /// toujours silencieusement), puis l'ouvre depuis un fichier local.
  Future<void> _ouvrirPdf() async {
    setState(() => _ouvertureEnCours = true);
    try {
      final reponse = await ApiClient.instance.dio.get<List<int>>(
        widget.prescription.urlPdf,
        options: Options(responseType: ResponseType.bytes),
      );
      final erreur = await ouvrirPdfDepuisOctets(reponse.data!, 'ordonnance_${widget.prescription.id}.pdf');
      if (erreur != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erreur)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Impossible de télécharger le PDF de l'ordonnance.")),
        );
      }
    } finally {
      if (mounted) setState(() => _ouvertureEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.prescription;
    return Scaffold(
      backgroundColor: WarmsTheme.warmsBg,
      appBar: AppBar(
        title: const Text('Ordonnance'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: WarmsTheme.warmsCard,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(color: WarmsTheme.warmsBlue.withValues(alpha: 0.08), blurRadius: 18, offset: const Offset(0, 8)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: WarmsTheme.warmsHeroGradient,
                        ),
                        child: const Icon(Icons.emoji_emotions_rounded, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Cabinet Wam's", style: TextStyle(fontWeight: FontWeight.w800, color: WarmsTheme.warmsNavy)),
                            Text('Chirurgie dentaire & soins bucco-dentaires',
                                style: TextStyle(fontSize: 11, color: WarmsTheme.warmsGray)),
                          ],
                        ),
                      ),
                      const Icon(Icons.medication_liquid_rounded, color: WarmsTheme.warmsAccent),
                    ],
                  ),
                  const Divider(height: 28),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          p.titre.isEmpty ? 'Ordonnance' : p.titre,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: WarmsTheme.warmsNavy),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _couleurStatut.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          p.libelleStatut,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _couleurStatut),
                        ),
                      ),
                    ],
                  ),
                  if (p.praticienNom.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Dr. ${p.praticienNom}', style: const TextStyle(color: WarmsTheme.warmsGray, fontSize: 13)),
                  ],
                  if (p.creeLe != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${p.creeLe!.day.toString().padLeft(2, '0')}/${p.creeLe!.month.toString().padLeft(2, '0')}/${p.creeLe!.year}',
                      style: const TextStyle(color: WarmsTheme.warmsGray, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            _section('Traitement prescrit', Icons.medication_rounded, [
              if (p.lignes.isEmpty)
                const Text('Aucun médicament listé.', style: TextStyle(color: WarmsTheme.warmsGray))
              else
                ...p.lignes.map(
                  (l) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.circle, size: 7, color: WarmsTheme.warmsAccent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l.medicament, style: const TextStyle(fontWeight: FontWeight.w700, color: WarmsTheme.warmsNavy)),
                              if (l.posologie.isNotEmpty || l.duree.isNotEmpty || l.remarques.isNotEmpty)
                                Text(
                                  [l.posologie, l.duree, l.remarques].where((s) => s.isNotEmpty).join(' · '),
                                  style: const TextStyle(fontSize: 12.5, color: WarmsTheme.warmsGray),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ]),
            if (p.conseils.isNotEmpty)
              _section('Conseils du médecin', Icons.lightbulb_rounded, [
                Text(p.conseils, style: const TextStyle(color: WarmsTheme.warmsGray, height: 1.5)),
              ]),
            if (p.recommandations.isNotEmpty)
              _section('Recommandations', Icons.flag_rounded, [
                Text(p.recommandations, style: const TextStyle(color: WarmsTheme.warmsGray, height: 1.5)),
              ]),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Télécharger / voir le PDF',
              icone: Icons.picture_as_pdf_rounded,
              enChargement: _ouvertureEnCours,
              onPressed: _ouvrirPdf,
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String titre, IconData icone, List<Widget> contenu) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WarmsTheme.warmsCard,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icone, size: 18, color: WarmsTheme.warmsAccent),
              const SizedBox(width: 8),
              Text(titre, style: const TextStyle(fontWeight: FontWeight.w800, color: WarmsTheme.warmsNavy)),
            ],
          ),
          const SizedBox(height: 10),
          ...contenu,
        ],
      ),
    );
  }
}
