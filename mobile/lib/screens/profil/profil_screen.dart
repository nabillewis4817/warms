import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/utilisateur.dart';
import '../../services/profil_service.dart';
import '../../themes/warms_theme.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/avatar_circle.dart';
import '../../widgets/primary_button.dart';

/// Écran de profil et préférences.
///
/// Regroupe l'identité de l'utilisateur (photo, QR code), la langue et le
/// mode sombre (appliqués immédiatement via [onModeSombreChange] /
/// [onLangueChange], puis persistés au tap sur "Enregistrer"), ainsi que
/// les préférences de notification.
class ProfilScreen extends StatefulWidget {
  final Utilisateur utilisateur;
  final VoidCallback onDeconnexion;
  final ValueChanged<bool>? onModeSombreChange;

  const ProfilScreen({
    super.key,
    required this.utilisateur,
    required this.onDeconnexion,
    this.onModeSombreChange,
  });

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  final _profilService = ProfilService.instance;

  late String _langue;
  late bool _modeSombre;
  late PreferencesNotifications _notifications;
  bool _enregistrementEnCours = false;
  String _message = '';

  late TextEditingController _prenomCtrl;
  late TextEditingController _nomCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _telephoneCtrl;
  late String _photoProfil;
  bool _identiteEnCours = false;
  bool _photoEnCours = false;

  @override
  void initState() {
    super.initState();
    _langue = widget.utilisateur.langueInterface;
    _modeSombre = widget.utilisateur.modeSombre;
    _notifications = widget.utilisateur.preferencesNotifications;

    _prenomCtrl = TextEditingController(text: widget.utilisateur.prenom);
    _nomCtrl = TextEditingController(text: widget.utilisateur.nom);
    _emailCtrl = TextEditingController(text: widget.utilisateur.email);
    _telephoneCtrl = TextEditingController(text: widget.utilisateur.telephone);
    _photoProfil = widget.utilisateur.photoProfil;
  }

  @override
  void dispose() {
    _prenomCtrl.dispose();
    _nomCtrl.dispose();
    _emailCtrl.dispose();
    _telephoneCtrl.dispose();
    super.dispose();
  }

  bool get _francais => _langue == 'fr';

  Future<void> _enregistrerIdentite() async {
    setState(() => _identiteEnCours = true);
    try {
      await _profilService.mettreAJourIdentite(
        prenom: _prenomCtrl.text.trim(),
        nom: _nomCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        telephone: _telephoneCtrl.text.trim(),
      );
      setState(() => _message = _francais ? 'Informations mises à jour.' : 'Information updated.');
    } catch (_) {
      setState(() => _message = _francais ? 'Échec de la mise à jour.' : 'Update failed.');
    } finally {
      if (mounted) setState(() => _identiteEnCours = false);
    }
  }

