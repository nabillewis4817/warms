import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/ordonnance.dart';
import '../../models/utilisateur.dart';
import '../../services/patient_service.dart';
import '../../themes/warms_theme.dart';
import '../../widgets/avatar_circle.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/ordonnance_card.dart';
import '../../widgets/service_chip.dart';
import '../../widgets/skeleton_box.dart';
import '../avis/avis_modal.dart';
import '../messages/messages_screen.dart';
import '../ia_chat_screen.dart';
import '../ia_recherche_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profil/profil_screen.dart';

/// Écran d'accueil du patient.
///
/// Reproduit la structure de la maquette : en-tête avec salutation,
/// avatar et notifications ; carte de mise en avant ; rangée "Nos
/// services" ; liste ("Mes ordonnances") ; barre de navigation flottante.
class HomeScreen extends StatefulWidget {
  final Utilisateur utilisateur;
  final int patientId;
  final VoidCallback onDeconnexion;
  final ValueChanged<bool>? onModeSombreChange;

  const HomeScreen({
    super.key,
    required this.utilisateur,
    required this.patientId,
    required this.onDeconnexion,
    this.onModeSombreChange,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _patientService = PatientService.instance;

  List<Prescription> _ordonnances = [];
  Badges _badges = const Badges();
  bool _enChargement = true;
  Timer? _minuteurBadges;

  @override
  void initState() {
    super.initState();
    _charger();
    // Rafraîchit le compteur de notifications même sans action de
    // l'utilisateur, pour que le badge s'incrémente/décrémente tout seul
    // (ex. un message du cabinet arrivé entre-temps).
    _minuteurBadges = Timer.periodic(const Duration(seconds: 30), (_) => _rafraichirBadges());
  }

  @override
  void dispose() {
    _minuteurBadges?.cancel();
    super.dispose();
  }

  Future<void> _charger() async {
    setState(() => _enChargement = true);
    final resultats = await Future.wait([
      _patientService.chargerOrdonnances(),
      _patientService.chargerBadges(),
    ]);
    if (!mounted) return;
    setState(() {
      _ordonnances = resultats[0] as List<Prescription>;
      _badges = resultats[1] as Badges;
      _enChargement = false;
    });
  }

  Future<void> _rafraichirBadges() async {
    final badges = await _patientService.chargerBadges();
    if (!mounted) return;
    setState(() => _badges = badges);
  }

  Future<void> _ouvrirNotifications() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
    _rafraichirBadges();
  }

  void _onNavTap(int index) {
    switch (index) {
      case 0: // Accueil : déjà sur l'écran.
        break;
      case 1:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const MessagesScreen()));
        break;
      case 2:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const IAChatScreen()));
        break;
      case 3:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const IARechercheScreen()));
        break;
      case 4:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfilScreen(
              utilisateur: widget.utilisateur,
              onDeconnexion: widget.onDeconnexion,
              onModeSombreChange: widget.onModeSombreChange,
            ),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WarmsTheme.warmsBg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _charger,
          color: WarmsTheme.warmsAccent,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              _enTete(),
              const SizedBox(height: 24),
              if (_badges.total > 0) _carteRappels(),
              _titreSection('Nos services'),
              const SizedBox(height: 8),
              _rangeeServices(),
              const SizedBox(height: 24),
              _titreSection('Mes ordonnances'),
              const SizedBox(height: 12),
              if (_enChargement)
                const SkeletonListe(count: 3)
              else if (_ordonnances.isEmpty)
                _etatVideOrdonnances()
              else
                ..._ordonnances.take(5).map((o) => OrdonnanceCard(ordonnance: o)),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        indexActif: 0,
        onTap: _onNavTap,
        destinations: const [
          BottomNavDestination(icone: Icons.home_rounded, label: 'Accueil'),
          BottomNavDestination(icone: Icons.chat_bubble_rounded, label: 'Messages'),
          BottomNavDestination(icone: Icons.smart_toy_rounded, label: 'Chat IA'),
          BottomNavDestination(icone: Icons.search_rounded, label: 'Recherche'),
          BottomNavDestination(icone: Icons.person_rounded, label: 'Profil'),
        ],
      ),
    );
  }

  Widget _enTete() {
    return Row(
      children: [
        AvatarCircle(
          initiales: widget.utilisateur.initiales,
          photoUrl: widget.utilisateur.photoProfil,
          taille: 50,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bonjour, ${widget.utilisateur.prenom.isEmpty ? "patient" : widget.utilisateur.prenom} !',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: WarmsTheme.warmsNavy),
              ),
              const Text(
                'Comment vous sentez-vous aujourd\'hui ?',
                style: TextStyle(fontSize: 12.5, color: WarmsTheme.warmsGray),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IARechercheScreen())),
          icon: const Icon(Icons.search_rounded, color: WarmsTheme.warmsNavy),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: _ouvrirNotifications,
              icon: const Icon(Icons.notifications_none_rounded, color: WarmsTheme.warmsNavy),
            ),
            if (_badges.total > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: WarmsTheme.warmsHeart, shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    '${_badges.total}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _carteRappels() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [WarmsTheme.warmsAccent, WarmsTheme.warmsBlue]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: WarmsTheme.warmsAccent.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_badges.rappel} rappel(s) · ${_badges.critique} alerte(s)',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
                const Text(
                  'Pensez à vérifier vos messages du cabinet.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _titreSection(String titre) {
    return Text(titre, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: WarmsTheme.warmsNavy));
  }

  Widget _rangeeServices() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ServiceChip(icone: Icons.rate_review_rounded, label: 'Avis', onTap: () => ouvrirModalAvis(context)),
        ServiceChip(
          icone: Icons.chat_bubble_rounded,
          label: 'Messages',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MessagesScreen())),
        ),
        ServiceChip(
          icone: Icons.smart_toy_rounded,
          label: 'Chat IA',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IAChatScreen())),
        ),
        ServiceChip(
          icone: Icons.travel_explore_rounded,
          label: 'Recherche',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IARechercheScreen())),
        ),
      ],
    );
  }

  Widget _etatVideOrdonnances() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.medication_outlined, size: 40, color: WarmsTheme.warmsGray.withValues(alpha: 0.5)),
          const SizedBox(height: 8),
          Text('Aucune ordonnance pour le moment', style: TextStyle(color: WarmsTheme.warmsGray)),
        ],
      ),
    );
  }
}
