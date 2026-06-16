import 'package:flutter/material.dart';
import '../../core/core.dart';
import 'quick_action_button.dart';

/// Model for a single quick-action entry.
class QuickActionItem {
  const QuickActionItem({required this.label, this.onTap});
  final String label;
  final VoidCallback? onTap;
}

/// "Quick Actions" section with a header row ("Quick Actions" + "View All")
/// and a responsive 3-column grid of [QuickActionButton]s.
class QuickActionsSection extends StatelessWidget {
  const QuickActionsSection({
    super.key,
    required this.actions,
    this.onViewAll,
  });

  final List<QuickActionItem> actions;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header row ────────────────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
            ),
            GestureDetector(
              onTap: onViewAll,
              child: Text(
                'View All',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color      : AppTheme.textDark,
                      fontWeight : FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ── 3-column responsive grid ──────────────────────────────────────────
        LayoutBuilder(
          builder: (context, constraints) {
            const columns   = 3;
            const spacing   = 12.0;
            final itemWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;

            // Build rows of 3
            final rows = <Widget>[];
            for (var i = 0; i < actions.length; i += columns) {
              final rowItems = actions.skip(i).take(columns).toList();
              rows.add(
                Row(
                  children: [
                    for (var j = 0; j < rowItems.length; j++) ...[
                      if (j > 0) const SizedBox(width: spacing),
                      SizedBox(
                        width  : itemWidth,
                        child  : QuickActionButton(
                          label : rowItems[j].label,
                          onTap : rowItems[j].onTap,
                        ),
                      ),
                    ],
                    // Fill remaining space if row is not full
                    if (rowItems.length < columns)
                      for (var k = rowItems.length; k < columns; k++) ...[
                        const SizedBox(width: spacing),
                        SizedBox(width: itemWidth),
                      ],
                  ],
                ),
              );
              if (i + columns < actions.length) {
                rows.add(const SizedBox(height: spacing));
              }
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rows,
            );
          },
        ),
      ],
    );
  }
}
