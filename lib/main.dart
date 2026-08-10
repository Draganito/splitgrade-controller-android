import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'ble/ble_service.dart';
import 'screens/home_screen.dart';
import 'theme/darkroom_theme.dart';
import 'widgets/orientation_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Darkroom display requirements (spec section 3):
  //  - forced landscape
  //  - immersive mode (no status/nav bars)
  //  - permanent wakelock (screen never sleeps mid-exposure)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await WakelockPlus.enable();

  final ble = BleService();
  // Fire-and-forget: try to silently reconnect to the last paired ESP32
  // without blocking app startup.
  unawaited(ble.tryAutoReconnect());

  runApp(DarkroomApp(ble: ble));
}

class DarkroomApp extends StatelessWidget {
  final BleService ble;

  const DarkroomApp({super.key, required this.ble});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Darkroom Timer',
      debugShowCheckedModeBanner: false,
      theme: buildDarkroomTheme(),
      // Generalization (v0.2), both device-independence concerns handled
      // in one global `builder` so every route (home screen + the settings
      // screen pushed on top of it) gets the same treatment without
      // duplicating either check per-screen:
      builder: (context, child) {
        // 1. Clamp the system/accessibility font-scale factor to 1.0.
        //    This app's buttons and time readouts already self-scale via
        //    `FittedBox` to fill whatever space they get (see
        //    ExposureButton/TimeDisplay) — that's the actual accessibility
        //    win here (huge, high-contrast, glanceable-in-the-dark
        //    controls), not the system text-size slider. Letting a large
        //    accessibility font-scale setting *additionally* inflate our
        //    already-FittedBox-scaled text on top of that risks overflow
        //    in the fixed-height grid cells instead of helping anyone.
        // 2. `OrientationGate`: show a rotate-prompt instead of the grid
        //    whenever the OS hands us a portrait viewport despite our
        //    landscape lock request (foldables, multi-window, ...).
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: const TextScaler.linear(1.0)),
          child: OrientationGate(child: child!),
        );
      },
      home: HomeScreen(ble: ble),
    );
  }
}
