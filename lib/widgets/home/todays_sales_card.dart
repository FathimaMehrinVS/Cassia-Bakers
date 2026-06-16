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
    required this.selectedDate,
    required this.onDateChanged,
  });

  /// Formatted amount string, e.g. "₹28,450"
  final String amount;

  /// Signed delta text, e.g. "+12.5 from yesterday"
  final String delta;

  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday = selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final dateFormatted = "${selectedDate.day} ${months[selectedDate.month - 1]} ${selectedDate.year}";

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Left: text block ─────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isToday ? "Today's Sales" : "Sales for $dateFormatted",
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textMid,
                                fontSize: 20,
                              ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: AppTheme.primary,
                                    onPrimary: Colors.white,
                                    onSurface: AppTheme.textDark,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            onDateChanged(picked);
                          }
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: const Padding(
                          padding: EdgeInsets.all(6.0),
                          child: Icon(
                            Icons.calendar_today_outlined,
                            size: 24,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    amount,
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textDark,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    delta,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: delta.startsWith('-') ? Colors.red[800] : Colors.green[800],
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
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
