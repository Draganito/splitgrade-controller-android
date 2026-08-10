import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/device_config.dart';
import 'ble_constants.dart';

/// Mirrors the firmware's `ExposureState` (see esp32_firmware_v0.2/exposure_controller.h).
enum ExposureState { idle, hard, soft, focus }

ExposureState _parseState(String s) {
  switch (s) {
    case 'hard':
      return ExposureState.hard;
    case 'soft':
      return ExposureState.soft;
    case 'focus':
      return ExposureState.focus;
    default:
      return ExposureState.idle;
  }
}

/// Single BLE connection manager for the whole app. No BLoC/GetX — just a
/// plain [ChangeNotifier] driven by Flutter's own [ListenableBuilder], kept
/// deliberately small and readable.
///
/// Connection strategy ("stable ... automatische Hintergrund-Wiederverbindung"):
///  1. First connect from the settings menu uses a fast direct connection.
///  2. The device id is remembered (SharedPreferences); on next app start we
///     try to reconnect automatically.
///  3. If the link drops unexpectedly (out of range, ESP32 reset, ...), we
///     hand off to flutter_blue_plus' `autoConnect: true`, which uses the
///     OS-level background scan/reconnect — no polling loop of our own.
class BleService extends ChangeNotifier {
  static const _prefsDeviceIdKey = 'last_device_id';

  BluetoothDevice? _device;
  BluetoothCharacteristic? _cmdChar;
  BluetoothCharacteristic? _configChar;
  BluetoothCharacteristic? _statusChar;

  StreamSubscription<BluetoothConnectionState>? _connSub;
  StreamSubscription<List<int>>? _statusSub;
  StreamSubscription<List<ScanResult>>? _scanSub;

  // Local, symbolic countdown ticker (see "Countdown ticker" section
  // below) — the firmware only pushes a fresh STATUS notify on *phase
  // change* (see esp32_firmware_v0.2's `notifyStatusIfChanged`), not
  // periodically, so without this the displayed `remainingSeconds` would
  // just sit frozen at whatever value arrived when the phase started.
  Timer? _countdownTimer;
  double _anchorRemaining = 0;
  DateTime? _anchorAt;

  bool _userInitiatedDisconnect = false;
  // Guards the auto-reconnect-on-drop logic below. Deliberately NOT the same
  // as `isConnected`: flutter_blue_plus' `device.connectionState` stream
  // replays a synthetic "disconnected" as its *initial* value the instant
  // you subscribe (see `newStreamWithInitialValue` in bluetooth_device.dart)
  // -- even before `connect()` was ever called. Without this guard, that
  // synthetic event looked just like a real drop, so `_onConnectionStateChanged`
  // called `_connectTo()` again, which subscribed a *new* listener, which
  // replayed *another* synthetic "disconnected", recursing without bound —
  // an infinite loop that pegged the CPU at 100%, exhausted the Dart heap,
  // and froze the whole app (Android ANR). Only real "connected" events may
  // set this true; it's cleared right before we react to a drop so the new
  // listener's replay can't re-trigger the same recursion.
  bool _hasBeenConnected = false;

  bool isScanning = false;
  bool isConnected = false;
  String? connectedDeviceName;
  List<ScanResult> scanResults = [];

  DeviceConfig config = DeviceConfig.defaults();
  ExposureState exposureState = ExposureState.idle;
  double remainingSeconds = 0;
  String? lastError;

