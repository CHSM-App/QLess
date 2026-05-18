


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/presentation/shared/providers/viewModel_provider.dart';

class NetworkOverlay extends ConsumerWidget {
  final Widget child;

  const NetworkOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final networkStatus = ref.watch(networkStatusProvider);

    return networkStatus.when(
      data: (isConnected) {
        if (!isConnected) {
          // return const NetworkErrorPage();
        }
        return child;
      },
      loading: () => child,
      error: (_, __) => child,
    );
  }
}
