import 'package:flutter/material.dart';

/// Darkroom-safe palette: pure black background, pure red everywhere else.
/// The ONLY intentional exception anywhere in the app is the physical white
/// focus light triggered on the ESP32 — never a white pixel on screen.
class DarkroomColors {
  DarkroomColors._();

  static const Color background = Colors.black;
  static const Color red = Color(0xFFFF0000);
  static const Color dimRed = Color(0xFF7A0000); // disabled state, borders
}

ThemeData buildDarkroomTheme() {
  const red = DarkroomColors.red;
  const bg = DarkroomColors.background;

  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: bg,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: red,
      onPrimary: bg,
      surface: bg,
      onSurface: red,
      error: red,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: red, fontWeight: FontWeight.bold),
      displayMedium: TextStyle(color: red, fontWeight: FontWeight.bold),
      titleLarge: TextStyle(color: red, fontWeight: FontWeight.bold),
      bodyLarge: TextStyle(color: red),
      bodyMedium: TextStyle(color: red),
      labelLarge: TextStyle(color: red, fontWeight: FontWeight.bold),
    ),
    iconTheme: const IconThemeData(color: red),
    dividerColor: DarkroomColors.dimRed,
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: red,
        side: const BorderSide(color: red, width: 2),
        backgroundColor: bg,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: red),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: red,
      thumbColor: red,
      inactiveTrackColor: DarkroomColors.dimRed,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(red),
      trackColor: WidgetStateProperty.all(DarkroomColors.dimRed),
    ),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: bg),
  );
}
