/// Mirrors the firmware's `DeviceConfig` (led count + GPIO pin).
/// Held locally in [BleService] and only written over BLE when the user
/// taps the explicit "Save" button in the hidden settings menu.
class DeviceConfig {
  final int ledCount;
  final int gpioPin;

  const DeviceConfig({required this.ledCount, required this.gpioPin});

  // Matches firmware defaults (ConfigStore::kDefaultLedCount / kDefaultGpioPin)
  // for the MILUKA Aristo D2 panel (109× SK6812RGBW, XIAO D4 / GPIO 5).
  factory DeviceConfig.defaults() =>
      const DeviceConfig(ledCount: 109, gpioPin: 5);

  DeviceConfig copyWith({int? ledCount, int? gpioPin}) => DeviceConfig(
    ledCount: ledCount ?? this.ledCount,
    gpioPin: gpioPin ?? this.gpioPin,
  );

  Map<String, dynamic> toJson() => {'led_count': ledCount, 'gpio': gpioPin};
}