  Future<void> _changerPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded, color: WarmsTheme.warmsAccent),
              title: Text(_francais ? 'Prendre une photo' : 'Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: WarmsTheme.warmsAccent),
              title: Text(_francais ? 'Choisir dans la galerie' : 'Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final fichier = await ImagePicker().pickImage(source: source, maxWidth: 1024, imageQuality: 85);
    if (fichier == null) return;

    setState(() => _photoEnCours = true);
    try {
      final url = await _profilService.uploaderPhotoProfil(File(fichier.path));
      setState(() => _photoProfil = url);
    } catch (_) {
      setState(() => _message = _francais ? 'Échec de l\'envoi de la photo.' : 'Photo upload failed.');
    } finally {
      if (mounted) setState(() => _photoEnCours = false);
    }
  }

  Future<void> _ouvrirChangementMotDePasse() async {
    await showDialog<void>(
      context: context,
      builder: (context) => _DialogueMotDePasse(francais: _francais),
    );
  }

  Future<void> _enregistrer() async {
    setState(() => _enregistrementEnCours = true);
    try {
      await _profilService.sauvegarderPreferences(
        langueInterface: _langue,
        modeSombre: _modeSombre,
        preferences: _notifications,
      );
      setState(() => _message = _francais ? 'Préférences enregistrées.' : 'Preferences saved.');
    } catch (_) {
      setState(() => _message = _francais ? 'Erreur de sauvegarde.' : 'Save failed.');
    } finally {
      if (mounted) setState(() => _enregistrementEnCours = false);
    }
  }

  void _changerModeSombre(bool valeur) {
    setState(() => _modeSombre = valeur);
    widget.onModeSombreChange?.call(valeur);
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.utilisateur;

    return Scaffold(
      backgroundColor: WarmsTheme.warmsBg,
      appBar: AppBar(
        title: Text(_francais ? 'Mon profil' : 'My profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          _carteIdentite(u),
          const SizedBox(height: 16),
          _carteSection(
            titre: _francais ? 'Informations personnelles' : 'Personal information',
            enfant: Column(
              children: [
                AppTextField(controller: _prenomCtrl, label: _francais ? 'Prénom' : 'First name', icone: Icons.badge_outlined),
                const SizedBox(height: 12),
                AppTextField(controller: _nomCtrl, label: _francais ? 'Nom' : 'Last name', icone: Icons.badge_outlined),
                const SizedBox(height: 12),
                AppTextField(controller: _emailCtrl, label: 'Email', icone: Icons.email_outlined, typeClavier: TextInputType.emailAddress),
                const SizedBox(height: 12),
                AppTextField(controller: _telephoneCtrl, label: _francais ? 'Téléphone' : 'Phone', icone: Icons.phone_outlined, typeClavier: TextInputType.phone),
                const SizedBox(height: 14),
                PrimaryButton(
                  label: _identiteEnCours ? '...' : (_francais ? 'Mettre à jour' : 'Update'),
                  icone: Icons.check_rounded,
                  enChargement: _identiteEnCours,
                  onPressed: _enregistrerIdentite,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _carteSection(
            titre: _francais ? 'Sécurité' : 'Security',
            enfant: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.lock_outline_rounded, color: WarmsTheme.warmsAccent),
              title: Text(_francais ? 'Changer le mot de passe' : 'Change password'),
              trailing: const Icon(Icons.chevron_right_rounded, color: WarmsTheme.warmsGray),
              onTap: _ouvrirChangementMotDePasse,
            ),
          ),
          const SizedBox(height: 16),
          _carteSection(
            titre: _francais ? 'Apparence et langue' : 'Appearance and language',
            enfant: Column(
              children: [
                _ligneChoixLangue(),
                const Divider(height: 28),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_francais ? 'Mode sombre' : 'Dark mode'),
                  value: _modeSombre,
                  activeColor: WarmsTheme.warmsAccent,
                  onChanged: _changerModeSombre,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _carteSection(
            titre: _francais ? 'Notifications et rappels' : 'Notifications and reminders',
            enfant: Column(
              children: [
                _switchNotif('Email', _notifications.email, (v) => setState(() => _notifications = _notifications.copyWith(email: v))),
                _switchNotif('SMS', _notifications.sms, (v) => setState(() => _notifications = _notifications.copyWith(sms: v))),
                _switchNotif('Push', _notifications.push, (v) => setState(() => _notifications = _notifications.copyWith(push: v))),
                _switchNotif(
                  _francais ? 'Rappels automatiques' : 'Automatic reminders',
                  _notifications.rappelsAuto,
                  (v) => setState(() => _notifications = _notifications.copyWith(rappelsAuto: v)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: _enregistrementEnCours ? '...' : (_francais ? 'Enregistrer' : 'Save'),
            icone: Icons.save_rounded,
            enChargement: _enregistrementEnCours,
            onPressed: _enregistrer,
          ),
          if (_message.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(_message, textAlign: TextAlign.center, style: const TextStyle(color: WarmsTheme.warmsSuccess)),
          ],
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: widget.onDeconnexion,
            icon: const Icon(Icons.logout_rounded, color: WarmsTheme.warmsError),
            label: Text(
              _francais ? 'Déconnexion' : 'Sign out',
              style: const TextStyle(color: WarmsTheme.warmsError),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: WarmsTheme.warmsError),
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ],
      ),
    );
  }

  Widget _carteIdentite(Utilisateur u) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [WarmsTheme.warmsAccent.withValues(alpha: 0.1), WarmsTheme.warmsBlue.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: WarmsTheme.warmsAccent.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _photoEnCours ? null : _changerPhoto,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                AvatarCircle(initiales: u.initiales, photoUrl: _photoProfil, taille: 70),
                if (_photoEnCours)
                  const Positioned.fill(
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(color: WarmsTheme.warmsAccent, shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(u.nomComplet.isEmpty ? '—' : u.nomComplet,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: WarmsTheme.warmsNavy)),
                const SizedBox(height: 2),
                Text(u.role, style: const TextStyle(color: WarmsTheme.warmsGray, fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 4),
                Text(u.email, style: const TextStyle(color: WarmsTheme.warmsGray, fontSize: 12.5)),
              ],
            ),
          ),
          if (u.qrCode.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: WarmsTheme.warmsCard, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.qr_code_2_rounded, color: WarmsTheme.warmsAccent, size: 28),
            ),
        ],
      ),
    );
  }

  Widget _carteSection({required String titre, required Widget enfant}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: WarmsTheme.warmsCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: WarmsTheme.warmsBlue.withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titre, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: WarmsTheme.warmsNavy)),
          const SizedBox(height: 8),
          enfant,
        ],
      ),
    );
  }

  Widget _ligneChoixLangue() {
    return Row(
      children: [
        Expanded(child: Text(_francais ? "Langue de l'interface" : 'Interface language')),
        ChoiceChip(
          label: const Text('FR'),
          selected: _francais,
          selectedColor: WarmsTheme.warmsAccent.withValues(alpha: 0.18),
          onSelected: (_) => setState(() => _langue = 'fr'),
        ),
        const SizedBox(width: 6),
        ChoiceChip(
          label: const Text('EN'),
          selected: !_francais,
          selectedColor: WarmsTheme.warmsAccent.withValues(alpha: 0.18),
          onSelected: (_) => setState(() => _langue = 'en'),
        ),
      ],
    );
  }

  Widget _switchNotif(String label, bool valeur, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      value: valeur,
      activeColor: WarmsTheme.warmsAccent,
      onChanged: onChanged,
    );
  }
}

