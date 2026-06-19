import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/presentation/shared/providers/connectivity_notifier.dart';

const connectivityErrorMessage =
    'No internet connection. Please check your connection and try again.';

bool isConnectivityFailureMessage(String? message) {
  if (message == null) return false;
  final normalized = message.toLowerCase();
  return normalized.contains('network error') ||
      normalized.contains('connection error') ||
      normalized.contains('connection refused') ||
      normalized.contains('connection timed out') ||
      normalized.contains('connection timeout') ||
      normalized.contains('request timed out') ||
      normalized.contains('send timeout') ||
      normalized.contains('receive timeout') ||
      normalized.contains('failed host lookup') ||
      normalized.contains('socketexception') ||
      normalized.contains('xmlhttprequest') ||
      normalized.contains('connection closed') ||
      normalized.contains('no internet');
}

/// Full-screen "no internet connection" state with a Retry action.
///
/// Drop this into any `.when(error: ...)` / empty body in place of showing a
/// raw Dio exception. Pull-to-refresh and the Retry button both call [onRetry].
class ConnectivityErrorView extends StatelessWidget {
  final Future<void> Function() onRetry;
  final String title;
  final String message;

  const ConnectivityErrorView({
    super.key,
    required this.onRetry,
    this.title = 'No internet connection',
    this.message = 'Please check your connection and try again.',
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: const Color(0xFF26C6B0),
      strokeWidth: 2,
      onRefresh: onRetry,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFEF3C7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.wifi_off_rounded,
                        size: 26,
                        color: Color(0xFFD97706),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF718096),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 38,
                      child: ElevatedButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF26C6B0),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                        ),
                        label: const Text(
                          'Retry',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ConnectivityErrorCard extends ConsumerWidget {
  final String title;
  final String message;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onRetry;

  const ConnectivityErrorCard({
    super.key,
    this.title = 'You are offline',
    this.message = connectivityErrorMessage,
    this.margin = const EdgeInsets.only(bottom: 18),
    this.onRetry,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOffline = ref.watch(connectivityNotifierProvider).isOffline;
    if (!isOffline) return const SizedBox.shrink();

    return Container(
      margin: margin,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.wifi_off_rounded,
              color: Color(0xFFD97706),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF92400E),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFFB45309),
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Retry'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFB45309),
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
