import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Thème WARMS Mobile - Palette turquoise "cabinet dentaire"
///
/// Ce thème centralise les couleurs, polices et styles de l'app mobile.
/// Tous les écrans/widgets de l'app référencent ces constantes (jamais de
/// couleur codée en dur) : changer une valeur ici suffit à retinter
/// l'application entière de façon cohérente.
///
/// Palette principale (turquoise/cyan, alignée sur la maquette de référence) :
/// --warms-navy   (texte foncé / titres)   : #0B2B2E
/// --warms-blue   (teal foncé, dégradés)   : #0E6E76
/// --warms-accent (teal principal, CTA)    : #14919B
/// --warms-bg     (fond app, très clair)   : #F2FBFC
/// --warms-card   (fond des cartes)        : #FFFFFF
/// --warms-gray   (texte secondaire)       : #5C7A7D
///
/// @author WARMS Team
/// @version 3.0.0
class WarmsTheme {
  // Couleurs principales WARMS (palette turquoise)
  static const Color warmsNavy = Color(0xFF0B2B2E);
  static const Color warmsBlue = Color(0xFF0E6E76);
  static const Color warmsAccent = Color(0xFF14919B);
  static const Color warmsBg = Color(0xFFF2FBFC);
  static const Color warmsCard = Color(0xFFFFFFFF);
  static const Color warmsGray = Color(0xFF5C7A7D);

  // Couleurs secondaires
  static const Color warmsLightBlue = Color(0xFF4FD1D9);
  static const Color warmsDarkBlue = Color(0xFF0A4F55);
  static const Color warmsSuccess = Color(0xFF22C55E);
  static const Color warmsWarning = Color(0xFFFACC15);
  static const Color warmsError = Color(0xFFEF4444);
  static const Color warmsInfo = Color(0xFF14919B);

  // Couleur d'accent pour les indicateurs "favori" / notation (cohérente avec la maquette)
  static const Color warmsHeart = Color(0xFFFF5C7A);
  static const Color warmsStar = Color(0xFFFFB800);

  // Teinte claire de l'accent (remplace les anciens `Colors.blue[50/100]`
  // utilisés comme fonds de badge/chip dans les écrans IA).
  static const Color warmsAccentTint = Color(0xFFDCF1F3);

  // Couleurs mode sombre
  static const Color warmsDarkBg = Color(0xFF07232A);
  static const Color warmsDarkCard = Color(0xFF103138);
  static const Color warmsDarkGray = Color(0xFFBFEAEE);
  
