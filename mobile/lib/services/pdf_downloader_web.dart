import 'dart:html' as html;
import 'dart:typed_data';

/// Ouvre [octets] dans un nouvel onglet du navigateur via une URL Blob —
/// `dart:io`/`open_filex` ne fonctionnent pas sur Flutter Web (pas d'accès
/// au système de fichiers). Retourne toujours `null` (succès) : un
/// éventuel blocage de popup est géré par le navigateur lui-même.
Future<String?> ouvrirPdfDepuisOctets(List<int> octets, String nomFichier) async {
  final blob = html.Blob([Uint8List.fromList(octets)], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.window.open(url, '_blank');
  Future.delayed(const Duration(minutes: 1), () => html.Url.revokeObjectUrl(url));
  return null;
}
