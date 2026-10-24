import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

/// Afriva design tokens: light body, dark top bar, red primary.
class AppColors {
  AppColors._();

  static const bg = Color(0xFFFFFFFF);
  static const surface = Color(0xFFF2F2F2);
  static const surface2 = Color(0xFFE4E4E4);
  static const border = Color(0xFFE5E5E5);
  static const text = Color(0xFF1A1A1A);
  static const textMuted = Color(0xFF666666);
  static const textDim = Color(0xFF888888);
  static const chipText = Color(0xFF555555);
  static const primary = Color(0xFFE1122B);
  static const primaryPressed = Color(0xFFB80E22);
  static const primaryDeep = Color(0xFF8B0A1A);

  /// Dark top app bar and its pill search field.
  static const topBar = Color(0xFF2B2B2B);
  static const topBarField = Color(0xFF3A3A3A);
  static const topBarHint = Color(0xFF9A9A9A);

  static const success = Color(0xFF1A1A1A);
  static const danger = primary;

  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDeep],
  );

  /// Soft red wash used behind VIP / premium cards on the light body.
  static const vipCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFDE7EA), Color(0xFFF7F7F7)],
  );

  /// Bottom fade used on posters / banners so text stays legible.
  static const posterFade = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x00000000), Color(0x00000000), Color(0x66000000)],
    stops: [0, 0.7, 1],
  );
}

/// Palette for video surfaces (player, For You), which stay black.
class VideoColors {
  VideoColors._();
  static const bg = Color(0xFF000000);
  static const surface = Color(0xFF111111);
  static const surface2 = Color(0xFF1A1A1A);
  static const border = Color(0xFF262626);
  static const text = Color(0xFFFFFFFF);
  static const textMuted = Color(0xFFB3B3B3);
  static const textDim = Color(0xFF737373);
}

typedef _Palette = ({
  Brightness brightness,
  Color bg,
  Color surface,
  Color surface2,
  Color border,
  Color text,
  Color textMuted,
  Color textDim,
});

const _Palette _lightPalette = (
  brightness: Brightness.light,
  bg: AppColors.bg,
  surface: AppColors.surface,
  surface2: AppColors.surface2,
  border: AppColors.border,
  text: AppColors.text,
  textMuted: AppColors.textMuted,
  textDim: AppColors.textDim,
);

const _Palette _darkPalette = (
  brightness: Brightness.dark,
  bg: VideoColors.bg,
  surface: VideoColors.surface,
  surface2: VideoColors.surface2,
  border: VideoColors.border,
  text: VideoColors.text,
  textMuted: VideoColors.textMuted,
  textDim: VideoColors.textDim,
);

class AppRadii {
  AppRadii._();
  static const double poster = 6;
  static const double card = 14;
  static const double sheet = 22;
  static const double pill = 999;
}

class AppMotion {
  AppMotion._();
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 200);
  static const slow = Duration(milliseconds: 250);
  static const curve = Curves.easeOutCubic;
}

/// Light status-bar icons over the dark top bar / video surfaces.
const SystemUiOverlayStyle afrivaOverlayStyle = SystemUiOverlayStyle(
  statusBarColor: Color(0x00000000),
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemNavigationBarColor: AppColors.bg,
  systemNavigationBarIconBrightness: Brightness.dark,
  systemNavigationBarDividerColor: AppColors.border,
);

/// Dark status-bar icons for light screens without the dark top bar.
const SystemUiOverlayStyle afrivaLightOverlayStyle = SystemUiOverlayStyle(
  statusBarColor: Color(0x00000000),
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemNavigationBarColor: AppColors.bg,
  systemNavigationBarIconBrightness: Brightness.dark,
  systemNavigationBarDividerColor: AppColors.border,
);

const SystemUiOverlayStyle afrivaVideoOverlayStyle = SystemUiOverlayStyle(
  statusBarColor: Color(0x00000000),
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemNavigationBarColor: VideoColors.bg,
  systemNavigationBarIconBrightness: Brightness.light,
  systemNavigationBarDividerColor: VideoColors.bg,
);

