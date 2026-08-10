import 'dart:async';

import 'package:flutter/material.dart';

import '../ble/ble_service.dart';
import '../theme/darkroom_theme.dart';
import '../widgets/exposure_button.dart';
import '../widgets/time_display.dart';
import 'settings_sheet.dart';

const double _stepSeconds = 0.5;
const double _maxSeconds = 999;
const Duration _settingsHoldDuration = Duration(seconds: 3);

/// Main (and only visible) screen. 2 rows x 3 columns per spec:
///   Hard+   Soft+   Focus
///   [hard time] [soft time] [ ]
///   Hard-   Soft-   Expose
class HomeScreen extends StatefulWidget {
  final BleService ble;

  const HomeScreen({super.key, required this.ble});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double _hardSeconds = 0;
  double _softSeconds = 0;
  Timer? _focusHoldTimer;
  bool _focusMenuTriggered = false;

  bool get _exposing =>
      widget.ble.exposureState == ExposureState.hard ||
      widget.ble.exposureState == ExposureState.soft;

  void _adjust(bool hard, double delta) {
    if (_exposing) return;
    setState(() {
      if (hard) {
        _hardSeconds = (_hardSeconds + delta).clamp(0, _maxSeconds);
      } else {
        _softSeconds = (_softSeconds + delta).clamp(0, _maxSeconds);
      }
    });
  }

  void _expose() {
    if (_exposing) return;
    widget.ble.sendExpose(hardSeconds: _hardSeconds, softSeconds: _softSeconds);
  }

  // Focus button: tap = toggle the white focus light on/off (stays on until
  // tapped again — changed 2026-07-27 from the previous hold-to-light
  // behavior per Dragan's request). Holding for 3s still opens the hidden
  // settings menu instead (and turns the light back off first if it was on,
  // since you're configuring, not focusing).
  void _onFocusDown(TapDownDetails _) {
    if (_exposing) return;
    _focusMenuTriggered = false;
    _focusHoldTimer = Timer(_settingsHoldDuration, () {
      _focusMenuTriggered = true;
      if (widget.ble.exposureState == ExposureState.focus) {
        widget.ble.sendFocus(false);
      }
      _openSettings();
    });
  }

  void _onFocusUp(TapUpDetails _) {
    _focusHoldTimer?.cancel();
    if (_focusMenuTriggered) return;
    // Quick tap (didn't reach the 3s settings threshold): toggle based on
    // the device's own last-reported state.
    widget.ble.sendFocus(widget.ble.exposureState != ExposureState.focus);
  }

  void _onFocusCancel() {
    // Gesture aborted (e.g. finger dragged off the button) — just cancel
    // the pending settings-menu timer, no light change either way.
    _focusHoldTimer?.cancel();
  }

