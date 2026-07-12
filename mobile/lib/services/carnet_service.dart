import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/carnet_scan_result.dart';
import 'api_client.dart';

/// Service de numérisation des carnets patients physiques.
///
/// Enchaîne trois responsabilités :
/// 1. OCR via google_mlkit_text_recognition sur l'image capturée
/// 2. Parsing du texte brut pour extraire les champs structurés
/// 3. Envoi au backend via POST /patients/importer-carnet/
class CarnetService {
  CarnetService._();
  static final CarnetService instance = CarnetService._();

  final _dio = ApiClient.instance.dio;

  /// Analyse [imageFile] avec MLKit et retourne les champs extraits.
  Future<CarnetScanResult> analyserCarnet(File imageFile) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final result = await recognizer.processImage(inputImage);
      return _parseTexte(result.text);
    } finally {
      recognizer.close();
    }
  }

  /// Envoie les données extraites (et complétées) au backend.
  Future<Map<String, dynamic>> importerPatient(Map<String, String> donnees) async {
    final rep = await _dio.post('/patients/importer-carnet/', data: donnees);
    return rep.data as Map<String, dynamic>;
  }

  // ---------------------------------------------------------------------------
  // Parsing
  // ---------------------------------------------------------------------------

  CarnetScanResult _parseTexte(String texte) {
    final extraits = <String, String>{};

    // ── NOM ──────────────────────────────────────────────────────────────────
    // Gère "NOM : EWANE" dans une ligne de tableau all-caps.
    // S'arrête sur le prochain label connu (3+ espaces + majuscule ou retour ligne).
    final nomM = RegExp(
      r'\bNOM\s*[:\-]\s*([A-ZÀ-Ÿa-zà-ÿ][A-ZÀ-Ÿa-zà-ÿ\-]{0,29}'
      r'(?:\s+[A-ZÀ-Ÿ][A-ZÀ-Ÿa-zà-ÿ\-]{1,20})?)',
      caseSensitive: false,
    ).firstMatch(texte);
    if (nomM != null) {
      final v = nomM.group(1)!.trim();
      if (v.length >= 2) extraits[ChampsCarnet.nom] = v;
    }

    // ── PRÉNOM ───────────────────────────────────────────────────────────────
    // Gère PRÉNOM, PRENOM, PRÉNOM(S), PRENOM(S).
    // S'arrête dès qu'il y a 3+ espaces (séparation de colonne MLKit) ou retour ligne.
    final prenomM = RegExp(
      r'\bPR[EÉ]NOM\(?S?\)?\s*[:\-]\s*'
      r'([A-ZÀ-Ÿa-zà-ÿ][A-ZÀ-Ÿa-zà-ÿ\s\-]{0,39}?)'
      r'(?=\s{3,}[A-ZÀÂÉÈÊËÎÏÔÙÛÜ]|\n|$)',
      caseSensitive: false,
    ).firstMatch(texte);
    if (prenomM != null) {
      final v = prenomM.group(1)!.trim();
      if (v.length >= 2) extraits[ChampsCarnet.prenom] = v;
    }

    // ── DATE DE NAISSANCE ────────────────────────────────────────────────────
    // Gère "DATE DE NAISSANCE :" (all-caps) et "Né(e) le" dans tous les formats.
    final dateM = RegExp(
      r'(?:DATE\s+DE\s+NAISSANCE|N[EÉ]E?\s+LE)\s*[:\-]?\s*'
      r'(\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{4})',
      caseSensitive: false,
    ).firstMatch(texte);
    if (dateM != null) {
      final raw = dateM.group(1)!;
      final parts = raw.split(RegExp(r'[\/\-\.]'));
      if (parts.length == 3) {
        // DD/MM/YYYY → YYYY-MM-DD (format Django)
        extraits[ChampsCarnet.dateNaissance] =
            '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
      }
    }

    // ── SEXE ──────────────────────────────────────────────────────────────────
    // "SEXE : M ☑ M ☐ F" → capture le premier M ou F après le label.
    // Les symboles de case à cocher (☑ ☐ ✓) sont ignorés naturellement.
    final sexeM = RegExp(
      r'\bSEXE\s*[:\-]\s*(M(?:asculin)?|F(?:[eé]minin)?)',
      caseSensitive: false,
    ).firstMatch(texte);
    if (sexeM != null) {
      final s = sexeM.group(1)!.toUpperCase();
      extraits[ChampsCarnet.sexe] = s.startsWith('F') ? 'F' : 'M';
    }

    // ── TÉLÉPHONE ────────────────────────────────────────────────────────────
    // Le label est optionnel (le numéro peut apparaître sans contexte de label).
    // Priorité au numéro précédé du label TÉLÉPHONE / TÉL.
    final telLabelM = RegExp(
      r'T[EÉ]L(?:[EÉ]PHONE?)?\s*[:\-]\s*'
      r'(\+?(?:237|33|229|225|221|228|226|223|224|227)\s?\d[\d\s]{5,13}|\b0\d{9}\b)',
      caseSensitive: false,
    ).firstMatch(texte);
    if (telLabelM != null) {
      final tel = telLabelM.group(1)!.replaceAll(RegExp(r'\s'), '');
      if (tel.length >= 8) extraits[ChampsCarnet.telephone] = tel;
    } else {
      // Fallback : cherche un numéro international sans label
      final telM = RegExp(
        r'(\+?(?:237|33|229|225|221|228|226|223|224|227)\s?\d[\d\s]{5,13})',
      ).firstMatch(texte);
      if (telM != null) {
        final tel = telM.group(1)!.replaceAll(RegExp(r'\s'), '');
        if (tel.length >= 8) extraits[ChampsCarnet.telephone] = tel;
      }
    }

    // ── EMAIL ─────────────────────────────────────────────────────────────────
    final emailM = RegExp(r'[\w.\-]+@[\w.\-]+\.\w{2,}').firstMatch(texte);
    if (emailM != null) extraits[ChampsCarnet.email] = emailM.group(0)!;

    // ── GROUPE SANGUIN ────────────────────────────────────────────────────────
    final gsM = RegExp(r'\b(AB[+\-]|A[+\-]|B[+\-]|O[+\-])\b').firstMatch(texte);
    if (gsM != null) extraits[ChampsCarnet.groupeSanguin] = gsM.group(0)!;

    // ── ADRESSE ───────────────────────────────────────────────────────────────
    // S'arrête à 3+ espaces (séparation colonne) ou retour ligne.
    final adrM = RegExp(
      r'\bADRESSE\s*[:\-]\s*(.{5,80}?)(?=\s{3,}[A-ZÀÂÉ]|\n[A-ZÀÂÉ]|\n\n|$)',
      caseSensitive: false,
      dotAll: false,
    ).firstMatch(texte);
    if (adrM != null) {
      final v = adrM.group(1)!.trim();
      if (v.length > 4) extraits[ChampsCarnet.adresse] = v;
    }

    // ── ALLERGIES ─────────────────────────────────────────────────────────────
    final allerM = RegExp(
      r'\bALLERGIES?\s*[:\-]\s*(.{2,120}?)(?=\s{3,}[A-ZÀÂÉ]|\n[A-ZÀÂÉ]|\n\n|$)',
      caseSensitive: false,
      dotAll: false,
    ).firstMatch(texte);
    if (allerM != null) {
      final v = allerM.group(1)!.trim();
      if (v.isNotEmpty &&
          !RegExp(r'^(?:aucune?|n[eéè]ant|RAS|\/|-)$', caseSensitive: false)
              .hasMatch(v)) {
        extraits[ChampsCarnet.allergies] = v;
      }
    }

    final manquants = ChampsCarnet.tous
        .where((c) => !extraits.containsKey(c))
        .toList();

    return CarnetScanResult(
      champsExtraits: extraits,
      champsManquants: manquants,
      texteOcr: texte,
    );
  }
}
