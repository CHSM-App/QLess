import 'package:flutter/material.dart';

class SomethingWentWrongRetry extends StatelessWidget {
  final VoidCallback onRetry;
  final String title;
  final String? message;
  final String buttonLabel;
  final IconData icon;
  final Color? iconColor;

  const SomethingWentWrongRetry({
    super.key,
    required this.onRetry,
    this.title = 'Something went wrong',
    this.message,
    this.buttonLabel = 'Retry',
    this.icon = Icons.error_outline_rounded,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final titleStyle = theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.textTheme.titleMedium?.color ?? colorScheme.onSurface,
        ) ??
        TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        );
    final bodyStyle = theme.textTheme.bodySmall?.copyWith(
          color:
              theme.textTheme.bodySmall?.color ?? colorScheme.onSurfaceVariant,
        ) ??
        TextStyle(
          fontSize: 12,
          color: colorScheme.onSurfaceVariant,
        );

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  color: iconColor ?? colorScheme.primary, size: 40),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: titleStyle,
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(buttonLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
