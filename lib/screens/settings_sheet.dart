import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../ble/ble_service.dart';
import '../models/device_config.dart';
import '../theme/darkroom_theme.dart';

/// Hidden settings screen — opened by holding "Focus" for 3s (see
/// home_screen). BLE pairing + LED count / GPIO pin. Nothing is sent to the
/// ESP32 until the user taps "Save" (spec requirement — no writes on every
/// keystroke).
///
/// Full-screen route (pushed via `Navigator.push`, not a modal bottom sheet)
/// so it fully replaces the timer UI instead of overlaying it, with a
/// regular AppBar back button to return. Every row uses its natural
/// (compact) height instead of `Expanded`, so with the keyboard closed the
/// whole screen — including the Save button — already fits without any
/// scrolling. The content still sits inside a `SingleChildScrollView` purely
/// as a safety net for the on-screen keyboard: Flutter auto-scrolls a
/// focused `TextField` into view within its nearest `Scrollable` ancestor,
/// which matters here because the numeric keyboard covers roughly the
/// bottom half of the screen in landscape.
class SettingsSheet extends StatefulWidget {
  final BleService ble;

  const SettingsSheet({super.key, required this.ble});

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  late TextEditingController _ledCountCtrl;
  late TextEditingController _gpioCtrl;

  @override
  void initState() {
    super.initState();
    _ledCountCtrl = TextEditingController(
      text: widget.ble.config.ledCount.toString(),
    );
    _gpioCtrl = TextEditingController(
      text: widget.ble.config.gpioPin.toString(),
    );
  }

  @override
  void dispose() {
    _ledCountCtrl.dispose();
    _gpioCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final ledCount = int.tryParse(_ledCountCtrl.text);
    final gpio = int.tryParse(_gpioCtrl.text);
    if (ledCount == null || gpio == null) return;
    await widget.ble.saveConfig(
      DeviceConfig(ledCount: ledCount, gpioPin: gpio),
    );
    // `saveConfig` catches its own errors into `ble.lastError` rather than
    // throwing, so only leave the screen if it actually succeeded.
    if (mounted && widget.ble.lastError == null) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DarkroomColors.background,
      appBar: AppBar(
        backgroundColor: DarkroomColors.background,
        foregroundColor: DarkroomColors.red,
        elevation: 0,
        title: const Text('Einstellungen'),
      ),
      body: SafeArea(
        // Same cutout/gesture-inset guard as home_screen.dart — the AppBar
        // already accounts for the top inset, this covers left/right/
        // bottom on devices with landscape display cutouts.
        child: ListenableBuilder(
          listenable: widget.ble,
          builder: (context, _) {
            final ble = widget.ble;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    ble.isConnected
                        ? 'Verbunden: ${ble.connectedDeviceName}'
                        : 'Nicht verbunden',
                    style: const TextStyle(color: DarkroomColors.red),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: ble.isScanning
                              ? null
                              : () => ble.startScan(),
                          child: Text(
                            ble.isScanning ? 'Suche...' : 'Geräte suchen',
                          ),
                        ),
                      ),
                      if (ble.isConnected) ...[
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () => ble.disconnect(),
                          child: const Text('Trennen'),
                        ),
                      ],
                    ],
                  ),
                  // Only takes up space while there's something to show, so it
                  // never pushes the LED/GPIO fields or Save button down when
                  // empty (the common case once a device is already paired).
                  ...ble.scanResults.map(
                    (r) => _DeviceRow(result: r, ble: ble),
                  ),
                  const Divider(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _configField(
                          label: 'LED-Anzahl',
                          controller: _ledCountCtrl,
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: _configField(
                          label: 'GPIO-Pin (DATA -> Pegelwandler)',
                          controller: _gpioCtrl,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (ble.lastError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        ble.lastError!,
                        style: const TextStyle(color: DarkroomColors.red),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ElevatedButton(
                    onPressed: ble.isConnected ? _save : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DarkroomColors.red,
                      foregroundColor: DarkroomColors.background,
                    ),
                    child: const Text('Save'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _configField({
    required String label,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(color: DarkroomColors.red)),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: DarkroomColors.red),
          decoration: const InputDecoration(
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: DarkroomColors.red),
            ),
            isDense: true,
          ),
        ),
      ],
    );
  }
}

class _DeviceRow extends StatelessWidget {
  final ScanResult result;
  final BleService ble;

  const _DeviceRow({required this.result, required this.ble});

  @override
  Widget build(BuildContext context) {
    final name = result.device.platformName.isNotEmpty
        ? result.device.platformName
        : result.device.remoteId.str;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: OutlinedButton(
        onPressed: () => ble.connect(result.device),
        child: Row(
          children: [
            const Icon(Icons.bluetooth, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(name)),
            Text('${result.rssi} dBm'),
          ],
        ),
      ),
    );
  }
}
