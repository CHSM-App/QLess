import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/presentation/shared/providers/connectivity_notifier.dart';

/// YouTube-style offline/online banner that slides up from below the bottom bar.
///
/// Usage — wrap your scaffold body (or the entire bottom-nav scaffold) with
/// [ConnectivityBannerWrapper] and it will overlay the banner automatically.
///
///   ConnectivityBannerWrapper(child: yourScaffoldOrBody)
class ConnectivityBannerWrapper extends ConsumerWidget {
  const ConnectivityBannerWrapper({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(connectivityNotifierProvider);

    final showOffline    = connectivity.isOffline;
    final showBackOnline = connectivity.showBackOnlineBanner;
    final showAny        = showOffline || showBackOnline;

    return Stack(
      children: [
        child,
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          left:   0,
          right:  0,
          bottom: showAny ? 0 : -56,
          child: _ConnectivityBanner(
            isOffline:    showOffline,
            isBackOnline: showBackOnline,
          ),
        ),
      ],
    );
  }
}

class _ConnectivityBanner extends StatelessWidget {
  const _ConnectivityBanner({
    required this.isOffline,
    required this.isBackOnline,
  });

  final bool isOffline;
  final bool isBackOnline;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    final Color bgColor;
    final Color textColor;
    final IconData icon;
    final String message;

    if (isBackOnline) {
      bgColor   = const Color(0xFF388E3C); // green
      textColor = Colors.white;
      icon      = Icons.wifi_rounded;
      message   = 'Back online';
    } else {
      bgColor   = const Color(0xFF323232); // dark grey — same as YouTube
      textColor = Colors.white;
      icon      = Icons.wifi_off_rounded;
      message   = 'You\'re offline';
    }

    return Container(
      color: bgColor,
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + bottomPad),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: textColor, size: 16),
          const SizedBox(width: 8),
          Text(
            message,
            style: TextStyle(
              color:      textColor,
              fontSize:   12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
