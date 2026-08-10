import 'package:flutter/material.dart';
import '../theme/darkroom_theme.dart';

/// Wraps [child] and shows a "please rotate" prompt instead whenever the OS
/// hands us a portrait-shaped viewport despite `main.dart`'s
/// `SystemChrome.setPreferredOrientations([landscapeLeft, landscapeRight])`.
///
/// That lock is a *request*, not a guarantee — it can be overridden by:
///  - foldables in book/portrait posture,
///  - split-screen / freeform multi-window (many OEMs force the requested
///    orientation only for fullscreen apps),
///  - some manufacturer software that lets the user override per-app
///    rotation lock globally.
///
/// None of that existed on the single Pixel 4a this app was originally
/// verified on (full-screen, no multi-window used), but all of it is fair
/// game once "runs on every Android device" is the goal. Without this
/// gate, the fixed 3x2 landscape grid would simply get laid out inside a
/// tall, narrow box — no crash, but the buttons would be thin, cramped
/// slivers, exactly wrong for a "big, glanceable, usable by feel in the
/// dark" darkroom timer.
///
/// Deliberately not applied by wrapping [HomeScreen] alone: hooked into
/// `MaterialApp.builder` in `main.dart` instead, so it also covers the
/// settings screen (pushed as a separate route) with one implementation.
class OrientationGate extends StatelessWidget {
  final Widget child;

  const OrientationGate({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isPortrait = size.height > size.width;
    if (!isPortrait) return child;

    return Scaffold(
      backgroundColor: DarkroomColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.screen_rotation,
                color: DarkroomColors.red,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'Bitte Gerät drehen',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: DarkroomColors.red,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Diese App ist für Querformat ausgelegt.',
                textAlign: TextAlign.center,
                style: TextStyle(color: DarkroomColors.dimRed, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
