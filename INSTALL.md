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
   cp miluka-splitgrade-controller-0.2.0.apk /media/$USER/*/Download/
   ```

   (or use the Files window that appears when the phone is mounted.)

3. On the phone, open the APK. Allow install from that source if Android
   asks.
4. Open **miluka Splitgrade Controller**. Allow Bluetooth / nearby
   devices when asked.
5. Power the enlarger head. Connect to **DarkroomTimer**.

## After connect

Hold **Focus** for 3 seconds to open **Einstellungen**. Set LED count and
GPIO to match your panel (see the head
[FLASH.md](https://github.com/Draganito/darkroom-enlarger-head/blob/main/FLASH.md)
§4), then **Save**.

## Build from source (optional)

```bash
flutter pub get
flutter build apk --release
```
