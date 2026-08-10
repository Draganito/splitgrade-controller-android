/// Mirrors the firmware's `DeviceConfig` (led count + GPIO pin).
/// Held locally in [BleService] and only written over BLE when the user
/// taps the explicit "Save" button in the hidden settings menu.
class DeviceConfig {
  final int ledCount;
  final int gpioPin;

  const DeviceConfig({required this.ledCount, required this.gpioPin});

  // Matches firmware defaults (ConfigStore::kDefaultLedCount / kDefaultGpioPin)
  // used only until the real value is read back from the device.
  factory DeviceConfig.defaults() =>
      const DeviceConfig(ledCount: 99, gpioPin: 4);

  DeviceConfig copyWith({int? ledCount, int? gpioPin}) => DeviceConfig(
    ledCount: ledCount ?? this.ledCount,
    gpioPin: gpioPin ?? this.gpioPin,
  );

  Map<String, dynamic> toJson() => {'led_count': ledCount, 'gpio': gpioPin};
}
