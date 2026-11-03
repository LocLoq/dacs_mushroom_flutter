import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  static const fontFamily = 'BeVietnamPro';

  static TextTheme _text(Color ink, Color muted) {
    TextStyle s(double size, FontWeight w, {Color? c, double? h, double? ls}) =>
        TextStyle(
          fontFamily: fontFamily,
          fontSize: size,
          fontWeight: w,
          color: c ?? ink,
          height: h,
          letterSpacing: ls,
        );
    return TextTheme(
      displaySmall: s(32, FontWeight.w800, h: 1.15, ls: -0.5),
      headlineMedium: s(26, FontWeight.w800, h: 1.2, ls: -0.3),
      headlineSmall: s(22, FontWeight.w700, h: 1.25, ls: -0.2),
      titleLarge: s(20, FontWeight.w700, h: 1.3),
      titleMedium: s(16, FontWeight.w700, h: 1.35),
      titleSmall: s(14, FontWeight.w600, h: 1.35),
      bodyLarge: s(15, FontWeight.w400, h: 1.5),
      bodyMedium: s(14, FontWeight.w400, h: 1.5),
      bodySmall: s(12, FontWeight.w400, c: muted, h: 1.45),
      labelLarge: s(14, FontWeight.w600),
      labelMedium: s(12, FontWeight.w600),
      labelSmall: s(11, FontWeight.w600),
    );
  }

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final isDark = b == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.mintSoft;
    final surface = isDark ? AppColors.darkCard : Colors.white;
    final line = isDark ? AppColors.darkLine : AppColors.line;
    final ink = isDark ? const Color(0xFFEAF2E2) : AppColors.textPrimary;
    final muted = isDark ? const Color(0xFF9FB08F) : AppColors.textSecondary;
    final primary = isDark ? AppColors.leaf : AppColors.primary;

    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: b,
    ).copyWith(
      primary: primary,
      onPrimary: isDark ? AppColors.darkBg : Colors.white,
      primaryContainer: isDark ? const Color(0xFF243818) : AppColors.mint,
      onPrimaryContainer: isDark ? const Color(0xFFD5EBC0) : AppColors.primaryDark,
      surface: bg,
      onSurface: ink,
      onSurfaceVariant: muted,
      surfaceContainerLowest: surface,
      surfaceContainerLow: surface,
      surfaceContainer: surface,
      surfaceContainerHigh: isDark ? const Color(0xFF223019) : AppColors.mint,
      surfaceContainerHighest: isDark ? const Color(0xFF2B3922) : AppColors.mint,
      outline: line,
      outlineVariant: line,
      error: AppColors.danger,
    );

    final radius = BorderRadius.circular(16);

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      fontFamily: fontFamily,
      textTheme: _text(ink, muted),
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),

      // AppBar: nền trong suốt, chữ đậm, không đổ bóng
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleSpacing: 20,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
          color: ink,
        ),
      ),

      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: line),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: TextStyle(color: muted, fontWeight: FontWeight.w400),
        labelStyle: TextStyle(color: muted),
        prefixIconColor: muted,
        suffixIconColor: muted,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.6),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: isDark ? AppColors.leaf : AppColors.primary,
          foregroundColor: isDark ? AppColors.darkBg : Colors.white,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: isDark ? AppColors.leaf : AppColors.primary,
          foregroundColor: isDark ? AppColors.darkBg : Colors.white,
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(64, 52),
          side: BorderSide(color: line, width: 1.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: isDark ? AppColors.leaf : AppColors.primary,
        side: BorderSide(color: line),
        shape: const StadiumBorder(),
        showCheckmark: false,
        labelStyle: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: ink,
        ),
        secondaryLabelStyle: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: isDark ? AppColors.darkBg : Colors.white,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: ink,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primaryDark,
        contentTextStyle: const TextStyle(
          fontFamily: fontFamily,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: primary,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? primary : line,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: line,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: primary,
          selectedForegroundColor: isDark ? AppColors.darkBg : Colors.white,
          side: BorderSide(color: line),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: isDark ? AppColors.darkBg : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
