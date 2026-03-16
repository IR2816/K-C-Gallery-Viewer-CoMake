import 'package:flutter/material.dart';

/// AppTheme — Social Media Style Design System
///
/// Primary: Indigo-Purple (#6C63FF)
/// Accent: Rose (#FF2D55)
/// Secondary: Teal (#00C6AE)
/// Dark bg: Near-black (#0A0A0F)
class AppTheme {
  // ═══════════════════════════════════════════════
  // BRAND COLORS
  // ═══════════════════════════════════════════════
  static const Color primaryColor = Color(0xFF6366F1); // More vibrant Indigo
  static const Color primaryDarkColor = Color(
    0xFF6200EA,
  ); // Deeper vibrant purple
  static const Color primaryLightColor = Color(
    0xFFB388FF,
  ); // Lighter vibrant lavender
  static const Color accentColor = Color(0xFFF43F5E); // More vibrant Rose
  static const Color secondaryAccent = Color(0xFF06B6D4); // Brighter Teal

  // ═══════════════════════════════════════════════
  // DARK THEME SURFACES
  // ═══════════════════════════════════════════════
  static const Color darkBackgroundColor = Color(0xFF050508);
  static const Color darkSurfaceColor = Color(0xFF0D0D14);
  static const Color darkCardColor = Color(0xFF151522);
  static const Color darkElevatedSurfaceColor = Color(0xFF252538);
  static const Color darkBorderColor = Color(0xFF232336);

  // ═══════════════════════════════════════════════
  // LIGHT THEME SURFACES
  // ═══════════════════════════════════════════════
  static const Color lightBackgroundColor = Color(0xFFFAF9FF);
  static const Color lightSurfaceColor = Color(0xFFFFFFFF);
  static const Color lightCardColor = Color(0xFFFEFDFF);
  static const Color lightElevatedSurfaceColor = Color(0xFFF3F1FF);
  static const Color lightBorderColor = Color(0xFFE2DFFF);

  // ═══════════════════════════════════════════════
  // DARK TEXT COLORS
  // ═══════════════════════════════════════════════
  static const Color darkPrimaryTextColor = Color(0xFFFFFFFF);
  static const Color darkSecondaryTextColor = Color(0xFF9898B0);
  static const Color darkDisabledTextColor = Color(0xFF55556A);
  static const Color darkHintTextColor = Color(0xFF6B6B80);

  // ═══════════════════════════════════════════════
  // LIGHT TEXT COLORS
  // ═══════════════════════════════════════════════
  static const Color lightPrimaryTextColor = Color(0xFF0D0D1A);
  static const Color lightSecondaryTextColor = Color(0xFF6B6B80);
  static const Color lightDisabledTextColor = Color(0xFFBBBBCC);
  static const Color lightHintTextColor = Color(0xFF9898B0);

  // ═══════════════════════════════════════════════
  // BACKWARD COMPAT (default = dark)
  // ═══════════════════════════════════════════════
  static const Color primaryTextColor = darkPrimaryTextColor;
  static const Color secondaryTextColor = darkSecondaryTextColor;
  static const Color backgroundColor = darkBackgroundColor;
  static const Color surfaceColor = darkSurfaceColor;
  static const Color cardColor = darkCardColor;
  static const TextStyle captionStyle = darkCaptionStyle;
  static const TextStyle bodyStyle = darkBodyStyle;
  static const TextStyle titleStyle = darkTitleStyle;
  static const TextStyle subtitleStyle = darkSubtitleStyle;
  static const TextStyle heading1Style = darkHeading1Style;
  static const TextStyle heading2Style = darkHeading2Style;
  static const TextStyle heading3Style = darkHeading3Style;
  static const TextStyle buttonTextStyle = darkButtonTextStyle;
  static const TextStyle tabTextStyle = darkTabTextStyle;

  // ═══════════════════════════════════════════════
  // STATUS COLORS
  // ═══════════════════════════════════════════════
  static const Color successColor = Color(0xFF00C6AE);
  static const Color warningColor = Color(0xFFFFB300);
  static const Color errorColor = Color(0xFFFF2D55);
  static const Color infoColor = Color(0xFF6C63FF);

  // ═══════════════════════════════════════════════
  // SERVICE COLORS
  // ═══════════════════════════════════════════════
  static const Map<String, Color> serviceColors = {
    'fanbox': Color(0xFF0099E5),
    'patreon': Color(0xFFFF424D),
    'fantia': Color(0xFF845EC2),
    'afdian': Color(0xFF1DB954),
    'boosty': Color(0xFFFF6B35),
    'kemono': Color(0xFF6C63FF),
    'coomer': Color(0xFFFF2D55),
    'onlyfans': Color(0xFF00AFF0),
    'fansly': Color(0xFF1A9BE0),
    'candfans': Color(0xFFFF79A8),
    'gumroad': Color(0xFF36A9AE),
    'subscribestar': Color(0xFF00B4D8),
    'dlsite': Color(0xFF6C2BD9),
    'discord': Color(0xFF5865F2),
  };

