import 'package:flutter/material.dart';

/// Cassia Bakery ERP – central design tokens & Material 3 theme.
class AppTheme {
  AppTheme._();

  // ── Brand colours ──────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF1A3CDB);   // deep royal blue (FAB)
  static const Color surface = Color(0xFFF5F5F5);   // light grey background
  static const Color cardBg  = Color(0xFFEEEEEE);   // card fill
  static const Color textDark = Color(0xFF1A1A1A);
  static const Color textMid  = Color(0xFF555555);
  static const Color textSub  = Color(0xFF888888);
  static const Color divider  = Color(0xFFDDDDDD);
  static const Color positive = Color(0xFF2E7D32);  // green for +growth

  // ── Typography ─────────────────────────────────────────────────────────────
  static const String _fontFamily = 'Roboto'; // default Material font

  static TextTheme get textTheme => const TextTheme(
    displayLarge : TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: textDark),
    titleLarge   : TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textDark),
    titleMedium  : TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: textDark),
    bodyLarge    : TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: textDark),
    bodyMedium   : TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: textMid),
    bodySmall    : TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: textSub),
    labelLarge   : TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textDark),
  );

  // ── Material 3 Theme ────────────────────────────────────────────────────────
  static ThemeData get light => ThemeData(
    useMaterial3 : true,
    fontFamily   : _fontFamily,
    colorScheme  : ColorScheme.fromSeed(
      seedColor     : primary,
      brightness    : Brightness.light,
      surface       : surface,
      onSurface     : textDark,
    ),
    scaffoldBackgroundColor : Colors.white,
    textTheme               : textTheme,
    appBarTheme : const AppBarTheme(
      backgroundColor     : Colors.white,
      elevation           : 0,
      centerTitle         : true,
      iconTheme           : IconThemeData(color: textDark),
      titleTextStyle      : TextStyle(
        fontSize   : 18,
        fontWeight : FontWeight.w600,
        color      : textDark,
        fontFamily : _fontFamily,
      ),
    ),
    cardTheme : CardThemeData(
      color        : cardBg,
      elevation    : 0,
      shape        : RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
      margin       : EdgeInsets.zero,
    ),
    bottomNavigationBarTheme : const BottomNavigationBarThemeData(
      backgroundColor : Colors.white,
      selectedItemColor   : primary,
      unselectedItemColor : textMid,
      showSelectedLabels  : true,
      showUnselectedLabels: true,
      type : BottomNavigationBarType.fixed,
      selectedLabelStyle  : TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: 11),
    ),
  );

  // ── Responsive Breakpoints & Helpers ────────────────────────────────────────
  static const double kMobileBreakpoint = 600.0;
  static const double kTabletBreakpoint = 850.0;

  static bool isWideScreen(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= kMobileBreakpoint;
  }

  static double getResponsivePadding(BuildContext context, {double maxContentWidth = 600.0}) {
    final screenW = MediaQuery.sizeOf(context).width;
    if (screenW > maxContentWidth) {
      return (screenW - maxContentWidth) / 2 + 16.0;
    }
    return 16.0;
  }
}
