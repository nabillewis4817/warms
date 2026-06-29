import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

/// Écrit [octets] dans un fichier temporaire puis l'ouvre avec le lecteur
/// PDF par défaut du système. Retourne un message d'erreur, ou `null` en
/// cas de succès.
Future<String?> ouvrirPdfDepuisOctets(List<int> octets, String nomFichier) async {
  final dossierTemp = await getTemporaryDirectory();
  final fichier = File('${dossierTemp.path}/$nomFichier');
  await fichier.writeAsBytes(octets, flush: true);
  final resultat = await OpenFilex.open(fichier.path);
  if (resultat.type != ResultType.done) {
    return resultat.message.isNotEmpty ? resultat.message : "Impossible d'ouvrir le PDF.";
  }
  return null;
}
