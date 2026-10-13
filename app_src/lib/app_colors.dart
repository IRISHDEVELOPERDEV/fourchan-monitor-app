import 'package:flutter/material.dart';

/// The app's fixed palette, in one place. These are the exact values that were
/// previously repeated across the screens -- changing one here changes it
/// everywhere, so keep them identical unless a visual change is intended.
class AppColors {
  AppColors._();

  /// X4chan clover green: accents, selected states, keyword highlights.
  static const green = Color(0xFF43B14B);

  /// Blue used for >>quote links and the highlighted post in a thread.
  static const quote = Color(0xFF6AA9C9);

  /// Card / section / sheet background in dark mode (light mode uses white).
  static const cardDark = Color(0xFF17191C);

  /// Unselected segment background in light mode.
  static const segmentLight = Color(0xFFECEEF1);

  /// Scaffold + app bar background in dark mode.
  static const scaffoldDark = Color(0xFF0E0F11);

  /// Scaffold background in light mode.
  static const scaffoldLight = Color(0xFFF5F6F8);

  /// App bar text/icons in light mode.
  static const appBarFgLight = Color(0xFF15171A);

  /// Bottom navigation bar background in dark mode.
  static const navBarDark = Color(0xFF121417);

  /// Card background for the current brightness (white in light mode).
  static Color card(bool dark) => dark ? cardDark : Colors.white;
}