  // ═══════════════════════════════════════════════
  // GRADIENTS
  // ═══════════════════════════════════════════════
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryColor, Color(0xFF9C27B0)], // Indigo to Purple
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentColor, Color(0xFFFF5252)],
  );

  static const LinearGradient storyRingGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryColor, accentColor, Color(0xFFFFD740)],
  );

  static const LinearGradient navBarGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryColor, Color(0xFFD500F9)],
  );

  static const LinearGradient darkBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [darkBackgroundColor, Color(0xFF12121A)],
  );

  static const LinearGradient lightBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [lightBackgroundColor, Color(0xFFFDFDFF)],
  );

  static const LinearGradient cardOverlayGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.transparent, Color(0xAA000000), Color(0xEE000000)],
  );

  // GLASSMORPHISM
  static BoxDecoration glassDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark
          ? Colors.black.withValues(alpha: 0.3)
          : Colors.white.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(mdRadius),
      border: Border.all(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
        width: 0.5,
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // DARK TEXT STYLES
  // ═══════════════════════════════════════════════
  static const TextStyle darkHeading1Style = TextStyle(
    color: darkPrimaryTextColor,
    fontSize: 32,
    fontWeight: FontWeight.w800,
    height: 1.2,
    letterSpacing: -0.5,
  );

  static const TextStyle darkHeading2Style = TextStyle(
    color: darkPrimaryTextColor,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.3,
  );

  static const TextStyle darkHeading3Style = TextStyle(
    color: darkPrimaryTextColor,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: -0.2,
  );

  static const TextStyle darkTitleStyle = TextStyle(
    color: darkPrimaryTextColor,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static const TextStyle darkSubtitleStyle = TextStyle(
    color: darkPrimaryTextColor,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  static const TextStyle darkBodyStyle = TextStyle(
    color: darkPrimaryTextColor,
    fontSize: 14,
    fontWeight: FontWeight.normal,
    height: 1.5,
  );

  static const TextStyle darkCaptionStyle = TextStyle(
    color: darkSecondaryTextColor,
    fontSize: 12,
    fontWeight: FontWeight.normal,
    height: 1.4,
  );

  static const TextStyle darkButtonTextStyle = TextStyle(
    color: darkPrimaryTextColor,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  static const TextStyle darkTabTextStyle = TextStyle(
    color: darkSecondaryTextColor,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.2,
  );

  // ═══════════════════════════════════════════════
  // LIGHT TEXT STYLES
  // ═══════════════════════════════════════════════
  static const TextStyle lightHeading1Style = TextStyle(
    color: lightPrimaryTextColor,
    fontSize: 32,
    fontWeight: FontWeight.w800,
    height: 1.2,
    letterSpacing: -0.5,
  );

  static const TextStyle lightHeading2Style = TextStyle(
    color: lightPrimaryTextColor,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.3,
  );

  static const TextStyle lightHeading3Style = TextStyle(
    color: lightPrimaryTextColor,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: -0.2,
  );

  static const TextStyle lightTitleStyle = TextStyle(
    color: lightPrimaryTextColor,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static const TextStyle lightSubtitleStyle = TextStyle(
    color: lightPrimaryTextColor,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  static const TextStyle lightBodyStyle = TextStyle(
    color: lightPrimaryTextColor,
    fontSize: 14,
    fontWeight: FontWeight.normal,
    height: 1.5,
  );

  static const TextStyle lightCaptionStyle = TextStyle(
    color: lightSecondaryTextColor,
    fontSize: 12,
    fontWeight: FontWeight.normal,
    height: 1.4,
  );

  static const TextStyle lightButtonTextStyle = TextStyle(
    color: lightPrimaryTextColor,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  static const TextStyle lightTabTextStyle = TextStyle(
    color: lightSecondaryTextColor,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.2,
  );

  // ═══════════════════════════════════════════════
  // SPACING & SIZING
  // ═══════════════════════════════════════════════
  static const double xsPadding = 4.0;
  static const double smPadding = 8.0;
  static const double mdPadding = 16.0;
  static const double lgPadding = 24.0;
  static const double xlPadding = 32.0;

  static const double xsSpacing = 4.0;
  static const double smSpacing = 8.0;
  static const double mdSpacing = 16.0;
  static const double lgSpacing = 24.0;
  static const double xlSpacing = 32.0;

  // Border radius
  static const double xsRadius = 4.0;
  static const double smRadius = 8.0;
  static const double mdRadius = 16.0;
  static const double lgRadius = 24.0;
  static const double xlRadius = 32.0;
  static const double pillRadius = 50.0;

  // Elevations
  static const double noElevation = 0.0;
  static const double smElevation = 2.0;
  static const double mdElevation = 8.0;
  static const double lgElevation = 16.0;

  // Animation durations
  static const Duration fastDuration = Duration(milliseconds: 150);
  static const Duration normalDuration = Duration(milliseconds: 300);
  static const Duration slowDuration = Duration(milliseconds: 500);

  // ═══════════════════════════════════════════════
  // THEME DATA
  // ═══════════════════════════════════════════════
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: accentColor,
        tertiary: secondaryAccent,
        surface: darkSurfaceColor,
        error: errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: darkPrimaryTextColor,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: darkBackgroundColor,

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: darkPrimaryTextColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: darkHeading3Style,
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
          side: BorderSide(color: darkBorderColor, width: 1),
        ),
        color: darkCardColor,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: lgPadding,
            vertical: smPadding + 4,
          ),
          textStyle: darkButtonTextStyle,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(smRadius)),
          ),
          textStyle: darkButtonTextStyle,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkCardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide(color: darkBorderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide(color: darkBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        hintStyle: darkCaptionStyle,
        labelStyle: darkCaptionStyle,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: mdPadding,
          vertical: smPadding + 4,
        ),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkSurfaceColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: darkSecondaryTextColor,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: darkTabTextStyle,
        unselectedLabelStyle: darkTabTextStyle,
      ),

      tabBarTheme: const TabBarThemeData(
        labelColor: primaryColor,
        unselectedLabelColor: darkSecondaryTextColor,
        indicatorColor: primaryColor,
        labelStyle: darkTabTextStyle,
        unselectedLabelStyle: darkTabTextStyle,
      ),

      iconTheme: const IconThemeData(color: darkSecondaryTextColor, size: 24),

      dividerTheme: const DividerThemeData(
        color: darkBorderColor,
        thickness: 1,
        space: 1,
      ),

      textTheme: const TextTheme(
        displayLarge: darkHeading1Style,
        displayMedium: darkHeading2Style,
        displaySmall: darkHeading3Style,
        headlineLarge: darkTitleStyle,
        headlineMedium: darkSubtitleStyle,
        bodyLarge: darkBodyStyle,
        bodyMedium: darkBodyStyle,
        bodySmall: darkCaptionStyle,
        labelLarge: darkButtonTextStyle,
        labelMedium: darkButtonTextStyle,
        labelSmall: darkCaptionStyle,
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: accentColor,
        tertiary: secondaryAccent,
        surface: lightSurfaceColor,
        error: errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: lightPrimaryTextColor,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: lightBackgroundColor,

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: lightPrimaryTextColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: lightHeading3Style,
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
          side: BorderSide(color: lightBorderColor, width: 1),
        ),
        color: lightCardColor,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: lgPadding,
            vertical: smPadding + 4,
          ),
          textStyle: lightButtonTextStyle,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(smRadius)),
          ),
          textStyle: lightButtonTextStyle,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide(color: lightBorderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide(color: lightBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        hintStyle: lightCaptionStyle,
        labelStyle: lightCaptionStyle,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: mdPadding,
          vertical: smPadding + 4,
        ),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: lightSurfaceColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: lightSecondaryTextColor,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: lightTabTextStyle,
        unselectedLabelStyle: lightTabTextStyle,
      ),

      tabBarTheme: const TabBarThemeData(
        labelColor: primaryColor,
        unselectedLabelColor: lightSecondaryTextColor,
        indicatorColor: primaryColor,
        labelStyle: lightTabTextStyle,
        unselectedLabelStyle: lightTabTextStyle,
      ),

      iconTheme: const IconThemeData(color: lightSecondaryTextColor, size: 24),

      dividerTheme: const DividerThemeData(
        color: lightBorderColor,
        thickness: 1,
        space: 1,
      ),

      textTheme: const TextTheme(
        displayLarge: lightHeading1Style,
        displayMedium: lightHeading2Style,
        displaySmall: lightHeading3Style,
        headlineLarge: lightTitleStyle,
        headlineMedium: lightSubtitleStyle,
        bodyLarge: lightBodyStyle,
        bodyMedium: lightBodyStyle,
        bodySmall: lightCaptionStyle,
        labelLarge: lightButtonTextStyle,
        labelMedium: lightButtonTextStyle,
        labelSmall: lightCaptionStyle,
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // HELPER METHODS
  // ═══════════════════════════════════════════════
  static Color getServiceColor(String service) {
    return serviceColors[service.toLowerCase()] ?? primaryColor;
  }

  static Color getSurfaceColor(BuildContext context) {
    return Theme.of(context).colorScheme.surface;
  }

  static Color getCardColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkCardColor
        : lightCardColor;
  }

  static Color getElevatedSurfaceColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkElevatedSurfaceColor
        : lightElevatedSurfaceColor;
  }

  static Color getOnSurfaceColor(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface;
  }

  static Color getBackgroundColor(BuildContext context) {
    return Theme.of(context).scaffoldBackgroundColor;
  }

  static Color getOnBackgroundColor(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface;
  }

  static Color getPrimaryColor(BuildContext context) {
    return Theme.of(context).colorScheme.primary;
  }

  static Color getPrimaryTextColor(BuildContext context, {double opacity = 1}) {
    final base = Theme.of(context).brightness == Brightness.dark
        ? darkPrimaryTextColor
        : lightPrimaryTextColor;
    return base.withValues(alpha: opacity);
  }

  static Color getSecondaryTextColor(
    BuildContext context, {
    double opacity = 1,
  }) {
    final base = Theme.of(context).brightness == Brightness.dark
        ? darkSecondaryTextColor
        : lightSecondaryTextColor;
    return base.withValues(alpha: opacity);
  }

  static Color getBorderColor(BuildContext context, {double opacity = 1}) {
    final base = Theme.of(context).brightness == Brightness.dark
        ? darkBorderColor
        : lightBorderColor;
    return base.withValues(alpha: opacity);
  }

  static LinearGradient getBackgroundGradient(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkBackgroundGradient
        : lightBackgroundGradient;
  }

  static double getBottomContentPadding(
    BuildContext context, {
    double extra = 24,
  }) {
    return MediaQuery.paddingOf(context).bottom + 82 + 10 + extra;
  }

  static Color getShadowColor(BuildContext context, {double opacity = 0.1}) {
    return Theme.of(context).shadowColor.withValues(alpha: opacity);
  }

  static Color getDividerColor(BuildContext context) {
    return Theme.of(context).dividerColor;
  }

  static Color getErrorColor(BuildContext context) {
    return Theme.of(context).colorScheme.error;
  }

  static Color getOnSurfaceWithOpacity(BuildContext context, double opacity) {
    return Theme.of(context).colorScheme.onSurface.withValues(alpha: opacity);
  }

  static Color getSurfaceVariant(BuildContext context) {
    return Theme.of(context).colorScheme.surfaceContainerHighest;
  }

  static bool isLightColor(Color color) {
    return color.computeLuminance() > 0.5;
  }

  static Color getContrastColor(Color backgroundColor) {
    return isLightColor(backgroundColor) ? Colors.black : Colors.white;
  }

  // Dynamic text styles
  static TextStyle getTitleStyle(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkTitleStyle
        : lightTitleStyle;
  }

  static TextStyle getBodyStyle(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkBodyStyle
        : lightBodyStyle;
  }

  static TextStyle getCaptionStyle(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkCaptionStyle
        : lightCaptionStyle;
  }

  static TextStyle getSubtitleStyle(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkSubtitleStyle
        : lightSubtitleStyle;
  }

  static TextStyle getButtonTextStyle(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkButtonTextStyle
        : lightButtonTextStyle;
  }

  static LinearGradient getCardGradient() {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [darkCardColor, darkElevatedSurfaceColor],
    );
  }

  static LinearGradient getLightCardGradient() {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [lightCardColor, lightElevatedSurfaceColor],
    );
  }

  static BoxShadow getCardShadow() {
    return BoxShadow(
      color: Colors.black.withValues(alpha: 0.12),
      blurRadius: 24,
      offset: const Offset(0, 8),
    );
  }

  static BoxShadow getElevatedShadow() {
    return BoxShadow(
      color: primaryColor.withValues(alpha: 0.20),
      blurRadius: 32,
      offset: const Offset(0, 12),
    );
  }

  static BoxShadow getGlowShadow(Color color) {
    return BoxShadow(
      color: color.withValues(alpha: 0.35),
      blurRadius: 20,
      spreadRadius: -4,
      offset: const Offset(0, 4),
    );
  }

  /// Get card gradient based on current theme
  static LinearGradient getContextCardGradient(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? getCardGradient()
        : getLightCardGradient();
  }

  /// Get icon color for current theme
  static Color getIconColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkSecondaryTextColor
        : lightSecondaryTextColor;
  }

  /// Get elevated surface color that respects theme brightness
  static Color getElevatedSurfaceColorContext(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkElevatedSurfaceColor
        : lightElevatedSurfaceColor;
  }

  /// Get surface color with brightness awareness
  static Color getSurfaceColorContext(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkSurfaceColor
        : lightSurfaceColor;
  }

  /// Get appropriate shadow for light or dark theme
  static BoxShadow getThemeAwareShadow(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxShadow(
      color: isDark
          ? Colors.black.withValues(alpha: 0.2)
          : Colors.black.withValues(alpha: 0.08),
      blurRadius: 12,
      offset: const Offset(0, 4),
    );
  }
}
