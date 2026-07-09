import 'package:flutter/material.dart';
import '../../models/ordonnance.dart';
import '../../services/patient_service.dart';
import '../../themes/warms_theme.dart';

class RdvScreen extends StatefulWidget {
  const RdvScreen({super.key});

  @override
  State<RdvScreen> createState() => _RdvScreenState();
}

class _RdvScreenState extends State<RdvScreen> {
  final _service = PatientService.instance;
  List<RendezVousPatient> _rdvs = [];
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() => _chargement = true);
    final rdvs = await _service.chargerMesRdv();
    if (!mounted) return;
    setState(() {
      _rdvs = rdvs;
      _chargement = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final futurs = _rdvs.where((r) => r.estFutur).toList();
    final passes = _rdvs.where((r) => !r.estFutur).toList();

    return Scaffold(
      backgroundColor: WarmsTheme.warmsBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        title: const Text('Mes Rendez-vous', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _charger),
        ],
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
          : RefreshIndicator(
              onRefresh: _charger,
              color: const Color(0xFF6366F1),
              child: _rdvs.isEmpty
                  ? _etatVide()
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (futurs.isNotEmpty) ...[
                          _sectionTitre('À venir', Icons.upcoming_rounded, const Color(0xFF6366F1)),
                          const SizedBox(height: 8),
                          ...futurs.map(_carteRdv),
                          const SizedBox(height: 20),
                        ],
                        if (passes.isNotEmpty) ...[
                          _sectionTitre('Historique', Icons.history_rounded, WarmsTheme.warmsGray),
                          const SizedBox(height: 8),
                          ...passes.map(_carteRdv),
                        ],
                      ],
                    ),
            ),
    );
  }

  Widget _sectionTitre(String titre, IconData icone, Color couleur) {
    return Row(
      children: [
        Icon(icone, color: couleur, size: 18),
        const SizedBox(width: 8),
        Text(
          titre,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: couleur,
          ),
        ),
      ],
    );
  }

  Widget _carteRdv(RendezVousPatient rdv) {
    final couleurStatut = _couleurStatut(rdv.statut);
    final estFutur = rdv.estFutur;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: WarmsTheme.warmsCard,
        borderRadius: BorderRadius.circular(16),
        border: estFutur
            ? Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.25))
            : null,
        boxShadow: [
          BoxShadow(
            color: WarmsTheme.warmsBlue.withValues(alpha: 0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Colonne date
            Container(
              width: 52,
              decoration: BoxDecoration(
                color: estFutur
                    ? const Color(0xFF6366F1).withValues(alpha: 0.1)
                    : WarmsTheme.warmsBg,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  Text(
                    rdv.debut.day.toString().padLeft(2, '0'),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: estFutur ? const Color(0xFF6366F1) : WarmsTheme.warmsGray,
                    ),
                  ),
                  Text(
                    _moisAbrege(rdv.debut.month),
                    style: TextStyle(
                      fontSize: 11,
                      color: estFutur ? const Color(0xFF6366F1) : WarmsTheme.warmsGray,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            // Infos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          rdv.motif.isNotEmpty ? rdv.motif : 'Consultation dentaire',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                            color: WarmsTheme.warmsNavy,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: couleurStatut.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          rdv.libelleStatut,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: couleurStatut,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded, size: 14, color: WarmsTheme.warmsGray),
                      const SizedBox(width: 4),
                      Text(
                        '${_heure(rdv.debut)} → ${_heure(rdv.fin)}',
                        style: TextStyle(fontSize: 12.5, color: WarmsTheme.warmsGray),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.person_rounded, size: 14, color: WarmsTheme.warmsGray),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          rdv.nomPraticien,
                          style: TextStyle(fontSize: 12.5, color: WarmsTheme.warmsGray),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _etatVide() {
    return ListView(
      children: [
        const SizedBox(height: 100),
        Center(
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.calendar_month_outlined, size: 36, color: Color(0xFF6366F1)),
              ),
              const SizedBox(height: 16),
              const Text(
                'Aucun rendez-vous',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: WarmsTheme.warmsNavy),
              ),
              const SizedBox(height: 8),
              const Text(
                'Vos rendez-vous avec le cabinet\napparaîtront ici une fois programmés.',
                textAlign: TextAlign.center,
                style: TextStyle(color: WarmsTheme.warmsGray, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _couleurStatut(String statut) {
    switch (statut) {
      case 'confirme':
        return const Color(0xFF22C55E);
      case 'annule':
        return WarmsTheme.warmsError;
      case 'effectue':
        return WarmsTheme.warmsGray;
      case 'reporte':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF6366F1);
    }
  }

  String _heure(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _moisAbrege(int mois) {
    const m = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun',
                'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'];
    return m[mois - 1];
  }
}
