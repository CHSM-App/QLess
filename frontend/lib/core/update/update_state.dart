/// Result of comparing the installed version with Remote Config.
class UpdateState {
  final bool updateAvailable;
  final bool forceUpdate;
  final String currentVersion;
  final String latestVersion;
  final String dialogTitle;
  final String dialogMessage;

  const UpdateState({
    required this.updateAvailable,
    required this.forceUpdate,
    required this.currentVersion,
    required this.latestVersion,
    required this.dialogTitle,
    required this.dialogMessage,
  });

  const UpdateState.upToDate({
    this.currentVersion = '',
    this.latestVersion = '',
  })  : updateAvailable = false,
        forceUpdate = false,
        dialogTitle = '',
        dialogMessage = '';
}
