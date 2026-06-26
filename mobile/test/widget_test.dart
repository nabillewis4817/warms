// Test de fumée : vérifie que l'application démarre sans exception et
// affiche directement l'écran de connexion, sans écran de chargement
// intermédiaire.

import 'package:flutter_test/flutter_test.dart';

import 'package:warms_mobile/app.dart';
import 'package:warms_mobile/screens/auth/login_screen.dart';

void main() {
  testWidgets("WARMS démarre directement sur l'écran de connexion", (WidgetTester tester) async {
    await tester.pumpWidget(const WarmsApp());
    await tester.pump();

    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