  // Gradients
  static const LinearGradient warmsPrimaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      warmsAccent,
      warmsLightBlue,
    ],
  );
  
  static const LinearGradient warmsCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFFFFF),
      Color(0xFFF8FAFF),
    ],
  );
  
  static const LinearGradient warmsButtonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      warmsAccent,
      warmsBlue,
    ],
  );

  /// Dégradé "héro" utilisé sur les écrans d'accueil/onboarding/connexion
  /// (fond plein écran turquoise, du clair en haut vers le foncé en bas).
  static const LinearGradient warmsHeroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF4FD1D9),
      warmsAccent,
      warmsBlue,
    ],
  );
  
  // Thème clair
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: warmsAccent,
        secondary: warmsBlue,
        surface: warmsCard,
        surfaceContainer: warmsBg,
        error: warmsError,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: warmsGray,
        onSurfaceVariant: warmsGray,
        onError: Colors.white,
      ),
      
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: warmsNavy,
          letterSpacing: 0.8,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: warmsNavy,
          letterSpacing: 0.6,
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: warmsNavy,
          letterSpacing: 0.4,
        ),
        headlineLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: warmsNavy,
          letterSpacing: 0.4,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: warmsNavy,
          letterSpacing: 0.3,
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: warmsNavy,
          letterSpacing: 0.2,
        ),
        titleLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: warmsNavy,
          letterSpacing: 0.2,
        ),
        titleMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: warmsGray,
          letterSpacing: 0.1,
        ),
        titleSmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: warmsGray,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: warmsGray,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: warmsGray,
          height: 1.4,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: warmsGray,
          height: 1.3,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 0.3,
        ),
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 0.2,
        ),
      ),
      
      // App Bar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: warmsCard,
        foregroundColor: warmsNavy,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: warmsNavy,
          letterSpacing: 0.4,
        ),
        iconTheme: IconThemeData(
          color: warmsNavy,
          size: 24,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),
      
      // Card Theme
      cardTheme: CardThemeData(
        color: warmsCard,
        elevation: 10,
        shadowColor: warmsBlue.withValues(alpha: 0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      
      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: warmsAccent,
          foregroundColor: Colors.white,
          elevation: 8,
          shadowColor: warmsBlue.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      
      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: warmsAccent,
          side: const BorderSide(color: warmsAccent, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      
      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: warmsAccent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      
      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: warmsCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: warmsBlue.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: warmsBlue.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: warmsAccent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: warmsError, width: 2),
        ),
        labelStyle: const TextStyle(
          color: warmsGray,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: TextStyle(
          color: warmsGray.withOpacity(0.6),
          fontWeight: FontWeight.w400,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      
      // Floating Action Button Theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: warmsAccent,
        foregroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      
      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: warmsCard,
        selectedItemColor: warmsAccent,
        unselectedItemColor: warmsGray,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),
      
      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: warmsBg,
        selectedColor: warmsAccent,
        disabledColor: warmsGray.withOpacity(0.2),
        labelStyle: const TextStyle(
          color: warmsGray,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      
      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: warmsCard,
        elevation: 20,
        shadowColor: warmsBlue.withValues(alpha: 0.25),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: warmsNavy,
        ),
        contentTextStyle: const TextStyle(
          fontSize: 16,
          color: warmsGray,
          height: 1.5,
        ),
      ),
      
      // Switch Theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return warmsAccent;
          }
          return warmsGray.withValues(alpha: 0.4);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return warmsAccent.withValues(alpha: 0.3);
          }
          return warmsGray.withValues(alpha: 0.2);
        }),
      ),
      
      // Slider Theme
      sliderTheme: SliderThemeData(
        activeTrackColor: warmsAccent,
        inactiveTrackColor: warmsBg,
        thumbColor: warmsAccent,
        overlayColor: warmsAccent.withValues(alpha: 0.2),
        valueIndicatorColor: warmsAccent,
        valueIndicatorTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      
      // Progress Indicator Theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: warmsAccent,
        linearTrackColor: warmsBg,
        circularTrackColor: warmsBg,
      ),
      
      // Tooltip Theme
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: warmsNavy,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        textStyle: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
  
  // Thème sombre
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: warmsAccent,
        secondary: warmsLightBlue,
        surface: warmsDarkCard,
        surfaceContainer: warmsDarkBg,
        error: warmsError,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: warmsDarkGray,
        onSurfaceVariant: warmsDarkGray,
        onError: Colors.white,
      ),
      
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: warmsDarkGray,
          letterSpacing: 0.8,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: warmsDarkGray,
          letterSpacing: 0.6,
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: warmsDarkGray,
          letterSpacing: 0.4,
        ),
        headlineLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: warmsDarkGray,
          letterSpacing: 0.4,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: warmsDarkGray,
          letterSpacing: 0.3,
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: warmsDarkGray,
          letterSpacing: 0.2,
        ),
        titleLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: warmsDarkGray,
          letterSpacing: 0.2,
        ),
        titleMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: warmsDarkGray,
          letterSpacing: 0.1,
        ),
        titleSmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: warmsDarkGray,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: warmsDarkGray,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: warmsDarkGray,
          height: 1.4,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: warmsDarkGray,
          height: 1.3,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 0.3,
        ),
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 0.2,
        ),
      ),
      
      // App Bar Theme (sombre)
      appBarTheme: const AppBarTheme(
        backgroundColor: warmsDarkCard,
        foregroundColor: warmsDarkGray,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: warmsDarkGray,
          letterSpacing: 0.4,
        ),
        iconTheme: IconThemeData(
          color: warmsDarkGray,
          size: 24,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      
      // Card Theme (sombre)
      cardTheme: CardThemeData(
        color: warmsDarkCard,
        elevation: 10,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      
      // Les autres thèmes héritent de la structure du thème clair
      // avec des couleurs adaptées pour le mode sombre
    );
  }
}

/// Widget pour les animations WARMS
class WarmsAnimations {
  static const Duration shortDuration = Duration(milliseconds: 250);
  static const Duration mediumDuration = Duration(milliseconds: 300);
  static const Duration longDuration = Duration(milliseconds: 500);
  
  // Animation de flottement (comme les bulles dans l'app web)
  static Animation<double> floatingAnimation(AnimationController controller) {
    return Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOut,
    ));
  }
  
  // Animation de pulsation
  static Animation<double> pulseAnimation(AnimationController controller) {
    return Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOut,
    ));
  }
  
  // Animation de rotation (comme le diamant dans l'app web)
  static Animation<double> rotationAnimation(AnimationController controller) {
    return Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.linear,
    ));
  }
  
  // Animation de glissement vers le haut
  static Animation<Offset> slideUpAnimation(AnimationController controller) {
    return Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.easeOutBack,
    ));
  }
  
  // Animation de fondu
  static Animation<double> fadeInAnimation(AnimationController controller) {
    return Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOut,
    ));
  }
}
