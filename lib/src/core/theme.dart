import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Semantic color tokens for one theme preset (from design-system MASTER.md).
class EvieeTokens {
  final String id;
  final String label;
  final Color background;
  final Color card;
  final Color muted;
  final Color border;
  final Color foreground;
  final Color foreground2;
  final Color accent;
  final Color onAccent;
  final Color accentDim;
  final bool isLight;

  const EvieeTokens({
    required this.id,
    required this.label,
    required this.background,
    required this.card,
    required this.muted,
    required this.border,
    required this.foreground,
    required this.foreground2,
    required this.accent,
    required this.onAccent,
    required this.accentDim,
    this.isLight = false,
  });
}

const List<EvieeTokens> evieePresets = [
  EvieeTokens(
    id: 'ember',
    label: 'Ember',
    background: Color(0xFF0E0D0C),
    card: Color(0xFF171412),
    muted: Color(0xFF211C18),
    border: Color(0xFF2E2620),
    foreground: Color(0xFFF5F1EC),
    foreground2: Color(0xFFA89C8D),
    accent: Color(0xFFFF6B35),
    onAccent: Color(0xFF1A0B04),
    accentDim: Color(0x1AFF6B35),
  ),
  EvieeTokens(
    id: 'run-green',
    label: 'Run Green',
    background: Color(0xFF0B0C0E),
    card: Color(0xFF14161A),
    muted: Color(0xFF1B1E24),
    border: Color(0xFF262B33),
    foreground: Color(0xFFF2F4F6),
    foreground2: Color(0xFF9AA3AF),
    accent: Color(0xFF22C55E),
    onAccent: Color(0xFF06130B),
    accentDim: Color(0x1A22C55E),
  ),
  EvieeTokens(
    id: 'champagne',
    label: 'Champagne',
    background: Color(0xFF0E0D0A),
    card: Color(0xFF161410),
    muted: Color(0xFF221E15),
    border: Color(0xFF322B1D),
    foreground: Color(0xFFF4F0E6),
    foreground2: Color(0xFFA79E86),
    accent: Color(0xFFE8B84B),
    onAccent: Color(0xFF1A1204),
    accentDim: Color(0x1AE8B84B),
  ),
  EvieeTokens(
    id: 'ice',
    label: 'Ice',
    background: Color(0xFF0A0E12),
    card: Color(0xFF12171D),
    muted: Color(0xFF1A212A),
    border: Color(0xFF26303B),
    foreground: Color(0xFFEFF4F8),
    foreground2: Color(0xFF93A3B3),
    accent: Color(0xFF7DD3FC),
    onAccent: Color(0xFF06202E),
    accentDim: Color(0x1A7DD3FC),
  ),
  EvieeTokens(
    id: 'crimson',
    label: 'Crimson',
    background: Color(0xFF100C0C),
    card: Color(0xFF181214),
    muted: Color(0xFF241A1D),
    border: Color(0xFF35242A),
    foreground: Color(0xFFF6EFF0),
    foreground2: Color(0xFFA89299),
    accent: Color(0xFFFF4D5E),
    onAccent: Color(0xFF1F060A),
    accentDim: Color(0x1AFF4D5E),
  ),
  EvieeTokens(
    id: 'paper',
    label: 'Paper',
    background: Color(0xFFF4F2EC),
    card: Color(0xFFFFFFFF),
    muted: Color(0xFFECEAE2),
    border: Color(0xFFDDD9CC),
    foreground: Color(0xFF1A1B1C),
    foreground2: Color(0xFF6B6E66),
    accent: Color(0xFF16A34A),
    onAccent: Color(0xFFFFFFFF),
    accentDim: Color(0x1A16A34A),
    isLight: true,
  ),
];

EvieeTokens tokensFor(String id) =>
    evieePresets.firstWhere((t) => t.id == id, orElse: () => evieePresets.first);

/// Display greeting style: Playfair Display italic.
TextStyle greetingStyle(EvieeTokens t, {double size = 34}) =>
    GoogleFonts.playfairDisplay(
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.w500,
      fontSize: size,
      height: 1.25,
      color: t.foreground,
    );

/// AI message body: Newsreader.
TextStyle aiBodyStyle(EvieeTokens t) => GoogleFonts.newsreader(
      fontSize: 16,
      height: 1.6,
      color: t.foreground,
    );

/// UI text: Inter.
TextStyle uiStyle(EvieeTokens t,
        {double size = 15, FontWeight weight = FontWeight.w400, Color? color}) =>
    GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      height: 1.5,
      color: color ?? t.foreground,
    );

/// Mono: JetBrains Mono for provider/model/cost data.
TextStyle monoStyle(EvieeTokens t,
        {double size = 12, FontWeight weight = FontWeight.w500, Color? color}) =>
    GoogleFonts.jetBrainsMono(
      fontSize: size,
      fontWeight: weight,
      color: color ?? t.foreground2,
    );

ThemeData buildTheme(EvieeTokens t) {
  final base = t.isLight ? ThemeData.light() : ThemeData.dark();
  final scheme = ColorScheme(
    brightness: t.isLight ? Brightness.light : Brightness.dark,
    primary: t.accent,
    onPrimary: t.onAccent,
    secondary: t.accent,
    onSecondary: t.onAccent,
    surface: t.card,
    onSurface: t.foreground,
    error: const Color(0xFFEF4444),
    onError: Colors.white,
  );
  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: t.background,
    canvasColor: t.background,
    cardColor: t.card,
    dividerColor: t.border,
    textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: t.foreground,
      displayColor: t.foreground,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: t.background,
      foregroundColor: t.foreground,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: t.muted,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(color: t.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(color: t.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(color: t.accent, width: 1.5),
      ),
      hintStyle: GoogleFonts.inter(color: t.foreground2, fontSize: 14),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: t.muted,
      labelStyle: GoogleFonts.inter(color: t.foreground, fontSize: 12),
      side: BorderSide(color: t.border),
      shape: const StadiumBorder(),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (_) => t.isLight ? Colors.white : t.foreground),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.accent : t.muted),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: t.accent),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: t.accent,
        foregroundColor: t.onAccent,
        shape: const StadiumBorder(),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: t.foreground,
        side: BorderSide(color: t.border),
        shape: const StadiumBorder(),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: t.card,
      contentTextStyle: GoogleFonts.inter(color: t.foreground),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: t.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: t.border),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: t.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: t.foreground2,
      textColor: t.foreground,
    ),
    iconTheme: IconThemeData(color: t.foreground2),
  );
}
