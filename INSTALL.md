# Install miluka Splitgrade Controller (Android)

You do **not** need Flutter. Sideload the APK from
[Releases](https://github.com/Draganito/splitgrade-controller-android/releases).

Needs a real phone or tablet, **Android 8.0** or newer. Emulator BLE is
unreliable. The enlarger head must already be flashed
([FLASH.md](https://github.com/Draganito/darkroom-enlarger-head/blob/main/FLASH.md)).

This APK is a hobby beta, signed with a debug key — not a Play Store
build.

## From Debian, onto the phone

1. Plug the phone in over USB. Unlock it and allow file transfer.
2. Copy the APK to Downloads:

   ```bash
   cp miluka-splitgrade-controller-0.2.1.apk /media/$USER/*/Download/
   ```

   (or use the Files window that appears when the phone is mounted.)

3. On the phone, open the APK. Allow install from that source if Android
   asks.
4. Open **miluka Splitgrade Controller**. Allow Bluetooth / nearby
   devices when asked.
5. Power the enlarger head. Do **not** pair `DarkroomTimer` in Android
   Bluetooth settings — that breaks the app. Open the app, hold
   **Focus** for 3 seconds → **Einstellungen** → **Geräte suchen** → tap
   **DarkroomTimer**.

## After connect

Defaults are already **109 LEDs / GPIO 5** (MILUKA Aristo D2). Change
them only for a different panel, then **Save**.

## Build from source (optional)

```bash
flutter pub get
flutter build apk --release
```