/// Dialogue de changement de mot de passe (ancien + nouveau), appelle
/// `POST /personnel/me/mot-de-passe/` via [ProfilService].
class _DialogueMotDePasse extends StatefulWidget {
  final bool francais;
  const _DialogueMotDePasse({required this.francais});

  @override
  State<_DialogueMotDePasse> createState() => _DialogueMotDePasseState();
}

class _DialogueMotDePasseState extends State<_DialogueMotDePasse> {
  final _ancienCtrl = TextEditingController();
  final _nouveauCtrl = TextEditingController();
  bool _ancienVisible = false;
  bool _nouveauVisible = false;
  bool _enCours = false;
  String _erreur = '';

  @override
  void dispose() {
    _ancienCtrl.dispose();
    _nouveauCtrl.dispose();
    super.dispose();
  }

  Future<void> _valider() async {
    if (_ancienCtrl.text.isEmpty || _nouveauCtrl.text.isEmpty) {
      setState(() => _erreur = widget.francais ? 'Tous les champs sont requis.' : 'All fields are required.');
      return;
    }
    setState(() {
      _enCours = true;
      _erreur = '';
    });
    try {
      await ProfilService.instance.changerMotDePasse(
        ancien: _ancienCtrl.text,
        nouveau: _nouveauCtrl.text,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _erreur = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: WarmsTheme.warmsCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(widget.francais ? 'Changer le mot de passe' : 'Change password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppTextField(
            controller: _ancienCtrl,
            label: widget.francais ? 'Mot de passe actuel' : 'Current password',
            icone: Icons.lock_outline,
            motDePasse: true,
            motDePasseVisible: _ancienVisible,
            onToggleVisibilite: () => setState(() => _ancienVisible = !_ancienVisible),
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _nouveauCtrl,
            label: widget.francais ? 'Nouveau mot de passe' : 'New password',
            icone: Icons.lock_outline,
            motDePasse: true,
            motDePasseVisible: _nouveauVisible,
            onToggleVisibilite: () => setState(() => _nouveauVisible = !_nouveauVisible),
          ),
          if (_erreur.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(_erreur, style: const TextStyle(color: WarmsTheme.warmsError, fontSize: 13)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _enCours ? null : () => Navigator.of(context).pop(),
          child: Text(widget.francais ? 'Annuler' : 'Cancel'),
        ),
        TextButton(
          onPressed: _enCours ? null : _valider,
          child: Text(_enCours ? '...' : (widget.francais ? 'Valider' : 'Confirm')),
        ),
      ],
    );
  }
}
