/// Default texts for the update dialog, used when the Remote Config
/// `update_title` / `update_message` values are empty.
///
/// The project has no localization setup yet (English only), so the strings
/// live here in one place. When ARB/l10n is added, move these keys there.
class UpdateStrings {
  const UpdateStrings._();

  static const title = 'Update available';
  static const body =
      'A new version of QLess is available with improvements and fixes.';
  static const forceNote =
      'This update is required to continue using the app.';
  static const updateNow = 'Update now';
  static const later = 'Later';
}
