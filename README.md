# miluka Splitgrade Controller

Android companion app for the open-source **splitgrade** enlarger LED head:
connects over **Bluetooth LE**, sets hard/soft exposure times, and runs
exposures — no light sensor required. On-device name:
**miluka Splitgrade Controller**.

Pairs with the shared head firmware:
[darkroom-enlarger-head](https://github.com/Draganito/darkroom-enlarger-head)
(Seeed XIAO ESP32-S3 + SK6812RGBW panel).

**License: [MIT](LICENSE)** — Copyright © 2026 Dragan Bojovic.

## Start here

Do not install Flutter for a first try. Grab the APK from
**[Releases](https://github.com/Draganito/splitgrade-controller-android/releases)**
and follow **[INSTALL.md](INSTALL.md)** (copy onto the phone from Debian,
sideload, connect to `DarkroomTimer`).

Flash the head first:
[FLASH.md](https://github.com/Draganito/darkroom-enlarger-head/blob/main/FLASH.md).

## What this is

| | |
|---|---|
| **Platform** | Android (`minSdk 26`), phones and tablets |
| **Link** | BLE GATT (JSON commands) |
| **Role** | Budget-tier controller — phone you already own |
| **Package** | `com.dragan.darkroom_timer` |

This is the cheap half of the two-tier design: the same enlarger head also
speaks ESP-NOW for a SenseCAP primary-tier controller with sensors
([splitgrade-controller-sensecap](https://github.com/Draganito/splitgrade-controller-sensecap)).
The head firmware is shared; only the remote changes.

## Beta scope

**For:** darkroom hobbyists with an Android phone/tablet and a flashed
enlarger-head board.

**Includes:** BLE scan/connect, focus / expose UI, hard & soft times,
hidden LED config (pixel count + GPIO), wake-lock during exposure, a
sideload APK on GitHub Releases.

**Not this repo:** ESP32 firmware, SenseCAP UI, panel Gerbers, Play Store
release signing. Emulator BLE is unreliable — use a real device.

## Project layout

| Path | Role |
|------|------|
| `INSTALL.md` | Sideload the release APK (no Flutter SDK) |
| `lib/main.dart` | App entry |
| `lib/ble/ble_service.dart` | BLE + JSON protocol (must match firmware `ble_server`) |
| `lib/ble/ble_constants.dart` | Service / characteristic UUIDs |
| `lib/screens/home_screen.dart` | Focus / Expose UI |
| `lib/screens/settings_sheet.dart` | LED pin / pixel-count config |
| `lib/widgets/` | Exposure button, time display, orientation gate |
| `lib/models/device_config.dart` | LED config model |

## Status

Verified on real hardware (phones and a tablet). Needs the enlarger-head
firmware advertising as `DarkroomTimer` over BLE.

## Sibling projects

- Head firmware: https://github.com/Draganito/darkroom-enlarger-head
- SenseCAP controller: https://github.com/Draganito/splitgrade-controller-sensecap
