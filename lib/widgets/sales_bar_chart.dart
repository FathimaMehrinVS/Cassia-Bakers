import 'package:flutter/material.dart';
import '../../core/core.dart';

/// Mini bar-chart illustration used inside the Today's Sales card.
/// Draws 5 bars of varying heights, purely decorative.
class SalesBarChart extends StatelessWidget {
  const SalesBarChart({super.key});

  static const List<double> _heights = [0.4, 0.65, 0.55, 0.85, 0.70];
  static const double _barWidth = 10;
  static const double _gap      = 5;
  static const double _maxH     = 52;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: _heights
          .map(
            (ratio) => Container(
              width : _barWidth,
              height: _maxH * ratio,
              margin: const EdgeInsets.only(left: _gap),
              decoration: BoxDecoration(
                color        : AppTheme.textMid,
                borderRadius : BorderRadius.circular(3),
              ),
            ),
          )
          .toList(),
    );
  }
}
