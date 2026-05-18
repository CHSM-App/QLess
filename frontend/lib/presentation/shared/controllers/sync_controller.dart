

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/presentation/shared/providers/connectivity_provider.dart';

final syncControllerProvider = Provider<void>((ref) {
  // Listen to connectivity changes
  ref.listen<AsyncValue<List<ConnectivityResult>>>(connectivityProvider, (
    previous,
    next,
  ) async {
    final wasOffline =
        previous?.value?.contains(ConnectivityResult.none) ?? true;
    final isOnline =
        next.value != null && !next.value!.contains(ConnectivityResult.none);

    if (wasOffline && isOnline) {
      await _refreshOnReconnect(ref);
    }
  });
});

Future<void> _refreshOnReconnect(Ref ref) async {
 
}
