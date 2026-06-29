// Ouvre un PDF (octets déjà téléchargés via le client HTTP authentifié)
// selon la plateforme : fichier temporaire + lecteur PDF du système sur
// mobile/desktop, onglet navigateur (Blob) sur Flutter Web — `dart:io` et
// `open_filex` n'existent pas sur le web, d'où cette implémentation
// conditionnelle.
export 'pdf_downloader_io.dart' if (dart.library.html) 'pdf_downloader_web.dart';
