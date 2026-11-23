import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

abstract final class AppTheme {
  /// Tests turn this off so no font is fetched over the network.
  static bool useGoogleFonts = true;

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final dark = b == Brightness.dark;
    final bg = dark ? Brand.bgDark : Brand.bgLight;
    final surface = dark ? Brand.surfaceDark : Brand.surfaceLight;
    final text = dark ? Brand.textDark : Brand.textLight;
    final muted = dark ? Brand.mutedDark : Brand.mutedLight;
    final border = dark ? Brand.borderDark : Brand.borderLight;
    final primary = dark ? Brand.crimson400 : Brand.crimson600;

    final scheme = ColorScheme.fromSeed(seedColor: Brand.crimson600, brightness: b).copyWith(
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: dark ? const Color(0xFF3A0610) : Brand.crimson50,
      onPrimaryContainer: dark ? Brand.crimson200 : Brand.crimson700,
      surface: surface,
      onSurface: text,
      onSurfaceVariant: muted,
      surfaceContainerLowest: surface,
      surfaceContainerLow: dark ? const Color(0xFF1B1819) : const Color(0xFFFAFAFA),
      surfaceContainer: dark ? const Color(0xFF201D1E) : const Color(0xFFF4F4F5),
      surfaceContainerHigh: dark ? const Color(0xFF262223) : const Color(0xFFEDEDEF),
      outline: border,
      outlineVariant: border,
      error: StatusColors.danger,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: b);
    final textTheme = (useGoogleFonts ? GoogleFonts.poppinsTextTheme(base.textTheme) : base.textTheme)
        .apply(bodyColor: text, displayColor: text);

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.control),
      borderSide: BorderSide(color: border),
    );

    return base.copyWith(
      scaffoldBackgroundColor: bg,
      textTheme: textTheme.copyWith(
        titleLarge: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600, fontSize: 20),
        titleMedium: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 16),
        titleSmall: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        bodyMedium: textTheme.bodyMedium?.copyWith(fontSize: 14),
        bodySmall: textTheme.bodySmall?.copyWith(color: muted),
        labelSmall: textTheme.labelSmall?.copyWith(color: muted, letterSpacing: 0.2),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600, fontSize: 19, color: text),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
          side: BorderSide(color: border),
        ),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(borderSide: BorderSide(color: primary, width: 1.6)),
        errorBorder: inputBorder.copyWith(borderSide: const BorderSide(color: StatusColors.danger)),
        labelStyle: TextStyle(color: muted),
        hintStyle: TextStyle(color: muted.withValues(alpha: 0.8)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.control)),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          side: BorderSide(color: border),
          foregroundColor: text,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.control)),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.control)),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      chipTheme: base.chipTheme.copyWith(
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        labelStyle: textTheme.labelMedium,
        backgroundColor: surface,
        selectedColor: scheme.primaryContainer,
        checkmarkColor: scheme.onPrimaryContainer,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        height: 66,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => textTheme.labelSmall?.copyWith(
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? scheme.onPrimaryContainer : muted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(color: s.contains(WidgetState.selected) ? scheme.onPrimaryContainer : muted),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
        unselectedIconTheme: IconThemeData(color: muted),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600, color: scheme.onPrimaryContainer),
        unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(color: muted),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sheet)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.control)),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: muted,
        contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.control)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: scheme.primaryContainer,
          selectedForegroundColor: scheme.onPrimaryContainer,
          side: BorderSide(color: border),
        ),
      ),
    );
  }
}

extension ThemeX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
}
