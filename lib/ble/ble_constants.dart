/// BLE GATT protocol constants — MUST stay in sync with the enlarger-head
/// firmware (`ble_server.h` / JSON shape in
/// https://github.com/Draganito/darkroom-enlarger-head).
library;

class BleConstants {
  BleConstants._();

  static const String deviceName = 'DarkroomTimer';

  static const String serviceUuid = 'b1a1e000-0001-4a2e-9c2a-6f1c2d3b4a10';
  static const String cmdCharUuid = 'b1a1e000-0002-4a2e-9c2a-6f1c2d3b4a10';
  static const String configCharUuid = 'b1a1e000-0003-4a2e-9c2a-6f1c2d3b4a10';
  static const String statusCharUuid = 'b1a1e000-0004-4a2e-9c2a-6f1c2d3b4a10';
}
