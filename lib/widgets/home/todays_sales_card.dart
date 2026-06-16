import 'package:flutter/material.dart';
import '../../core/core.dart';
import '../sales_bar_chart.dart';

/// The prominent "Today's Sales" hero card.
///
/// Displays:
///   • Section label
///   • Large rupee amount
///   • Comparison note with yesterday
///   • Decorative bar chart on the right
class TodaysSalesCard extends StatelessWidget {
  const TodaysSalesCard({
    super.key,
    required this.amount,
    required this.delta,
  });

  /// Formatted amount string, e.g. "₹28,450"
  final String amount;

  /// Signed delta text, e.g. "+12.5 from yesterday"
  final String delta;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Left: text block ─────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Today's Sales",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textMid,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    amount,
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textDark,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    delta,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.positive,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ),

            // ── Right: decorative bar chart ───────────────────────────────────
            const SalesBarChart(),
          ],
        ),
      ),
    );
  }
}
