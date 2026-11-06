import 'package:flutter/material.dart';

import 'widgets/motion.dart';

/// Design tokens taken from the Figma "Chat page" frames (430 x 932).
/// Keep every color / text style here so final Figma values are a one-file swap.
class AppColors {
  static const ink = Color(0xFF111111);
  static const muted = Color(0xFF8A8A8A);
  static const bubble = Color(0xFFE3E3E3); // grey circle behind each avatar
  static const chatBackground = Color(0xFFDDDDDD);
  static const sent = Color(0xFFE4F9CB); // light green sent message
  static const received = Colors.white;
  static const online = Color(0xFF34C759);
  static const badge = Color(0xFFFFD60A); // yellow unread counter
  static const storyRing = Color(0xFF8C6464);
  static const accent = Color(0xFF22C55E); // send button / highlights
  static const mergeTarget = Color(0xFF34C759);

  /// Story rings, the create button: warm Snapchat / Instagram-like energy.
  static const storyGradient = [
    Color(0xFFFF3D7F),
    Color(0xFFFF8A3D),
    Color(0xFFFFC53D),
    Color(0xFFFF3D7F),
  ];
  static const brandGradient = [Color(0xFFFF3D7F), Color(0xFFFF8A3D)];

  /// Grey page behind feed cards (Facebook-style).
  static const page = Color(0xFFF2F3F5);
  static const card = Colors.white;
  static const line = Color(0xFFE9E9EC);
  static const like = Color(0xFF1877F2);
}

TextStyle tx(
  double size, {
  FontWeight weight = FontWeight.w400,
  Color color = AppColors.ink,
}) {
  // Outfit is a variable font: set the weight axis explicitly so every platform renders it.
  return TextStyle(
    fontFamily: 'Outfit',
    fontSize: size,
    fontWeight: weight,
    fontVariations: [FontVariation('wght', weight.value.toDouble())],
    color: color,
    height: 1.2,
  );
}

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Outfit',
    scaffoldBackgroundColor: Colors.white,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      surface: Colors.white,
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
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
