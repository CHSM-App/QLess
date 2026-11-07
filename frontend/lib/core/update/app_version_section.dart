import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/core/update/update_check_provider.dart';

/// "App version x.y.z" label for settings/profile screens. The update dialog
/// itself appears automatically at app start (see showUpdateDialogOnStart).
class AppVersionSection extends ConsumerWidget {
  const AppVersionSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(currentVersionProvider).valueOrNull ?? '-';
    return Text('App version $version',
        style: Theme.of(context).textTheme.bodySmall);
  }
}
