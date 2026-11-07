import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:qless/core/navigation/navigator_key.dart';
import 'package:qless/core/services/remote_config_service.dart';
import 'package:qless/core/update/update_check_provider.dart';
import 'package:qless/core/update/update_state.dart';
import 'package:qless/core/update/update_strings.dart';
import 'package:url_launcher/url_launcher.dart';

// applicationId in android/app/build.gradle.kts (case-sensitive).
const _fallbackPackageName = 'com.vengurlatech.qless';
const _logoAsset = 'assets/icon/qless_logo_512.png';

Future<void> _openStore() async {
  var id = _fallbackPackageName;
  try {
    id = (await PackageInfo.fromPlatform()).packageName;
  } catch (_) {}
  await launchUrl(
    Uri.parse('https://play.google.com/store/apps/details?id=$id'),
    mode: LaunchMode.externalApplication,
  );
}

bool _promptShown = false;

/// Runs the update check once on app start and shows the dialog if needed.
/// Waits (bounded) for Remote Config in the background so app start is never
/// blocked; any failure or timeout simply means no dialog.
Future<void> showUpdateDialogOnStart(ProviderContainer container) async {
  if (_promptShown) return;
  try {
    await RemoteConfigService.instance
        .init()
        .timeout(const Duration(seconds: 15));
    final state = await container.read(updateCheckProvider.future);
    if (!state.updateAvailable) return;
    // The navigator may not be mounted yet on a slow start; retry briefly.
    BuildContext? ctx = navigatorKey.currentContext;
    for (var i = 0; ctx == null && i < 10; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      ctx = navigatorKey.currentContext;
    }
    if (ctx == null || !ctx.mounted) return;
    _promptShown = true;
    await showUpdateDialog(ctx, state);
  } catch (e) {
    debugPrint('Update prompt skipped: $e');
  }
}

/// Shows the update dialog. Forced -> not dismissible, no "Later".
Future<void> showUpdateDialog(BuildContext context, UpdateState state) {
  final force = state.forceUpdate;
  return showDialog<void>(
    context: context,
    barrierDismissible: !force,
    builder: (_) => PopScope(
      canPop: !force,
      child: _UpdateDialog(state: state),
    ),
  );
}

class _UpdateDialog extends StatelessWidget {
  final UpdateState state;
  const _UpdateDialog({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final force = state.forceUpdate;
    final title = state.dialogTitle.trim().isEmpty
        ? UpdateStrings.title
        : state.dialogTitle;
    final message = state.dialogMessage.trim().isEmpty
        ? UpdateStrings.body
        : state.dialogMessage;
    final secondary = scheme.onSurface.withValues(alpha: 0.65);

    return Dialog(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  _logoAsset,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(
                      Icons.system_update_rounded,
                      color: scheme.primary,
                      size: 36),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: secondary,
                  fontWeight: FontWeight.w400),
            ),
            if (force) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 18, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        UpdateStrings.forceNote,
                        style: TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: () async {
                  await _openStore();
                  if (!force && context.mounted) Navigator.of(context).pop();
                },
                icon: const Icon(Icons.download_rounded, size: 20),
                label: const Text(UpdateStrings.updateNow,
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            if (!force) ...[
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(UpdateStrings.later,
                      style: TextStyle(color: secondary)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
