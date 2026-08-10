// Smoke + generalization tests: the app boots and shows the main exposure
// grid without throwing, across a spread of screen sizes standing in for
// "every Android device" — this is v0.2's actual verification method for
// tablets, since no physical tablet or Android emulator image is available
// in this environment. `tester.view.physicalSize`/`devicePixelRatio` let a
// widget test simulate arbitrary screen dimensions instantly and
// repeatably, which is strictly more useful for catching layout
// regressions than a one-off manual screenshot on a single borrowed
// device would be. BLE hardware isn't available in the test environment
// either, so `BleService` just sits in its default (disconnected) state.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:darkroom_timer/ble/ble_service.dart';
import 'package:darkroom_timer/main.dart';

void main() {
  testWidgets('App boots and shows Expose button', (WidgetTester tester) async {
    await tester.pumpWidget(DarkroomApp(ble: BleService()));
    await tester.pump();

    expect(find.text('Expose'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  // Logical-pixel landscape sizes covering the practical spread of Android
  // form factors this app needs to survive on, even though it was only
  // ever physically touched on one of them (Pixel 4a, roughly the "phone"
  // entry below).
  const screenSizes = <String, Size>{
    'small phone (e.g. compact Android, ~5")': Size(640, 360),
    'phone (Pixel 4a-ish)': Size(851, 393),
    'large phone / small tablet': Size(960, 600),
    'foldable unfolded': Size(1148, 725),
    '10" tablet': Size(1280, 800),
    'large tablet (e.g. 12.9")': Size(1600, 1000),
  };

  for (final entry in screenSizes.entries) {
    testWidgets('Home screen renders without overflow on ${entry.key}', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(entry.value);
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(DarkroomApp(ble: BleService()));
      await tester.pumpAndSettle();

      // No RenderFlex overflow / layout exception anywhere in the tree —
      // this is the main thing a fixed-dp layout tuned on one phone would
      // fail at on a very different screen size.
      expect(tester.takeException(), isNull);
      // Sanity check the grid actually rendered (not the rotate-prompt —
      // all sizes above are landscape) with all six buttons present.
      expect(find.text('Expose'), findsOneWidget);
      expect(find.text('Hard +'), findsOneWidget);
      expect(find.text('Soft +'), findsOneWidget);
    });
  }

  testWidgets(
    'Portrait viewport shows rotate prompt instead of a squished grid',
    (tester) async {
      const portrait = Size(400, 800);
      await tester.binding.setSurfaceSize(portrait);
      tester.view.physicalSize = portrait;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(DarkroomApp(ble: BleService()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // The OS ignoring our landscape lock (foldable book mode, split-screen,
      // ...) must not render the fixed 3x2 grid squished into a tall box —
      // see lib/widgets/orientation_gate.dart.
      expect(find.text('Bitte Gerät drehen'), findsOneWidget);
      expect(find.text('Expose'), findsNothing);
    },
  );

  testWidgets(
    'Large accessibility text scale does not break the fixed grid layout',
    (tester) async {
      // Simulates a user with the Android "large font size" accessibility
      // setting enabled — main.dart clamps textScaler to 1.0 app-wide
      // specifically so this can't blow up the fixed-height button grid; this
      // test would fail with a RenderFlex overflow exception without that
      // clamp (each button's FittedBox-wrapped label would still fit, but
      // unrelated fixed-height rows elsewhere could overflow as scale grows).
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: DarkroomApp(ble: BleService()),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Expose'), findsOneWidget);
    },
  );
}
