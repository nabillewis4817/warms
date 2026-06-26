import 'package:flutter/material.dart';

import '../../models/notification_interne.dart';
import '../../services/notifications_internes_service.dart';
import '../../themes/warms_theme.dart';

/// Liste des notifications de l'utilisateur, avec marquage individuel
/// comme lue (tap). Le retour sur cet écran rafraîchit toujours le badge
/// de l'accueil, qui décrémente en conséquence.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _service = NotificationsInternesService.instance;
  List<NotificationInterne> _notifications = [];
  bool _enChargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() => _enChargement = true);
    final notifications = await _service.chargerNotifications();
    if (!mounted) return;
    setState(() {
      _notifications = notifications;
      _enChargement = false;
    });
  }

  Future<void> _marquerLu(NotificationInterne notif) async {
    if (notif.lu) return;
    setState(() {
      final index = _notifications.indexWhere((n) => n.id == notif.id);
      if (index != -1) {
        _notifications[index] = NotificationInterne(
          id: notif.id,
          titre: notif.titre,
          contenu: notif.contenu,
          niveau: notif.niveau,
          lu: true,
          creeLe: notif.creeLe,
        );
      }
    });
    try {
      await _service.marquerLu(notif.id);
    } catch (_) {
      // Pas grave si ça échoue silencieusement : un prochain chargement
      // remettra l'état réel ; on ne bloque pas l'utilisateur pour ça.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WarmsTheme.warmsBg,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: WarmsTheme.warmsCard,
      ),
      body: RefreshIndicator(
        onRefresh: _charger,
        color: WarmsTheme.warmsAccent,
        child: _enChargement
            ? const Center(child: CircularProgressIndicator(color: WarmsTheme.warmsAccent))
            : _notifications.isEmpty
                ? _etatVide()
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _carte(_notifications[index]),
                  ),
      ),
    );
  }

  Widget _etatVide() {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        Icon(Icons.notifications_off_outlined, size: 48, color: WarmsTheme.warmsGray.withValues(alpha: 0.5)),
        const SizedBox(height: 12),
        Text(
          'Aucune notification pour le moment',
          textAlign: TextAlign.center,
          style: TextStyle(color: WarmsTheme.warmsGray),
        ),
      ],
    );
  }

  Widget _carte(NotificationInterne notif) {
    final style = _styleNiveau(notif.niveau);
    return InkWell(
      onTap: () => _marquerLu(notif),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: WarmsTheme.warmsCard,
          borderRadius: BorderRadius.circular(18),
          border: notif.lu ? null : Border.all(color: style.couleur.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(color: WarmsTheme.warmsBlue.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: style.couleur.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(style.icone, color: style.couleur, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notif.titre,
                    style: TextStyle(
                      fontWeight: notif.lu ? FontWeight.w600 : FontWeight.w800,
                      color: WarmsTheme.warmsNavy,
                      fontSize: 14.5,
                    ),
                  ),
                  if (notif.contenu.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(notif.contenu, style: TextStyle(color: WarmsTheme.warmsGray, fontSize: 13)),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    _formaterDate(notif.creeLe),
                    style: TextStyle(color: WarmsTheme.warmsGray.withValues(alpha: 0.8), fontSize: 11),
                  ),
                ],
              ),
            ),
            if (!notif.lu)
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: style.couleur, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }

  _StyleNiveau _styleNiveau(String niveau) {
    switch (niveau) {
      case 'critique':
        return _StyleNiveau(Icons.warning_amber_rounded, WarmsTheme.warmsError);
      case 'rappel':
        return _StyleNiveau(Icons.notifications_active_rounded, WarmsTheme.warmsBlue);
      case 'message':
        return _StyleNiveau(Icons.chat_bubble_rounded, WarmsTheme.warmsAccent);
      default:
        return _StyleNiveau(Icons.info_rounded, WarmsTheme.warmsGray);
    }
  }

  String _formaterDate(DateTime date) {
    final maintenant = DateTime.now();
    final diff = maintenant.difference(date);
    if (diff.inMinutes < 1) return "À l'instant";
    if (diff.inHours < 1) return 'Il y a ${diff.inMinutes} min';
    if (diff.inDays < 1) return 'Il y a ${diff.inHours} h';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _StyleNiveau {
  final IconData icone;
  final Color couleur;
  const _StyleNiveau(this.icone, this.couleur);
}
