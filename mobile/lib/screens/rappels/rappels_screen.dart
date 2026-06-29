import 'dart:async';

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../services/notification_service.dart';
import '../../services/rappels_service.dart';
import '../../themes/warms_theme.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/skeleton_box.dart';

/// Écran de rappels personnalisables : un patient programme lui-même un
/// rappel (médicament, rendez-vous, hygiène...) via un calendrier, avec une
/// récurrence au choix. Diffusion en notification locale uniquement (pas de
/// SMS/email — non disponible pour le moment).
class RappelsScreen extends StatefulWidget {
  const RappelsScreen({super.key});

  @override
  State<RappelsScreen> createState() => _RappelsScreenState();
}

class _RappelsScreenState extends State<RappelsScreen> {
  final _service = RappelsService.instance;

  List<Rappel> _rappels = [];
  bool _enChargement = true;
  bool _creationEnCours = false;

  DateTime _jourFocus = DateTime.now();
  DateTime? _jourSelectionne;
  TimeOfDay _heureSelectionnee = TimeOfDay.now();
  String _recurrence = 'aucune';
  final _titreCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _jourSelectionne = DateTime.now();
    NotificationService().demanderPermissionLocale();
    _charger();
  }

  @override
  void dispose() {
    _titreCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    setState(() => _enChargement = true);
    final rappels = await _service.lister();
    if (!mounted) return;
    setState(() {
      _rappels = rappels;
      _enChargement = false;
    });
    unawaited(_service.resynchroniser(rappels));
  }

  Set<DateTime> get _joursAvecRappel =>
      _rappels.map((r) => DateTime(r.dateHeure.year, r.dateHeure.month, r.dateHeure.day)).toSet();

  Future<void> _choisirHeure() async {
    final heure = await showTimePicker(context: context, initialTime: _heureSelectionnee);
    if (heure != null) setState(() => _heureSelectionnee = heure);
  }

  Future<void> _creerRappel() async {
    final titre = _titreCtrl.text.trim();
    if (titre.isEmpty || _jourSelectionne == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Donnez un titre et une date à votre rappel.')),
      );
      return;
    }

    final dateHeure = DateTime(
      _jourSelectionne!.year,
      _jourSelectionne!.month,
      _jourSelectionne!.day,
      _heureSelectionnee.hour,
      _heureSelectionnee.minute,
    );

    if (_recurrence == 'aucune' && dateHeure.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisissez une date/heure dans le futur.')),
      );
      return;
    }

    setState(() => _creationEnCours = true);
    try {
      await _service.creer(
        titre: titre,
        message: _messageCtrl.text.trim(),
        dateHeure: dateHeure,
        recurrence: _recurrence,
      );
      _titreCtrl.clear();
      _messageCtrl.clear();
      if (mounted) {
        setState(() => _recurrence = 'aucune');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rappel programmé avec succès.'), backgroundColor: WarmsTheme.warmsSuccess),
        );
      }
      await _charger();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de programmer ce rappel. Réessayez.')),
        );
      }
    } finally {
      if (mounted) setState(() => _creationEnCours = false);
    }
  }

  Future<void> _basculer(Rappel rappel) async {
    try {
      final maj = await _service.basculerActif(rappel);
      if (!mounted) return;
      setState(() {
        _rappels = _rappels.map((r) => r.id == maj.id ? maj : r).toList();
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action impossible.')));
      }
    }
  }

  Future<void> _supprimer(Rappel rappel) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce rappel ?'),
        content: Text('"${rappel.titre}" ne sera plus programmé.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: WarmsTheme.warmsError)),
          ),
        ],
      ),
    );
    if (confirme != true) return;

    setState(() => _rappels = _rappels.where((r) => r.id != rappel.id).toList());
    try {
      await _service.supprimer(rappel.id);
    } catch (_) {
      await _charger();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WarmsTheme.warmsBg,
      appBar: AppBar(title: const Text('Mes rappels'), backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _charger,
          color: WarmsTheme.warmsAccent,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              _carteCalendrier(),
              const SizedBox(height: 16),
              _carteFormulaire(),
              const SizedBox(height: 20),
              const Text('Rappels programmés', style: TextStyle(fontWeight: FontWeight.w800, color: WarmsTheme.warmsNavy)),
              const SizedBox(height: 10),
              if (_enChargement)
                const SkeletonListe(count: 3)
              else if (_rappels.isEmpty)
                _etatVide()
              else
                ..._rappels.map(_carteRappel),
            ],
          ),
        ),
      ),
    );
  }

  Widget _carteCalendrier() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: WarmsTheme.warmsCard, borderRadius: BorderRadius.circular(20)),
      child: TableCalendar(
        firstDay: DateTime.now().subtract(const Duration(days: 365)),
        lastDay: DateTime.now().add(const Duration(days: 730)),
        focusedDay: _jourFocus,
        selectedDayPredicate: (jour) => _jourSelectionne != null && isSameDay(jour, _jourSelectionne),
        onDaySelected: (selectionne, focus) => setState(() {
          _jourSelectionne = selectionne;
          _jourFocus = focus;
        }),
        calendarFormat: CalendarFormat.month,
        availableGestures: AvailableGestures.horizontalSwipe,
        headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
        calendarStyle: CalendarStyle(
          selectedDecoration: const BoxDecoration(color: WarmsTheme.warmsAccent, shape: BoxShape.circle),
          todayDecoration: BoxDecoration(color: WarmsTheme.warmsAccent.withValues(alpha: 0.3), shape: BoxShape.circle),
          markerDecoration: const BoxDecoration(color: WarmsTheme.warmsBlue, shape: BoxShape.circle),
        ),
        eventLoader: (jour) => _joursAvecRappel.contains(DateTime(jour.year, jour.month, jour.day)) ? const [1] : const [],
      ),
    );
  }

  Widget _carteFormulaire() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: WarmsTheme.warmsCard, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Nouveau rappel', style: TextStyle(fontWeight: FontWeight.w800, color: WarmsTheme.warmsNavy)),
          const SizedBox(height: 12),
          TextField(
            controller: _titreCtrl,
            decoration: const InputDecoration(labelText: 'Titre (ex: Prendre le médicament)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _messageCtrl,
            decoration: const InputDecoration(labelText: 'Message (optionnel)', border: OutlineInputBorder()),
            maxLines: 2,
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: _choisirHeure,
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Heure', border: OutlineInputBorder()),
              child: Text(_heureSelectionnee.format(context)),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              _chipRecurrence('aucune', 'Une fois'),
              _chipRecurrence('quotidien', 'Quotidien'),
              _chipRecurrence('hebdomadaire', 'Hebdomadaire'),
              _chipRecurrence('mensuel', 'Mensuel'),
            ],
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Programmer le rappel',
            icone: Icons.alarm_add_rounded,
            enChargement: _creationEnCours,
            onPressed: _creerRappel,
          ),
        ],
      ),
    );
  }

  Widget _chipRecurrence(String valeur, String label) {
    final selectionne = _recurrence == valeur;
    return ChoiceChip(
      label: Text(label),
      selected: selectionne,
      onSelected: (_) => setState(() => _recurrence = valeur),
      selectedColor: WarmsTheme.warmsAccent,
      labelStyle: TextStyle(color: selectionne ? Colors.white : WarmsTheme.warmsNavy, fontWeight: FontWeight.w600),
    );
  }

  Widget _carteRappel(Rappel rappel) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: WarmsTheme.warmsCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: rappel.actif ? Colors.transparent : WarmsTheme.warmsGray.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (rappel.actif ? WarmsTheme.warmsAccent : WarmsTheme.warmsGray).withValues(alpha: 0.12),
            ),
            child: Icon(Icons.alarm_rounded, color: rappel.actif ? WarmsTheme.warmsAccent : WarmsTheme.warmsGray),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rappel.titre, style: const TextStyle(fontWeight: FontWeight.w700, color: WarmsTheme.warmsNavy)),
                Text(
                  '${_formatDate(rappel.dateHeure)} · ${rappel.libelleRecurrence}',
                  style: const TextStyle(fontSize: 12, color: WarmsTheme.warmsGray),
                ),
              ],
            ),
          ),
          Switch(value: rappel.actif, activeColor: WarmsTheme.warmsAccent, onChanged: (_) => _basculer(rappel)),
          IconButton(
            onPressed: () => _supprimer(rappel),
            icon: const Icon(Icons.delete_outline_rounded, color: WarmsTheme.warmsError),
          ),
        ],
      ),
    );
  }

  Widget _etatVide() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.alarm_off_rounded, size: 40, color: WarmsTheme.warmsGray.withValues(alpha: 0.5)),
          const SizedBox(height: 8),
          const Text('Aucun rappel programmé', style: TextStyle(color: WarmsTheme.warmsGray)),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} à ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
