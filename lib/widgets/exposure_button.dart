import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/darkroom_theme.dart';

/// Big, high-contrast button for the main 2x3 grid. Deliberately oversized
/// tap target — this is operated by feel/glance in a dark room.
///
/// **Generalization note (v0.2):** the label used to be a fixed `fontSize:
/// 22`, tuned by eye on one phone (Pixel 4a). That looked comically small
/// on a 10" tablet cell and would've clipped on a tiny multi-window/
/// split-screen cell. Wrapped in `FittedBox(fit: BoxFit.contain)` instead —
/// same pattern already used by `TimeDisplay` — so the label always scales
/// to fill whatever box this button actually gets, on any screen size,
/// with zero manual breakpoints.
class ExposureButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final void Function(TapDownDetails)? onTapDown;
  final void Function(TapUpDetails)? onTapUp;
  final VoidCallback? onTapCancel;
  final bool enabled;
  final bool filled;

  /// If true, holding the button down (past a short initial delay) repeats
  /// [onTap] on an accelerating schedule instead of firing it exactly once
  /// per completed tap — added 2026-07-27 so dialing in a large value (e.g.
  /// 99s at the UI's 0.5s step size, which used to take up to 198 individual
  /// taps) is a quick press-and-hold instead. Only meant for the Hard/Soft
  /// +/- adjustment buttons; deliberately left `false` (the default) for
  /// Expose and Focus, where repeatedly re-firing the action on a hold would
  /// be actively wrong (Expose starts a real timed light sequence, Focus
  /// uses `onTapDown`/`onTapUp` directly for its own toggle/hold-for-settings
  /// logic, not `onTap` at all).
  final bool repeatOnHold;

  const ExposureButton({
    super.key,
    required this.label,
    this.onTap,
    this.onTapDown,
    this.onTapUp,
    this.onTapCancel,
    this.enabled = true,
    this.filled = false,
    this.repeatOnHold = false,
  });

  @override
  State<ExposureButton> createState() => _ExposureButtonState();
}

class _ExposureButtonState extends State<ExposureButton> {
  Timer? _repeatTimer;
  int _repeatTicks = 0;

  // Delay before the first repeat fires — long enough that a normal quick
  // tap never triggers it (that still goes through the single `onTap` call
  // in `_handleTapUp` below, exactly one step, unchanged from before).
  static const _initialDelay = Duration(milliseconds: 450);

  void _handleTapDown(TapDownDetails details) {
    widget.onTapDown?.call(details);
    if (!widget.repeatOnHold || widget.onTap == null) return;
    _repeatTicks = 0;
    _repeatTimer?.cancel();
    _repeatTimer = Timer(_initialDelay, _tick);
  }

  void _tick() {
    if (!mounted || !widget.enabled) return;
    widget.onTap?.call();
    _repeatTicks++;
    // Accelerating repeat: starts at 180ms/step, ramps down to a 35ms/step
    // floor after ~18 ticks (~2s of continuous holding). Lets you dial a
    // big value (e.g. 0 -> 99s at the 0.5s step size) in well under 10s of
    // holding, while the first second or so still feels controllable for
    // small nudges.
    final delayMs = (180 - _repeatTicks * 8).clamp(35, 180);
    _repeatTimer = Timer(Duration(milliseconds: delayMs), _tick);
  }

  void _stopRepeating() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }

  void _handleTapUp(TapUpDetails details) {
    final wasRepeating = _repeatTicks > 0;
    _stopRepeating();
    // Quick tap that never reached the repeat threshold: fire exactly once,
    // same as the plain `onTap` path did before this change. If we were
    // already repeating, `_tick` already fired `onTap` the right number of
    // times — don't add an extra step on release.
    if (widget.repeatOnHold && widget.onTap != null && !wasRepeating) {
      widget.onTap!();
    }
    widget.onTapUp?.call(details);
  }

  void _handleTapCancel() {
    _stopRepeating();
    widget.onTapCancel?.call();
  }

  @override
  void dispose() {
    _repeatTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.enabled ? DarkroomColors.red : DarkroomColors.dimRed;
    return GestureDetector(
      // For repeatOnHold buttons, `onTap` is driven entirely by
      // `_handleTapDown`/`_handleTapUp` above instead of GestureDetector's
      // own tap recognizer, so a long hold+release doesn't *also* fire a
      // final extra `onTap` on top of the repeats. Non-repeating buttons
      // (Expose) keep the original direct wiring, completely unchanged.
      onTap: widget.enabled && !widget.repeatOnHold ? widget.onTap : null,
      onTapDown: widget.enabled ? _handleTapDown : null,
      onTapUp: widget.enabled ? _handleTapUp : null,
      onTapCancel: widget.enabled ? _handleTapCancel : null,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: widget.filled && widget.enabled
              ? DarkroomColors.red
              : DarkroomColors.background,
          border: Border.all(color: color, width: 3),
        ),
        child: FittedBox(
          fit: BoxFit.contain,
          child: Text(
            widget.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: widget.filled && widget.enabled
                  ? DarkroomColors.background
                  : color,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
