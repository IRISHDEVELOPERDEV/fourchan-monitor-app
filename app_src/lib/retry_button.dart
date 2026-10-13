import 'package:flutter/material.dart';

/// "Retry" for a screen's error state. Uses the same OutlinedButton.icon style
/// the app already uses for its secondary actions (e.g. the Archive's
/// "Try the full external archives").
class RetryButton extends StatelessWidget {
  final VoidCallback onPressed;
  const RetryButton({required this.onPressed, super.key});

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.refresh, size: 18),
        label: const Text('Retry'),
      );
}
