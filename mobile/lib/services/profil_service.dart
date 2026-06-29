import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/utilisateur.dart';
import 'api_client.dart';
import 'secure_storage_service.dart';

/// Lecture/écriture du profil et des préférences de l'utilisateur connecté.
class ProfilService {
  ProfilService._();
  static final ProfilService instance = ProfilService._();

  final _dio = ApiClient.instance.dio;
  final _storage = SecureStorageService.instance;

  /// Profil mis en cache localement, affichable immédiatement au démarrage
  /// avant la réponse réseau (évite un écran vide pendant le chargement).
  Future<Utilisateur> chargerProfilEnCache() async {
    final cache = await _storage.lireProfilEnCache();
    final nomComplet = cache['nom'] ?? '';
    final espace = nomComplet.indexOf(' ');
    return Utilisateur(
      prenom: espace == -1 ? nomComplet : nomComplet.substring(0, espace),
      nom: espace == -1 ? '' : nomComplet.substring(espace + 1),
      role: cache['role'] ?? '',
      email: cache['email'] ?? '',
      telephone: cache['telephone'] ?? '',
      qrCode: cache['qrCode'] ?? '',
      photoProfil: cache['photo'] ?? '',
      langueInterface: 'fr',
      modeSombre: false,
      preferencesNotifications: const PreferencesNotifications(),
    );
  }

  /// Récupère le profil à jour depuis l'API et met à jour le cache local.
  Future<Utilisateur> chargerProfil() async {
    final rep = await _dio.get('/personnel/me/');
    final data = rep.data as Map<String, dynamic>;
    final utilisateur = Utilisateur.fromJson(data);

    await _storage.sauvegarderProfilEnCache(
      nom: utilisateur.nomComplet,
      role: utilisateur.role,
      email: utilisateur.email,
    );

    if (kDebugMode) {
      debugPrint("Wam's: profil chargé (${utilisateur.role})");
    }
    return utilisateur;
  }

  Future<void> sauvegarderPreferences({
    required String langueInterface,
    required bool modeSombre,
    required PreferencesNotifications preferences,
  }) async {
    await _dio.patch('/personnel/me/preferences/', data: {
      'langue_interface': langueInterface,
      'mode_sombre': modeSombre,
      'preferences_notifications': preferences.toJson(),
    });
  }

  /// Met à jour les informations d'identité (nom, email, téléphone).
  Future<Utilisateur> mettreAJourIdentite({
    required String prenom,
    required String nom,
    required String email,
    required String telephone,
  }) async {
    final rep = await _dio.patch('/personnel/me/preferences/', data: {
      'first_name': prenom,
      'last_name': nom,
      'email': email,
      'telephone': telephone,
    });
    return Utilisateur.fromJson(rep.data as Map<String, dynamic>);
  }

  /// Téléverse une nouvelle photo de profil et retourne son URL.
  Future<String> uploaderPhotoProfil(File image) async {
    final formData = FormData.fromMap({
      'photo_profil': await MultipartFile.fromFile(image.path),
    });
    final rep = await _dio.patch('/personnel/me/preferences/', data: formData);
    final data = rep.data as Map<String, dynamic>;
    return (data['photo_profil'] ?? '').toString();
  }

  /// Change le mot de passe de l'utilisateur connecté (vérifie l'ancien).
  ///
  /// Lance une [Exception] avec un message lisible si l'ancien mot de
  /// passe est incorrect ou si le nouveau ne respecte pas les règles de
  /// sécurité du backend.
  Future<void> changerMotDePasse({
    required String ancien,
    required String nouveau,
  }) async {
    try {
      await _dio.post('/personnel/me/mot-de-passe/', data: {
        'ancien_mot_de_passe': ancien,
        'nouveau_mot_de_passe': nouveau,
      });
    } on DioException catch (e) {
      final detail = e.response?.data is Map ? (e.response?.data as Map)['detail'] : null;
      throw Exception(detail?.toString() ?? 'Échec du changement de mot de passe.');
    }
  }
}