class AppTheme {
  AppTheme._();

  static bool _googleFonts = true;
  static ThemeData? _light;
  static ThemeData? _dark;

  /// Call once at startup; [useGoogleFonts] is disabled in tests so no font
  /// is fetched over the network.
  static void init({bool useGoogleFonts = true}) {
    if (_googleFonts != useGoogleFonts) {
      _light = null;
      _dark = null;
    }
    _googleFonts = useGoogleFonts;
  }

  /// The app-wide light theme.
  static ThemeData get light => _light ??= _build(_lightPalette, _googleFonts);

  /// Theme for black video surfaces (player, For You).
  static ThemeData get video => _dark ??= _build(_darkPalette, _googleFonts);

  static ThemeData _build(_Palette p, bool useGoogleFonts) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      scaffoldBackgroundColor: p.bg,
      canvasColor: p.bg,
      colorScheme: ColorScheme(
        brightness: p.brightness,
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.primaryPressed,
        onSecondary: Colors.white,
        tertiary: p.text,
        surface: p.surface,
        onSurface: p.text,
        surfaceContainerHighest: p.surface2,
        outline: p.border,
        error: AppColors.danger,
        onError: Colors.white,
      ),
    );

    TextTheme text = base.textTheme;
    if (useGoogleFonts) {
      text = GoogleFonts.plusJakartaSansTextTheme(text);
    }
    text = text
        .apply(bodyColor: p.text, displayColor: p.text)
        .copyWith(
          displaySmall: text.displaySmall?.copyWith(
              fontWeight: FontWeight.w800, letterSpacing: -1, color: p.text),
          headlineMedium: text.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800, letterSpacing: -0.8, color: p.text),
          headlineSmall: text.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800, letterSpacing: -0.6, color: p.text),
          titleLarge: text.titleLarge?.copyWith(
              fontWeight: FontWeight.w800, letterSpacing: -0.4, color: p.text),
          titleMedium: text.titleMedium?.copyWith(
              fontWeight: FontWeight.w700, letterSpacing: -0.2, color: p.text),
          titleSmall: text.titleSmall?.copyWith(
              fontWeight: FontWeight.w700, color: p.text),
          bodyLarge: text.bodyLarge?.copyWith(color: p.text),
          bodyMedium: text.bodyMedium?.copyWith(color: p.textMuted, height: 1.45),
          bodySmall: text.bodySmall?.copyWith(color: p.textMuted),
          labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          labelMedium: text.labelMedium?.copyWith(fontWeight: FontWeight.w600),
          labelSmall: text.labelSmall?.copyWith(
              fontWeight: FontWeight.w600, color: p.textMuted, letterSpacing: 0.2),
        );

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: p.border),
    );

    return base.copyWith(
      textTheme: text,
      primaryTextTheme: text,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: p.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: p.brightness == Brightness.dark
            ? afrivaVideoOverlayStyle
            : afrivaLightOverlayStyle,
        titleTextStyle: text.titleLarge,
        foregroundColor: p.text,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.bg,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: p.bg,
        showDragHandle: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.sheet)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.bg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.sheet)),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.topBar,
        contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        hintStyle: text.bodyMedium?.copyWith(color: p.textDim),
        labelStyle: text.bodyMedium?.copyWith(color: p.textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: AppColors.primary, width: 1.4),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: AppColors.danger, width: 1.4),
        ),
        prefixIconColor: p.textMuted,
        suffixIconColor: p.textMuted,
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        indicatorColor: AppColors.primary,
        labelColor: p.brightness == Brightness.light ? AppColors.primary : p.text,
        unselectedLabelColor: p.textMuted,
        labelStyle: text.titleSmall,
        unselectedLabelStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        tabAlignment: TabAlignment.start,
      ),
      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.primary),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.primary : p.border,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.textMuted,
          textStyle: text.labelLarge,
        ),
      ),
      iconTheme: IconThemeData(color: p.text),
      listTileTheme: ListTileThemeData(
        iconColor: p.textMuted,
        textColor: p.text,
      ),
    );
  }
}
