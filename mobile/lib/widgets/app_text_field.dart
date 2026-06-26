import 'package:flutter/material.dart';

import '../themes/warms_theme.dart';

/// Champ de saisie arrondi au style WARMS (fond clair, icône préfixe,
/// option d'affichage/masquage pour les mots de passe).
class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icone;
  final bool motDePasse;
  final bool motDePasseVisible;
  final VoidCallback? onToggleVisibilite;
  final TextInputType? typeClavier;

  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icone,
    this.motDePasse = false,
    this.motDePasseVisible = false,
    this.onToggleVisibilite,
    this.typeClavier,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: motDePasse && !motDePasseVisible,
      keyboardType: typeClavier,
      style: const TextStyle(color: WarmsTheme.warmsNavy, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: WarmsTheme.warmsBg,
        prefixIcon: Icon(icone, color: WarmsTheme.warmsAccent),
        suffixIcon: motDePasse
            ? IconButton(
                icon: Icon(
                  motDePasseVisible ? Icons.visibility_off : Icons.visibility,
                  color: WarmsTheme.warmsGray,
                ),
                onPressed: onToggleVisibilite,
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: WarmsTheme.warmsAccent, width: 2),
        ),
      ),
    );
  }
}
