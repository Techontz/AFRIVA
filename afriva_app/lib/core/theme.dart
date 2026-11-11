import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

/// Neutral colors for one brightness.
class AppPalette {
  const AppPalette({
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.border,
    required this.text,
    required this.textMuted,
    required this.textDim,
    required this.chipText,
    required this.topBar,
    required this.topBarField,
    required this.topBarHint,
    required this.shimmerHighlight,
    required this.vipCard,
  });

  final Brightness brightness;
  final Color bg;
  final Color surface;
  final Color surface2;
  final Color border;
  final Color text;
  final Color textMuted;
  final Color textDim;
  final Color chipText;
  final Color topBar;
  final Color topBarField;
  final Color topBarHint;
  final Color shimmerHighlight;
  final List<Color> vipCard;

  static const light = AppPalette(
    brightness: Brightness.light,
    bg: Color(0xFFFFFFFF),
    surface: Color(0xFFF2F2F2),
    surface2: Color(0xFFE4E4E4),
    border: Color(0xFFE5E5E5),
    text: Color(0xFF1A1A1A),
    textMuted: Color(0xFF555555),
    textDim: Color(0xFF888888),
    chipText: Color(0xFF555555),
    topBar: Color(0xFFFFFFFF),
    topBarField: Color(0xFFF2F2F2),
    topBarHint: Color(0xFF888888),
    shimmerHighlight: Color(0xFFFAFAFA),
    vipCard: [Color(0xFFFDE7EA), Color(0xFFF7F7F7)],
  );

  static const dark = AppPalette(
    brightness: Brightness.dark,
    bg: Color(0xFF000000),
    surface: Color(0xFF111111),
    surface2: Color(0xFF1A1A1A),
    border: Color(0xFF262626),
    text: Color(0xFFFFFFFF),
    textMuted: Color(0xFFB3B3B3),
    textDim: Color(0xFF737373),
    chipText: Color(0xFFB3B3B3),
    topBar: Color(0xFF000000),
    topBarField: Color(0xFF1A1A1A),
    topBarHint: Color(0xFF737373),
    shimmerHighlight: Color(0xFF222222),
    vipCard: [Color(0xFF3A0E15), Color(0xFF181818)],
  );
}

/// Afriva design tokens: red primary on a dark (default) or light body.
///
/// Neutral tokens follow the active palette, which the app root sets from the
/// resolved theme brightness (see [AppColors.use]).
class AppColors {
  AppColors._();

  static AppPalette _p = AppPalette.dark;

  /// The palette neutral tokens currently resolve to.
  static AppPalette get palette => _p;
  static bool get isDark => _p.brightness == Brightness.dark;

  /// Switches neutral tokens to [brightness]; returns true when it changed.
  static bool use(Brightness brightness) {
    final next = brightness == Brightness.dark ? AppPalette.dark : AppPalette.light;
    if (identical(next, _p)) return false;
    _p = next;
    return true;
  }

  static Color get bg => _p.bg;
  static Color get surface => _p.surface;
  static Color get surface2 => _p.surface2;
  static Color get border => _p.border;
  static Color get text => _p.text;
  static Color get textMuted => _p.textMuted;
  static Color get textDim => _p.textDim;
  static Color get chipText => _p.chipText;
  static const primary = Color(0xFFE90204);
  static const primaryPressed = Color(0xFFBF0003);
  static const primaryDeep = Color(0xFF8F0002);

  /// Top bar: the same as the page so the header blends in.
  static Color get topBar => _p.topBar;
  static Color get topBarField => _p.topBarField;
  static Color get topBarHint => _p.topBarHint;
  static Color get shimmerHighlight => _p.shimmerHighlight;

  static Color get success => _p.text;
  static const danger = primary;

  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDeep],
  );

  /// Soft red wash used behind VIP / premium cards.
  static LinearGradient get vipCardGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: _p.vipCard,
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

_Palette _fromApp(AppPalette p) => (
      brightness: p.brightness,
      bg: p.bg,
      surface: p.surface,
      surface2: p.surface2,
      border: p.border,
      text: p.text,
      textMuted: p.textMuted,
      textDim: p.textDim,
    );

const _Palette _videoPalette = (
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
  static const double poster = 14;
  static const double card = 16;
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
SystemUiOverlayStyle get afrivaOverlayStyle => SystemUiOverlayStyle(
      statusBarColor: const Color(0x00000000),
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.bg,
      systemNavigationBarIconBrightness: AppColors.isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarDividerColor: AppColors.border,
    );

/// Status-bar icons for body screens without the dark top bar: dark icons
/// on the light body, light icons on the dark body.
SystemUiOverlayStyle get afrivaLightOverlayStyle => _bodyOverlay(AppColors.palette);

SystemUiOverlayStyle _bodyOverlay(AppPalette p) {
  final dark = p.brightness == Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: const Color(0x00000000),
    statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    statusBarBrightness: dark ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: p.bg,
    systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    systemNavigationBarDividerColor: p.border,
  );
}

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
  static ThemeData? _video;

  /// Call once at startup; [useGoogleFonts] is disabled in tests so no font
  /// is fetched over the network.
  static void init({bool useGoogleFonts = true}) {
    if (_googleFonts != useGoogleFonts) {
      _light = null;
      _dark = null;
      _video = null;
    }
    _googleFonts = useGoogleFonts;
  }

  /// The app-wide light theme.
  static ThemeData get light => _light ??= _build(_fromApp(AppPalette.light), _googleFonts);

  /// The app-wide dark theme (default).
  static ThemeData get dark => _dark ??= _build(_fromApp(AppPalette.dark), _googleFonts);

  /// Theme for black video surfaces (player, For You).
  static ThemeData get video => _video ??= _build(_videoPalette, _googleFonts);

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
      borderSide: BorderSide.none,
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
        systemOverlayStyle: p.bg == VideoColors.bg
            ? afrivaVideoOverlayStyle
            : _bodyOverlay(p.brightness == Brightness.dark ? AppPalette.dark : AppPalette.light),
        titleTextStyle: text.headlineSmall?.copyWith(fontSize: 22),
        foregroundColor: p.text,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: p.surface,
        showDragHandle: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.sheet)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.sheet)),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2B2B2B),
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
          borderSide: BorderSide(color: AppColors.primary, width: 1.2),
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
        labelColor: p.bg == VideoColors.bg ? p.text : AppColors.primary,
        unselectedLabelColor: p.textMuted,
        labelStyle: text.titleSmall,
        unselectedLabelStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        tabAlignment: TabAlignment.start,
      ),
      dividerTheme: DividerThemeData(color: p.border, thickness: 0.6, space: 1),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.primary),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.primary : p.surface2,
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
