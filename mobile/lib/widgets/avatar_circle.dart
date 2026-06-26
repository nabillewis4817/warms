import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../themes/warms_theme.dart';

/// Avatar circulaire affichant la photo de profil si disponible, sinon les
/// initiales sur un fond en dégradé turquoise (cohérent avec les avatars du
/// web-administration).
class AvatarCircle extends StatelessWidget {
  final String? photoUrl;
  final String initiales;
  final double taille;

  const AvatarCircle({
    super.key,
    required this.initiales,
    this.photoUrl,
    this.taille = 44,
  });

  @override
  Widget build(BuildContext context) {
    final aPhoto = photoUrl != null && photoUrl!.isNotEmpty;

    return Container(
      width: taille,
      height: taille,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: aPhoto
            ? null
            : LinearGradient(
                colors: [WarmsTheme.warmsAccent, WarmsTheme.warmsBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        boxShadow: [
          BoxShadow(
            color: WarmsTheme.warmsBlue.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: aPhoto
          ? CachedNetworkImage(
              imageUrl: photoUrl!,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _initialesCentrees(),
            )
          : _initialesCentrees(),
    );
  }

  Widget _initialesCentrees() {
    return Center(
      child: Text(
        initiales,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: taille * 0.36,
        ),
      ),
    );
  }
}
