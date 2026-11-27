import 'package:flutter/foundation.dart';

/// Doctor self-registration is shown on iOS the same as on Android.
/// Set to `false` to hide it on iOS.
const bool kAllowDoctorRegisterOnIos = true;

bool get canShowDoctorRegister =>
    kIsWeb ||
    defaultTargetPlatform != TargetPlatform.iOS ||
    kAllowDoctorRegisterOnIos;

/// AI medical report summaries (doctor + patient). `false` hides every entry
/// point; the server-side kill switch is AI_REPORTS_ENABLED (ROLLBACK_AI_REPORTS.md).
const bool kAiReportsEnabled = true;
