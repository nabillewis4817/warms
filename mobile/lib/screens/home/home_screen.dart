import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/ordonnance.dart';
import '../../models/utilisateur.dart';
import '../../services/patient_service.dart';
import '../../themes/warms_theme.dart';
import '../../widgets/avatar_circle.dart';
import '../../widgets/ordonnance_card.dart';
import '../../widgets/skeleton_box.dart';
import '../avis/avis_modal.dart';
import '../messages/messages_screen.dart';
import '../ia_chat_screen.dart';
import '../ia_recherche_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profil/profil_screen.dart';
import '../qr/qr_identite_screen.dart';
import '../suivi_douleur/suivi_douleur_screen.dart';

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
        Navigator.push(context, MaterialPageRoute(builder: (_) => const QrIdentiteScreen()));
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
      body: RefreshIndicator(
        onRefresh: _charger,
        color: WarmsTheme.warmsAccent,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _enTeteMarketplace()),
            SliverToBoxAdapter(child: _carteHero()),
            if (_badges.total > 0) SliverToBoxAdapter(child: _carteRappels()),
            SliverToBoxAdapter(child: _sectionServices()),
            SliverToBoxAdapter(child: _sectionOrdonnances()),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
      bottomNavigationBar: _bottomNavBar(),
    );
  }

  Widget _enTeteMarketplace() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [WarmsTheme.warmsAccent, WarmsTheme.warmsBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 16,
        right: 16,
        bottom: 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_rounded, color: Colors.white70, size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Votre cabinet',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    Text(
                      'Dr. ${widget.utilisateur.nom.isNotEmpty ? widget.utilisateur.nom : "Cabinet"}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Notifications
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    onPressed: _ouvrirNotifications,
                    icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
                  ),
                  if (_badges.total > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
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
              // Avatar profil
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfilScreen(
                      utilisateur: widget.utilisateur,
                      onDeconnexion: widget.onDeconnexion,
                      onModeSombreChange: widget.onModeSombreChange,
                    ),
                  ),
                ),
                child: AvatarCircle(
                  initiales: widget.utilisateur.initiales,
                  photoUrl: widget.utilisateur.photoProfil,
                  taille: 36,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Barre de recherche
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IARechercheScreen())),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, color: WarmsTheme.warmsGray, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Rechercher symptômes, médicaments…',
                      style: TextStyle(color: WarmsTheme.warmsGray, fontSize: 13.5),
                    ),
                  ),
                  Icon(Icons.mic_rounded, color: WarmsTheme.warmsAccent, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _carteHero() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0E6E76), Color(0xFF14919B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: WarmsTheme.warmsAccent.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bonjour, ${widget.utilisateur.prenom.isEmpty ? "patient" : widget.utilisateur.prenom} 👋',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Comment vous sentez-vous\naujourd\'hui ?',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                  ),
                  child: const Text(
                    'Voir mon dossier →',
                    style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.health_and_safety_rounded, color: Colors.white, size: 38),
          ),
        ],
      ),
    );
  }

  Widget _carteRappels() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFB800).withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active_rounded, color: Color(0xFFFFB800), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${_badges.total} notification(s) en attente',
              style: const TextStyle(
                color: Color(0xFF7A5200),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          GestureDetector(
            onTap: _ouvrirNotifications,
            child: const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF7A5200), size: 14),
          ),
        ],
      ),
    );
  }

  Widget _sectionServices() {
    final services = [
      _ServiceItem(icon: Icons.folder_shared_rounded, label: 'Mon Dossier', color: const Color(0xFF14919B),
        onTap: () {}),
      _ServiceItem(icon: Icons.calendar_month_rounded, label: 'Mes RDV', color: const Color(0xFF6366F1),
        onTap: () {}),
      _ServiceItem(icon: Icons.medication_rounded, label: 'Ordonnances', color: const Color(0xFF22C55E),
        onTap: () {}),
      _ServiceItem(icon: Icons.smart_toy_rounded, label: 'IA Chat', color: const Color(0xFF0E6E76),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IAChatScreen()))),
      _ServiceItem(icon: Icons.chat_bubble_rounded, label: 'Messages', color: const Color(0xFFF59E0B),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MessagesScreen()))),
      _ServiceItem(icon: Icons.rate_review_rounded, label: 'Avis', color: const Color(0xFFEF4444),
        onTap: () => ouvrirModalAvis(context)),
      _ServiceItem(icon: Icons.favorite_border_rounded, label: 'Suivi douleur', color: const Color(0xFFEF4444),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SuiviDouleurScreen()))),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nos services',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: WarmsTheme.warmsNavy),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.05,
            children: services.map((s) => _carteService(s)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _carteService(_ServiceItem s) {
    return GestureDetector(
      onTap: s.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: s.color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: s.color.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(12)),
              child: Icon(s.icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              s.label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: WarmsTheme.warmsNavy),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionOrdonnances() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Mes ordonnances',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: WarmsTheme.warmsNavy),
              ),
              TextButton(
                onPressed: () {},
                child: Text('Voir tout', style: TextStyle(color: WarmsTheme.warmsAccent, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_enChargement)
            const SkeletonListe(count: 3)
          else if (_ordonnances.isEmpty)
            _etatVideOrdonnances()
          else
            ..._ordonnances.take(5).map((o) => OrdonnanceCard(ordonnance: o)),
        ],
      ),
    );
  }

  Widget _etatVideOrdonnances() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      alignment: Alignment.center,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: WarmsTheme.warmsAccent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.medication_outlined, size: 32, color: WarmsTheme.warmsAccent.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 12),
          const Text(
            'Aucune ordonnance pour le moment',
            style: TextStyle(color: WarmsTheme.warmsGray, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _bottomNavBar() {
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        indicatorColor: WarmsTheme.warmsAccent.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
      child: NavigationBar(
        selectedIndex: 0,
        backgroundColor: Colors.white,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        onDestinationSelected: _onNavTap,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label: 'Messages',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_rounded),
            selectedIcon: Icon(Icons.qr_code_rounded),
            label: 'Mon QR',
          ),
          NavigationDestination(
            icon: Icon(Icons.travel_explore_outlined),
            selectedIcon: Icon(Icons.travel_explore_rounded),
            label: 'Recherche',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

class _ServiceItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ServiceItem({required this.icon, required this.label, required this.color, required this.onTap});
}
