import 'package:flutter/material.dart';

class NoInternetRetry extends StatelessWidget {
  final VoidCallback onRetry;
  final String title;
  final String? message;
  final String buttonLabel;
  final IconData icon;
  final Color? iconColor;

  const NoInternetRetry({
    super.key,
    required this.onRetry,
    this.title = 'No internet connection',
    this.message = 'Check your connection and try again.',
    this.buttonLabel = 'Retry',
    this.icon = Icons.wifi_off_rounded,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primary = iconColor ?? colorScheme.primary;
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

    final showMessage = message != null && message!.trim().isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: primary, size: 40),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: titleStyle,
              ),
              if (showMessage) ...[
                const SizedBox(height: 6),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: bodyStyle,
                ),
              ],
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(buttonLabel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