  void _openSettings() {
    // Full-screen route, not a modal overlay — see settings_sheet.dart doc
    // comment. Gives a real back button (AppBar) instead of swipe-to-dismiss.
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => SettingsSheet(ble: widget.ble)));
  }

  @override
  void dispose() {
    _focusHoldTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DarkroomColors.background,
      body: SafeArea(
        // Guards against display cutouts/notches in landscape on devices
        // this app hasn't been physically tested on — immersiveSticky mode
        // (see main.dart) hides the system status/nav bars, but a camera
        // cutout or rounded-corner inset is a display-shape property, not
        // "system UI", and isn't guaranteed to be avoided by that alone.
        child: ListenableBuilder(
          listenable: widget.ble,
          builder: (context, _) {
            final enabled = !_exposing;
            return LayoutBuilder(
              builder: (context, constraints) {
                // Generalization (v0.2): spacing used to be fixed dp values
                // (12/6/4) tuned by eye on one phone. Scaling them off the
                // smaller screen dimension keeps proportions sane from a
                // small multi-window strip up to a large tablet, instead of
                // looking cramped (tiny gaps swallowed by huge buttons) or
                // wasteful (huge gaps on a small screen) at either extreme.
                final shortSide = constraints.biggest.shortestSide;
                final outerPad = (shortSide * 0.025).clamp(8.0, 20.0);
                final gap = (shortSide * 0.015).clamp(4.0, 12.0);
                return Padding(
                  padding: EdgeInsets.all(outerPad),
                  child: Column(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            _column(
                              gap: gap,
                              top: ExposureButton(
                                label: 'Hard +',
                                enabled: enabled,
                                repeatOnHold: true,
                                onTap: () => _adjust(true, _stepSeconds),
                              ),
                              middle: TimeDisplay(
                                // While Hard is actively running, show the
                                // live countdown here instead of the fixed
                                // set value — this big display is what's
                                // actually glanced at during an exposure,
                                // not the small Expose-button label. Once
                                // Hard finishes and Soft takes over, this
                                // stays pinned at 0 (Hard is done *within
                                // this run*) rather than jumping back to
                                // the set value — that only happens once
                                // the whole Hard->Soft sequence is over and
                                // we're back at Idle.
                                seconds:
                                    widget.ble.exposureState ==
                                        ExposureState.hard
                                    ? widget.ble.remainingSeconds
                                    : widget.ble.exposureState ==
                                          ExposureState.soft
                                    ? 0
                                    : _hardSeconds,
                                label: 'HARD',
                              ),
                              bottom: ExposureButton(
                                label: 'Hard -',
                                enabled: enabled,
                                repeatOnHold: true,
                                onTap: () => _adjust(true, -_stepSeconds),
                              ),
                            ),
                            _column(
                              gap: gap,
                              top: ExposureButton(
                                label: 'Soft +',
                                enabled: enabled,
                                repeatOnHold: true,
                                onTap: () => _adjust(false, _stepSeconds),
                              ),
                              middle: TimeDisplay(
                                // Same as the Hard display above, mirrored
                                // for Soft.
                                seconds:
                                    widget.ble.exposureState ==
                                        ExposureState.soft
                                    ? widget.ble.remainingSeconds
                                    : _softSeconds,
                                label: 'SOFT',
                              ),
                              bottom: ExposureButton(
                                label: 'Soft -',
                                enabled: enabled,
                                repeatOnHold: true,
                                onTap: () => _adjust(false, -_stepSeconds),
                              ),
                            ),
                            _column(
                              gap: gap,
                              top: ExposureButton(
                                label:
                                    widget.ble.exposureState ==
                                        ExposureState.focus
                                    ? 'FOCUS'
                                    : 'Focus',
                                enabled: enabled,
                                filled:
                                    widget.ble.exposureState ==
                                    ExposureState.focus,
                                onTapDown: _onFocusDown,
                                onTapUp: _onFocusUp,
                                onTapCancel: _onFocusCancel,
                              ),
                              middle: _StatusIndicator(ble: widget.ble),
                              bottom: ExposureButton(
                                label: _exposing
                                    ? '${widget.ble.exposureState == ExposureState.hard ? "HARD" : "SOFT"} ${widget.ble.remainingSeconds.toStringAsFixed(1)}s'
                                    : 'Expose',
                                enabled: !_exposing,
                                filled: _exposing,
                                onTap: _expose,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _column({
    required Widget top,
    required Widget middle,
    required Widget bottom,
    required double gap,
  }) {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.all(gap / 2),
        child: Column(
          children: [
            Expanded(flex: 2, child: top),
            SizedBox(height: gap),
            Expanded(flex: 1, child: middle),
            SizedBox(height: gap),
            Expanded(flex: 2, child: bottom),
          ],
        ),
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  final BleService ble;

  const _StatusIndicator({required this.ble});

  @override
  Widget build(BuildContext context) {
    final connected = ble.isConnected;
    return Center(
      child: Icon(
        connected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
        color: connected ? DarkroomColors.red : DarkroomColors.dimRed,
      ),
    );
  }
}
