import 'package:flutter/material.dart';
import '../../core/core.dart';

/// A compact stat card used in the summary row.
///
/// Shows:
///   • [label]  – small grey caption above
///   • [value]  – large bold figure below
class StatSummaryCard extends StatelessWidget {
  const StatSummaryCard({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textMid,
                      height: 1.3,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
