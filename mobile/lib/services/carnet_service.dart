import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/carnet_scan_result.dart';
import 'api_client.dart';

/// Service de numérisation des carnets patients physiques.
///
/// Enchaîne trois responsabilités :
/// 1. OCR via google_mlkit_text_recognition sur l'image capturée
/// 2. Parsing regex du texte brut pour extraire les champs structurés
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
  // Parsing regex
  // ---------------------------------------------------------------------------

  CarnetScanResult _parseTexte(String texte) {
    final extraits = <String, String>{};

    // --- NOM ---
    final nomRx = RegExp(
      r'(?:^|\n)\s*(?:NOM\s*[:\-]?\s*)([A-ZÀ-Ÿ][A-ZÀ-Ÿa-zà-ÿ\s\-]{1,40})',
      multiLine: true,
    );
    _firstMatch(nomRx, texte)?.let((v) => extraits[ChampsCarnet.nom] = v.trim());

    // --- PRÉNOM ---
    final prenomRx = RegExp(
      r'(?:^|\n)\s*(?:PR[ÉE]NOM[S]?\s*[:\-]?\s*)([A-ZÀ-Ÿa-zà-ÿ][A-ZÀ-Ÿa-zà-ÿ\s\-]{1,40})',
      multiLine: true,
      caseSensitive: false,
    );
    _firstMatch(prenomRx, texte)?.let((v) => extraits[ChampsCarnet.prenom] = v.trim());

    // --- DATE DE NAISSANCE ---
    final dateRx = RegExp(
      r'(?:N[ÉE]\([eE]\)\s+le|[Dd]ate\s+de\s+naissance\s*[:\-]?\s*|[Nn][ÉE]\s+le\s*)'
      r'(\d{2}[\/\-\.]\d{2}[\/\-\.]\d{4})',
    );
    final dateM = dateRx.firstMatch(texte);
    if (dateM != null) {
      final raw = dateM.group(1)!;
      final parts = raw.split(RegExp(r'[\/\-\.]'));
      if (parts.length == 3) {
        // DD/MM/YYYY → YYYY-MM-DD (format Django)
        extraits[ChampsCarnet.dateNaissance] =
            '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
      }
    }

    // --- SEXE ---
    final sexeRx = RegExp(
      r'[Ss]exe\s*[:\-]?\s*(M(?:asculin)?|F(?:[eé]minin)?|\bH\b)',
      caseSensitive: false,
    );
    final sexeM = sexeRx.firstMatch(texte);
    if (sexeM != null) {
      final s = sexeM.group(1)!.toUpperCase();
      if (s.startsWith('F')) {
        extraits[ChampsCarnet.sexe] = 'F';
      } else {
        extraits[ChampsCarnet.sexe] = 'M';
      }
    }

    // --- TÉLÉPHONE ---
    final telRx = RegExp(
      r'(?:[Tt][eé]l(?:[eé]phone?)?\s*[:\-]?\s*)?'
      r'(\+?(?:237|33|229|225|221|228|226|223|224|227)\s?\d[\d\s]{6,13}|\b0\d{9}\b)',
    );
    final telM = telRx.firstMatch(texte);
    if (telM != null) {
      final tel = telM.group(1)!.replaceAll(RegExp(r'\s'), '');
      if (tel.length >= 8) extraits[ChampsCarnet.telephone] = tel;
    }

    // --- EMAIL ---
    final emailRx = RegExp(r'[\w.\-]+@[\w.\-]+\.\w{2,}');
    final emailM = emailRx.firstMatch(texte);
    if (emailM != null) extraits[ChampsCarnet.email] = emailM.group(0)!;

    // --- GROUPE SANGUIN ---
    final gsRx = RegExp(r'\b(AB[+\-]|A[+\-]|B[+\-]|O[+\-])\b');
    final gsM = gsRx.firstMatch(texte);
    if (gsM != null) extraits[ChampsCarnet.groupeSanguin] = gsM.group(0)!;

    // --- ADRESSE ---
    final adrRx = RegExp(
      r'[Aa]dresse\s*[:\-]?\s*(.{5,80}?)(?=\n[A-Z]|\n\n|$)',
      dotAll: false,
    );
    _firstMatch(adrRx, texte)?.let((v) {
      final cleaned = v.trim();
      if (cleaned.length > 4) extraits[ChampsCarnet.adresse] = cleaned;
    });

    // --- ALLERGIES ---
    final allergyRx = RegExp(
      r'[Aa]llergies?\s*[:\-]?\s*(.{2,120}?)(?=\n[A-Z]|\n\n|$)',
      dotAll: false,
    );
    _firstMatch(allergyRx, texte)?.let((v) {
      final val = v.trim();
      if (val.isNotEmpty &&
          !RegExp(r'^(?:aucune?|n[eé]ant|rAS|\/|-)$', caseSensitive: false).hasMatch(val)) {
        extraits[ChampsCarnet.allergies] = val;
      }
    });

    final manquants = ChampsCarnet.tous
        .where((c) => !extraits.containsKey(c))
        .toList();

    return CarnetScanResult(champsExtraits: extraits, champsManquants: manquants);
  }

  String? _firstMatch(RegExp rx, String text) {
    final m = rx.firstMatch(text);
    return m?.groupCount != null && m!.groupCount >= 1 ? m.group(1) : null;
  }
}

extension _Let<T> on T {
  R let<R>(R Function(T) fn) => fn(this);
}
