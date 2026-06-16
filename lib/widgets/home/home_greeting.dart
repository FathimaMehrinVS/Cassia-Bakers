import 'package:flutter/material.dart';

/// The greeting block shown at the top of the home screen.
///
/// Renders:
///   "Good Morning 👋,"   (regular weight)
///   "Admin"              (bold, slightly larger)
class HomeGreeting extends StatelessWidget {
  const HomeGreeting({
    super.key,
    required this.greeting,
    required this.userName,
  });

  /// e.g. "Good Morning 👋,"
  final String greeting;

  /// e.g. "Admin"
  final String userName;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greeting,
          style: tt.bodyLarge?.copyWith(fontSize: 15, height: 1.4),
        ),
        Text(
          userName,
          style: tt.titleLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
