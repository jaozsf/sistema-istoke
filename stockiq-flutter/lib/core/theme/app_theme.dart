import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Paleta "Lagoon" + linguagem visual de iOS (fundo agrupado, cards sem
/// sombra, cantos contínuos, transição de página Cupertino em toda
/// plataforma). Fonte: a do sistema (SF Pro no iPhone, Roboto no Android)
/// -- não declara família própria de propósito.
class AppTheme {
  AppTheme._();

  // ── Lagoon ────────────────────────────────────────────────────────────────
  static const Color abyss  = Color(0xFF04181C); // texto/fundo escuro
  static const Color deep   = Color(0xFF0A4A55);
  static const Color lagoon = Color(0xFF14918F); // marca
  static const Color aqua   = Color(0xFF4FD8C4); // destaque no escuro
  static const Color foam   = Color(0xFFD4FBF3); // realce claro

  static const Color primary     = lagoon;
  static const Color primaryDark = deep;

  // Semânticas -- ajustadas pra não brigar com o teal da marca
  static const Color success = Color(0xFF2FB36B);
  static const Color warning = Color(0xFFE59E2D);
  static const Color danger  = Color(0xFFE5484D);
  static const Color info    = Color(0xFF3B82C4);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [deep, lagoon, aqua],
  );

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark  => _build(Brightness.dark);

  /// Cor de marca legível no fundo atual (teal no claro, aqua no escuro).
  static Color accentOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? aqua : lagoon;

  static ThemeData _build(Brightness brightness) {
    final isDark  = brightness == Brightness.dark;
    final bg      = isDark ? const Color(0xFF02100F) : const Color(0xFFF1F6F5);
    final surface = isDark ? const Color(0xFF0B2226) : Colors.white;
    final surface2= isDark ? const Color(0xFF113037) : const Color(0xFFE6F2F0);
    final onBg    = isDark ? const Color(0xFFE8FBF7) : abyss;
    final muted   = isDark ? const Color(0xFF8FB5B0) : const Color(0xFF5D7774);
    final hairline= isDark ? const Color(0xFF173A40) : const Color(0xFFDCE8E6);
    final accent  = isDark ? aqua : lagoon;

    const radius = 14.0;
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: accent,
        onPrimary: isDark ? abyss : Colors.white,
        primaryContainer: isDark ? deep : foam,
        onPrimaryContainer: isDark ? foam : deep,
        secondary: isDark ? lagoon : deep,
        onSecondary: Colors.white,
        error: danger,
        onError: Colors.white,
        surface: surface,
        onSurface: onBg,
        onSurfaceVariant: muted,
        surfaceContainerHighest: surface2,
        surfaceContainerLow: bg,
        outline: hairline,
        outlineVariant: hairline,
      ),
      scaffoldBackgroundColor: bg,
      splashFactory: NoSplash.splashFactory, // iOS não tem ripple
      highlightColor: accent.withValues(alpha: .08),
      cupertinoOverrideTheme: CupertinoThemeData(
        brightness: brightness,
        primaryColor: accent,
        scaffoldBackgroundColor: bg,
        barBackgroundColor: surface.withValues(alpha: .85),
      ),
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          for (final p in TargetPlatform.values) p: const CupertinoPageTransitionsBuilder(),
        },
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: shape,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      dividerTheme: DividerThemeData(color: hairline, thickness: .5, space: .5),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: onBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(color: onBg, fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -.4),
        iconTheme: IconThemeData(color: accent),
        actionsIconTheme: IconThemeData(color: accent),
        surfaceTintColor: Colors.transparent,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: accent,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        minVerticalPadding: 10,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface2,
        selectedColor: accent,
        labelStyle: TextStyle(color: onBg, fontSize: 13, fontWeight: FontWeight.w500),
        secondaryLabelStyle: TextStyle(color: isDark ? abyss : Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
        side: BorderSide.none,
        shape: const StadiumBorder(),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          side: WidgetStatePropertyAll(BorderSide(color: hairline)),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? surface2 : abyss,
        contentTextStyle: TextStyle(color: isDark ? onBg : Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: isDark ? abyss : Colors.white,
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: accent, linearTrackColor: surface2),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? success : hairline,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface2,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: danger, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        hintStyle: TextStyle(color: muted, fontSize: 15),
        labelStyle: TextStyle(color: muted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: isDark ? abyss : Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: shape,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -.2),
          elevation: 0,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: isDark ? abyss : Colors.white,
          minimumSize: const Size(0, 50),
          shape: shape,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -.2),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          minimumSize: const Size(double.infinity, 50),
          shape: shape,
          side: BorderSide(color: accent.withValues(alpha: .5)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -.2),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accent, textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      ),
      // Escala tipográfica do iOS (Large Title 34 / Title 22 / Headline 17 /
      // Body 17 / Subhead 15 / Footnote 13 / Caption 12)
      textTheme: TextTheme(
        displaySmall:  TextStyle(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -.8, color: onBg),
        headlineMedium:TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -.5, color: onBg),
        titleLarge:    TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -.4, color: onBg),
        titleMedium:   TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -.2, color: onBg),
        bodyLarge:     TextStyle(fontSize: 17, fontWeight: FontWeight.w400, letterSpacing: -.4, color: onBg),
        bodyMedium:    TextStyle(fontSize: 15, fontWeight: FontWeight.w400, letterSpacing: -.2, color: onBg),
        bodySmall:     TextStyle(fontSize: 13, color: muted),
        labelLarge:    TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: onBg),
        labelSmall:    TextStyle(fontSize: 12, color: muted, letterSpacing: 0),
      ),
    );
  }
}
