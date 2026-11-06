import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'widgets/motion.dart';

/// Design tokens. Colors follow the device's light or dark setting:
/// [FollowDeviceTheme] keeps [dark] current and rebuilds the app when it
/// changes. The night* colors never change: they are for places that stay
/// dark in both themes (stories, videos, black tiles).
class AppColors {
  static bool dark = false;

  // Surfaces and text.
  static Color get page => dark ? Colors.black : const Color(0xFFF5F5F7);
  static Color get card => dark ? const Color(0xFF1C1C1E) : Colors.white;
  static Color get ink =>
      dark ? const Color(0xFFF5F5F7) : const Color(0xFF1D1D1F);
  static Color get onInk => dark ? const Color(0xFF1D1D1F) : Colors.white;
  static Color get muted =>
      dark ? const Color(0xFFA1A1A6) : const Color(0xFF6E6E73);
  static Color get line =>
      dark ? const Color(0xFF38383A) : const Color(0xFFD2D2D7);
  static Color get bubble => dark
      ? const Color(0xFF2C2C2E)
      : const Color(0xFFE8E8ED); // quiet controls

  /// Big tiles with white words: black on light pages, raised on black ones.
  static Color get hero => dark ? const Color(0xFF1C1C1E) : Colors.black;

  // Always dark.
  static const night = Colors.black;
  static const nightCard = Color(0xFF1C1C1E);
  static const nightChip = Color(0xFF2C2C2E);
  static const nightInk = Color(0xFFF5F5F7);
  static const nightMuted = Color(0xFFA1A1A6);
  static const nightLink = Color(0xFF2997FF);

  // Accent: links and the active state.
  static Color get accent =>
      dark ? const Color(0xFF0A84FF) : const Color(0xFF0071E3);
  static Color get link => dark ? nightLink : const Color(0xFF0066CC);
  static Color get like => accent;

  // Meaning.
  static const online = Color(0xFF34C759);
  static const danger = Color(0xFFE5484D);
  static Color get badge => accent;

  // Chats.
  static Color get chatBackground => page;
  static Color get sent => accent;
  static const onSent = Colors.white;
  static Color get received => card;
  static Color get storyRing => accent;
  static Color get mergeTarget => accent;

  /// Primary filled controls.
  static List<Color> get brandGradient => [accent, accent];
}

/// Display sizes are set tight, small sizes a little looser.
double _tracking(double size) {
  if (size >= 34) return size * -.03;
  if (size >= 20) return size * -.02;
  return size * -.01;
}

TextStyle tx(double size, {FontWeight weight = FontWeight.w400, Color? color}) {
  // Emphasis tops out at semibold: size carries the hierarchy, not heaviness.
  final w = weight.value > 600 ? FontWeight.w600 : weight;
  return TextStyle(
    fontFamily: 'InterTight',
    fontSize: size,
    fontWeight: w,
    fontVariations: [FontVariation('wght', w.value.toDouble())],
    color: color ?? AppColors.ink,
    height: size >= 34 ? 1.06 : 1.25,
    letterSpacing: _tracking(size),
  );
}

enum ThemeChoice { system, light, dark }

/// Rebuilds [builder] when the phone switches between light and dark, or when
/// the choice in Account changes.
class FollowDeviceTheme extends StatefulWidget {
  const FollowDeviceTheme({super.key, required this.builder});
  final WidgetBuilder builder;

  static final choice = ValueNotifier(ThemeChoice.system);
  static const _key = 'theme';

  static Future<void> choose(ThemeChoice c) async {
    choice.value = c;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, c.name);
  }

  static Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      choice.value = ThemeChoice.values.firstWhere(
        (c) => c.name == saved,
        orElse: () => ThemeChoice.system,
      );
    } on Exception {
      // No saved choice available: follow the device.
    }
  }

  @override
  State<FollowDeviceTheme> createState() => _FollowDeviceThemeState();
}

class _FollowDeviceThemeState extends State<FollowDeviceTheme>
    with WidgetsBindingObserver {
  void _read() {
    AppColors.dark = switch (FollowDeviceTheme.choice.value) {
      ThemeChoice.light => false,
      ThemeChoice.dark => true,
      ThemeChoice.system =>
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark,
    };
  }

  void _apply() {
    final before = AppColors.dark;
    _read();
    if (before == AppColors.dark || !mounted) return;
    // Colors are read while building, so even const widgets must rebuild.
    void mark(Element e) {
      e.markNeedsBuild();
      e.visitChildren(mark);
    }

    setState(() {});
    (context as Element).visitChildren(mark);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FollowDeviceTheme.choice.addListener(_apply);
    _read();
    FollowDeviceTheme._load();
  }

  @override
  void dispose() {
    FollowDeviceTheme.choice.removeListener(_apply);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() => _apply();

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

ThemeData buildTheme() {
  final brightness = AppColors.dark ? Brightness.dark : Brightness.light;
  const sheetShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: 'InterTight',
    scaffoldBackgroundColor: AppColors.page,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: brightness,
      primary: AppColors.accent,
      onPrimary: Colors.white,
      surface: AppColors.card,
      onSurface: AppColors.ink,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: SmoothPageTransitions(),
        TargetPlatform.iOS: SmoothPageTransitions(),
        TargetPlatform.linux: SmoothPageTransitions(),
        TargetPlatform.macOS: SmoothPageTransitions(),
        TargetPlatform.windows: SmoothPageTransitions(),
        TargetPlatform.fuchsia: SmoothPageTransitions(),
      },
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.nightChip,
      actionTextColor: AppColors.nightLink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: AppColors.card,
      surfaceTintColor: Colors.transparent,
      shape: sheetShape,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: const StadiumBorder(),
        minimumSize: const Size(48, 48),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: const StadiumBorder(),
        minimumSize: const Size(48, 48),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.page,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.ink,
    ),
  );
}
