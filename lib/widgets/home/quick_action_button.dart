import 'package:flutter/material.dart';
import '../../core/core.dart';

/// A single tappable Quick-Action button.
///
/// Renders a rounded-rectangle card with a label.
/// Designed for use inside a responsive [Wrap] or grid.
class QuickActionButton extends StatelessWidget {
  const QuickActionButton({
    super.key,
    required this.label,
    this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color         : AppTheme.cardBg,
      borderRadius  : BorderRadius.circular(14),
      child: InkWell(
        onTap        : onTap,
        borderRadius : BorderRadius.circular(14),
        splashColor  : AppTheme.primary.withValues(alpha: 0.08),
        child: Container(
          // Fill parent width (controlled by LayoutBuilder in parent)
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
          alignment: Alignment.center,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize        : 14,
                  fontWeight      : FontWeight.w600,
                  color           : AppTheme.textDark,
                  letterSpacing   : 0.1,
                ),
          ),
        ),
      ),
    );
  }
}