  /// Call once at app startup; tries to silently reconnect to whichever
  /// device was paired last, if any.
  Future<void> tryAutoReconnect() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_prefsDeviceIdKey);
    if (id == null) return;
    try {
      final device = BluetoothDevice.fromId(id);
      await _connectTo(device, direct: true);
    } catch (_) {
      // Device not reachable right now — fine, user can open the settings
      // menu and pick it manually, or it may still auto-connect later via
      // the OS background scan started in _connectTo.
    }
  }

  Future<void> startScan() async {
    scanResults = [];
    isScanning = true;
    lastError = null;
    notifyListeners();
    _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      scanResults = results;
      notifyListeners();
    });
    try {
      await FlutterBluePlus.startScan(
        withServices: [Guid(BleConstants.serviceUuid)],
        timeout: const Duration(seconds: 10),
      );
    } catch (e) {
      // Most commonly: BLUETOOTH_SCAN permission denied, or adapter is off.
      // Must not leave isScanning stuck true (button would be disabled
      // forever) — always fall through to the reset below.
      lastError = 'Suche fehlgeschlagen: $e';
    } finally {
      isScanning = false;
      notifyListeners();
    }
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    isScanning = false;
    notifyListeners();
  }

  Future<void> connect(BluetoothDevice device) =>
      _connectTo(device, direct: true);

  Future<void> _connectTo(
    BluetoothDevice device, {
    required bool direct,
  }) async {
    _device = device;
    _userInitiatedDisconnect = false;
    // Always start clean: on a fresh manual connect (or reconnect after a
    // prior manual disconnect), the *new* listener below will replay
    // whatever's cached, and we must not mistake that replay for a drop
    // worth auto-reconnecting from (see `_hasBeenConnected` doc comment).
    _hasBeenConnected = false;

    _connSub?.cancel();
    _connSub = device.connectionState.listen(_onConnectionStateChanged);

    try {
      await device.connect(
        license: License.nonprofit,
        autoConnect: !direct,
        // MTU is requested ourselves in `_onConnectionStateChanged` instead
        // of here -- flutter_blue_plus only lets `connect(mtu: ...)` request
        // it for *direct* connections (mtu+autoConnect are asserted
        // incompatible), so after an autoConnect-based reconnect (unexpected
        // drop -> `_connectTo(direct:false)`) the link would otherwise be
        // stuck at the default 23-byte ATT MTU. Our JSON commands (e.g.
        // `{"cmd":"focus","on":true}` = 25 bytes) don't fit in that
        // default's 20-byte payload and every write would fail with
        // "data longer than allowed" until the app was killed and
        // relaunched (forcing a fresh direct connect). Requesting it
        // ourselves after *every* connect, regardless of path, fixes that.
        mtu: null,
        timeout: const Duration(seconds: 12),
      );
    } on Exception catch (e) {
      lastError = 'Verbindung fehlgeschlagen: $e';
      notifyListeners();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsDeviceIdKey, device.remoteId.str);
  }

  Future<void> _onConnectionStateChanged(BluetoothConnectionState state) async {
    if (state == BluetoothConnectionState.connected) {
      _hasBeenConnected = true;
      isConnected = true;
      connectedDeviceName = _device?.platformName.isNotEmpty == true
          ? _device!.platformName
          : BleConstants.deviceName;
      lastError = null;
      notifyListeners();
      try {
        // See the long comment on `connect(mtu: null)` above -- must happen
        // on every connection (direct or auto-reconnected), not just once.
        await _device!.requestMtu(512);
      } catch (_) {
        // Non-fatal: some stacks/OS versions may reject or no-op this: the
        // BLE server will just work with whatever the default MTU allows.
      }
      await _discoverAndSubscribe();
    } else if (state == BluetoothConnectionState.disconnected) {
      isConnected = false;
      // No more STATUS notifies coming until reconnected — stop
      // extrapolating a countdown from a now-stale anchor.
      _stopCountdownTicker();
      notifyListeners();
      // Only treat this as a real drop worth reconnecting from if we were
      // actually connected before -- see `_hasBeenConnected` doc comment.
      if (_hasBeenConnected && !_userInitiatedDisconnect && _device != null) {
        _hasBeenConnected = false;
        // Unexpected drop -> hand off to OS-level background reconnect.
        unawaited(_connectTo(_device!, direct: false));
      }
    }
  }

  Future<void> _discoverAndSubscribe() async {
    if (_device == null) return;
    final services = await _device!.discoverServices();
    final service = services.firstWhere(
      (s) => s.uuid == Guid(BleConstants.serviceUuid),
      orElse: () => throw Exception('DarkroomTimer service not found'),
    );
    _cmdChar = service.characteristics.firstWhere(
      (c) => c.uuid == Guid(BleConstants.cmdCharUuid),
    );
    _configChar = service.characteristics.firstWhere(
      (c) => c.uuid == Guid(BleConstants.configCharUuid),
    );
    _statusChar = service.characteristics.firstWhere(
      (c) => c.uuid == Guid(BleConstants.statusCharUuid),
    );

    await _statusChar!.setNotifyValue(true);
    _statusSub?.cancel();
    _statusSub = _statusChar!.onValueReceived.listen(_onStatusReceived);

    // Pull whatever the device currently has staged, so the UI reflects
    // real hardware state after a (re)connect rather than app defaults.
    try {
      final raw = await _configChar!.read();
      final map = jsonDecode(utf8.decode(raw)) as Map<String, dynamic>;
      config = DeviceConfig(
        ledCount: map['led_count'] as int? ?? config.ledCount,
        gpioPin: map['gpio'] as int? ?? config.gpioPin,
      );
      notifyListeners();
    } catch (_) {
      // Firmware CONFIG characteristic is write+read; if read ever fails
      // (e.g. older firmware), just keep local defaults — non-fatal.
    }
  }

  void _onStatusReceived(List<int> bytes) {
    if (bytes.isEmpty) return;
    try {
      final map = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      exposureState = _parseState(map['state'] as String? ?? 'idle');
      remainingSeconds = (map['remaining'] as num?)?.toDouble() ?? 0;
      // Re-anchor the local countdown to this fresh, authoritative value —
      // resyncs on every real phase change so drift never accumulates
      // across Hard -> Soft -> Idle.
      _anchorRemaining = remainingSeconds;
      _anchorAt = DateTime.now();
      if (exposureState == ExposureState.hard ||
          exposureState == ExposureState.soft) {
        _startCountdownTicker();
      } else {
        // Idle/Focus/meter states never count down (steady or zero) —
        // nothing to interpolate, and stopping avoids pointless ticks.
        _stopCountdownTicker();
      }
      notifyListeners();
    } catch (_) {
      // malformed notification — ignore, next one will correct state
    }
  }

  // Ticks 10x/second, purely client-side, extrapolating from the last real
  // STATUS notify's (remaining, timestamp) anchor. This is deliberately
  // symbolic, not authoritative — the ESP32 alone drives the actual
  // exposure via its own millis()-based state machine (fire-and-forget,
  // see ../esp32_firmware_v0.2/MEMORY.md); the phone doesn't need to stay
  // connected for the exposure to finish correctly, this just makes the
  // on-screen number count down smoothly instead of sitting frozen
  // between the sparse phase-change notifies.
  void _startCountdownTicker() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final anchorAt = _anchorAt;
      if (anchorAt == null) return;
      final elapsed = DateTime.now().difference(anchorAt).inMilliseconds / 1000;
      final next = (_anchorRemaining - elapsed).clamp(0.0, _anchorRemaining);
      if (next == remainingSeconds) return;
      remainingSeconds = next;
      notifyListeners();
    });
  }

  void _stopCountdownTicker() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  Future<void> disconnect() async {
    _userInitiatedDisconnect = true;
    await _device?.disconnect();
  }

  Future<void> _writeCmd(Map<String, dynamic> payload) async {
    if (_cmdChar == null) {
      lastError = 'Befehl nicht gesendet: keine BLE-Verbindung';
      notifyListeners();
      return;
    }
    try {
      await _cmdChar!.write(
        utf8.encode(jsonEncode(payload)),
        withoutResponse: false,
      );
    } catch (e) {
      lastError = 'Befehl nicht gesendet: $e';
      notifyListeners();
    }
  }

  Future<void> sendExpose({
    required double hardSeconds,
    required double softSeconds,
  }) => _writeCmd({'cmd': 'expose', 'hard': hardSeconds, 'soft': softSeconds});

  Future<void> sendFocus(bool on) => _writeCmd({'cmd': 'focus', 'on': on});

  Future<void> sendStop() => _writeCmd({'cmd': 'stop'});

  /// Only call this from the explicit "Save" button — never on every
  /// settings-menu keystroke (firmware persists to flash on every call).
  Future<void> saveConfig(DeviceConfig newConfig) async {
    if (_configChar == null) {
      lastError = 'Konfiguration nicht gespeichert: keine BLE-Verbindung';
      notifyListeners();
      return;
    }
    try {
      await _configChar!.write(
        utf8.encode(jsonEncode(newConfig.toJson())),
        withoutResponse: false,
      );
    } catch (e) {
      lastError = 'Konfiguration nicht gespeichert: $e';
      notifyListeners();
      return;
    }
    config = newConfig;
    notifyListeners();
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _statusSub?.cancel();
    _scanSub?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }
}
