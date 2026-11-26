import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Extra semantic colors not covered by [ColorScheme].
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.shell,
    required this.shellBorder,
    required this.rail,
    required this.panel,
    required this.subtle,
    required this.muted,
    required this.accentSoft,
  });

  /// Top bar / chrome background.
  final Color shell;
  final Color shellBorder;
  final Color rail;

  /// Side panels (sidebar, summary).
  final Color panel;

  /// Hover / zebra rows.
  final Color subtle;
  final Color muted;
  final Color accentSoft;

  @override
  AppColors copyWith({
    Color? shell,
    Color? shellBorder,
    Color? rail,
    Color? panel,
    Color? subtle,
    Color? muted,
    Color? accentSoft,
  }) => AppColors(
    shell: shell ?? this.shell,
    shellBorder: shellBorder ?? this.shellBorder,
    rail: rail ?? this.rail,
    panel: panel ?? this.panel,
    subtle: subtle ?? this.subtle,
    muted: muted ?? this.muted,
    accentSoft: accentSoft ?? this.accentSoft,
  );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      shell: Color.lerp(shell, other.shell, t)!,
      shellBorder: Color.lerp(shellBorder, other.shellBorder, t)!,
      rail: Color.lerp(rail, other.rail, t)!,
      panel: Color.lerp(panel, other.panel, t)!,
      subtle: Color.lerp(subtle, other.subtle, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
    );
  }
}

extension AppThemeX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
  ColorScheme get scheme => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
}

class AppTheme {
  static const accent = Color(0xFF34C759); // EME green, a touch more saturated
  static const accentDark = Color(0xFF1F9D45);

  static ThemeData dark() => _build(
    brightness: Brightness.dark,
    scheme: const ColorScheme.dark(
      primary: accent,
      onPrimary: Color(0xFF04210E),
      secondary: Color(0xFF4C8DFF),
      onSecondary: Colors.white,
      surface: Color(0xFF16181C),
      onSurface: Color(0xFFE7E9EE),
      surfaceContainerLowest: Color(0xFF111316),
      surfaceContainerLow: Color(0xFF1A1D22),
      surfaceContainer: Color(0xFF1E2127),
      surfaceContainerHigh: Color(0xFF252931),
      surfaceContainerHighest: Color(0xFF2D323B),
      outline: Color(0xFF3A404B),
      outlineVariant: Color(0xFF2A2F37),
      onSurfaceVariant: Color(0xFF9BA3B1),
      error: Color(0xFFFF6B6B),
    ),
    colors: const AppColors(
      shell: Color(0xFF0F1114),
      shellBorder: Color(0xFF23272E),
      rail: Color(0xFF0B0C0F),
      panel: Color(0xFF14161A),
      subtle: Color(0xFF1C1F25),
      muted: Color(0xFF7D8594),
      accentSoft: Color(0x2634C759),
    ),
  );

  static ThemeData light() => _build(
    brightness: Brightness.light,
    scheme: const ColorScheme.light(
      primary: accentDark,
      onPrimary: Colors.white,
      secondary: Color(0xFF2F6FEB),
      onSecondary: Colors.white,
      surface: Color(0xFFFFFFFF),
      onSurface: Color(0xFF15171A),
      surfaceContainerLowest: Color(0xFFFFFFFF),
      surfaceContainerLow: Color(0xFFF7F8FA),
      surfaceContainer: Color(0xFFF2F4F7),
      surfaceContainerHigh: Color(0xFFEBEEF2),
      surfaceContainerHighest: Color(0xFFE3E7ED),
      outline: Color(0xFFD3D8E0),
      outlineVariant: Color(0xFFE6E9EE),
      onSurfaceVariant: Color(0xFF5C6472),
      error: Color(0xFFD93636),
    ),
    colors: const AppColors(
      shell: Color(0xFFFFFFFF),
      shellBorder: Color(0xFFE6E9EE),
      rail: Color(0xFFF3F5F8),
      panel: Color(0xFFFAFBFC),
      subtle: Color(0xFFF4F6F9),
      muted: Color(0xFF7A8290),
      accentSoft: Color(0x1F1F9D45),
    ),
  );

  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme scheme,
    required AppColors colors,
  }) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
    );
    final textTheme = GoogleFonts.interTextTheme(base.textTheme)
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
    final radius = BorderRadius.circular(8);
    return base.copyWith(
      textTheme: textTheme,
      scaffoldBackgroundColor: scheme.surface,
      extensions: [colors],
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      visualDensity: VisualDensity.compact,
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: TextStyle(color: scheme.onInverseSurface, fontSize: 12),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        hintStyle: TextStyle(color: colors.muted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: radius),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: radius),
          side: BorderSide(color: scheme.outline),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        labelStyle: TextStyle(fontSize: 12.5, color: scheme.onSurface),
        backgroundColor: scheme.surfaceContainerHigh,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: scheme.primary,
        dividerColor: scheme.outlineVariant,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: WidgetStateProperty.all(8),
        radius: const Radius.circular(8),
        thumbColor: WidgetStateProperty.all(scheme.outline),
      ),
    );
  }
}
