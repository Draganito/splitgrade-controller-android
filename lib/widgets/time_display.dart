import 'package:flutter/material.dart';
import '../theme/darkroom_theme.dart';

/// Shows a seconds value ("Hard"/"Soft" exposure time), 0.5s granularity,
/// up to 999s per spec. Purely presentational — value lives in the parent.
class TimeDisplay extends StatelessWidget {
  final double seconds;
  final String label;

  const TimeDisplay({super.key, required this.seconds, required this.label});

  String get _formatted {
    // 0.5s steps -> always exactly one decimal place, e.g. "12.5", "7.0".
    return seconds.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: DarkroomColors.dimRed, width: 1.5),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: DarkroomColors.dimRed,
                fontSize: 14,
              ),
            ),
            Text(
              '${_formatted}s',
              style: const TextStyle(
                color: DarkroomColors.red,
                fontSize: 36,
                fontWeight: FontWeight.bold,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
