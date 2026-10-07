import 'package:flutter/material.dart';

/// Brand and status colours. The admin app is mostly neutral; these are the
/// accents.
abstract final class AppColors {
  static const ink = Color(0xFF1C1B18);
  static const forest = Color(0xFF0B3A30);
  static const emerald = Color(0xFF0E9F6E);
  static const lime = Color(0xFF3DDC97);
  static const purple = Color(0xFF7C5CFC);
  static const mist = Color(0xFFF5F5F2);
  static const danger = Color(0xFFE5484D);
  static const amber = Color(0xFFD98A00);
  static const blue = Color(0xFF3B82F6);
  static const slate = Color(0xFF7A776F);
}

abstract final class AppMotion {
  static const quick = Duration(milliseconds: 160);
  static const standard = Duration(milliseconds: 260);
  static const entrance = Duration(milliseconds: 420);
  static const curve = Curves.easeOutCubic;
}

abstract final class AppSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

/// The colours of the page furniture — sidebar, cards, borders — for the
/// current brightness. Read it with `Palette.of(context)`.
class Palette {
  const Palette({
    required this.page,
    required this.card,
    required this.border,
    required this.text,
    required this.muted,
    required this.subtle,
    required this.hover,
    required this.sidebar,
    required this.sidebarText,
    required this.sidebarMuted,
    required this.sidebarActive,
    required this.sidebarBorder,
    required this.accent,
    required this.shadow,
  });

  /// The background behind the cards.
  final Color page;
  final Color card;
  final Color border;
  final Color text;

  /// Secondary text.
  final Color muted;

  /// A faint fill: table headers, input backgrounds, code blocks.
  final Color subtle;

  /// The fill of a row or button under the pointer.
  final Color hover;
  final Color sidebar;
  final Color sidebarText;
  final Color sidebarMuted;
  final Color sidebarActive;
  final Color sidebarBorder;
  final Color accent;
  final Color shadow;

  static const _light = Palette(
    page: Color(0xFFF5F5F2),
    card: Color(0xFFFFFFFF),
    border: Color(0xFFE7E5DF),
    text: Color(0xFF1C1B18),
    muted: Color(0xFF6F6C64),
    subtle: Color(0xFFF7F6F3),
    hover: Color(0xFFF1F0EC),
    sidebar: Color(0xFF1B1B18),
    sidebarText: Color(0xFFE9E7E1),
    sidebarMuted: Color(0xFF8E8B82),
    sidebarActive: Color(0xFF2C2B27),
    sidebarBorder: Color(0xFF2C2B27),
    accent: Color(0xFF0E9F6E),
    shadow: Color(0x0F1C1B18),
  );

  static const _dark = Palette(
    page: Color(0xFF121210),
    card: Color(0xFF1B1B18),
    border: Color(0xFF2C2B27),
    text: Color(0xFFEDEBE6),
    muted: Color(0xFF9B978D),
    subtle: Color(0xFF211F1C),
    hover: Color(0xFF262521),
    sidebar: Color(0xFF0E0E0C),
    sidebarText: Color(0xFFE9E7E1),
    sidebarMuted: Color(0xFF8E8B82),
    sidebarActive: Color(0xFF232320),
    sidebarBorder: Color(0xFF232320),
    accent: Color(0xFF3DDC97),
    shadow: Color(0x00000000),
  );

  static Palette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _dark : _light;
}

abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final palette = dark ? Palette._dark : Palette._light;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.emerald,
      brightness: brightness,
    ).copyWith(
      primary: palette.accent,
      onPrimary: dark ? const Color(0xFF06231A) : Colors.white,
      secondary: AppColors.purple,
      surface: palette.card,
      onSurface: palette.text,
      onSurfaceVariant: palette.muted,
      outline: palette.border,
      outlineVariant: palette.border,
      error: AppColors.danger,
      onError: Colors.white,
      surfaceContainerLowest: palette.card,
      surfaceContainerLow: palette.card,
      surfaceContainer: palette.card,
      surfaceContainerHigh: palette.card,
      surfaceContainerHighest: palette.subtle,
      surfaceTint: Colors.transparent,
    );
    final base = ThemeData(brightness: brightness, useMaterial3: true);
    final textTheme = base.textTheme
        .apply(bodyColor: palette.text, displayColor: palette.text)
        .copyWith(
          displaySmall: base.textTheme.displaySmall?.copyWith(
            color: palette.text,
            fontWeight: FontWeight.w700,
            letterSpacing: -1,
          ),
          headlineMedium: base.textTheme.headlineMedium?.copyWith(
            color: palette.text,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
          ),
          headlineSmall: base.textTheme.headlineSmall?.copyWith(
            color: palette.text,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
          titleLarge: base.textTheme.titleLarge?.copyWith(
            color: palette.text,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
          titleMedium: base.textTheme.titleMedium?.copyWith(
            color: palette.text,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          titleSmall: base.textTheme.titleSmall?.copyWith(
            color: palette.text,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: base.textTheme.bodyLarge?.copyWith(
            color: palette.text,
            fontSize: 15,
            height: 1.45,
          ),
          bodyMedium: base.textTheme.bodyMedium?.copyWith(
            color: palette.text,
            fontSize: 14,
            height: 1.45,
          ),
          bodySmall: base.textTheme.bodySmall?.copyWith(
            color: palette.text,
            fontSize: 12.5,
            height: 1.4,
          ),
        );
    final shape10 = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    );
    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.page,
      canvasColor: palette.card,
      dividerColor: palette.border,
      hoverColor: palette.hover,
      splashFactory: InkRipple.splashFactory,
      textTheme: textTheme,
      iconTheme: IconThemeData(color: palette.muted, size: 20),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: palette.page,
        surfaceTintColor: Colors.transparent,
        foregroundColor: palette.text,
        titleTextStyle: textTheme.titleLarge,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.card,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: TextStyle(color: palette.muted),
        labelStyle: TextStyle(color: palette.muted),
        helperStyle: TextStyle(color: palette.muted, fontSize: 12),
        prefixIconColor: palette.muted,
        suffixIconColor: palette.muted,
        border: inputBorder(palette.border),
        enabledBorder: inputBorder(palette.border),
        disabledBorder: inputBorder(palette.border.withValues(alpha: 0.6)),
        focusedBorder: inputBorder(palette.accent, 1.5),
        errorBorder: inputBorder(AppColors.danger),
        focusedErrorBorder: inputBorder(AppColors.danger, 1.5),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 42),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: shape10,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 42),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: shape10,
          foregroundColor: palette.text,
          side: BorderSide(color: palette.border),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 38),
          shape: shape10,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: palette.muted,
          shape: shape10,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: palette.card,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: palette.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.card,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: palette.border),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: palette.card,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: palette.border),
        ),
        textStyle: textTheme.bodyMedium,
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(palette.card),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: palette.border),
            ),
          ),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFFEDEBE6) : const Color(0xFF1C1B18),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(
          color: dark ? const Color(0xFF1C1B18) : Colors.white,
          fontSize: 12,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : palette.muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? palette.accent
              : palette.subtle,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? palette.accent
              : palette.border,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        side: BorderSide(color: palette.muted, width: 1.4),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.accent,
        linearTrackColor: palette.subtle,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(8),
        radius: const Radius.circular(8),
        thumbColor: WidgetStatePropertyAll(
          palette.muted.withValues(alpha: 0.35),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: palette.muted,
        textColor: palette.text,
      ),
      dividerTheme: DividerThemeData(color: palette.border, thickness: 1, space: 1),
    );
  }
}
