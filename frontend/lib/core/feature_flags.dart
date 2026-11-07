import 'package:flutter/foundation.dart';

/// Doctor self-registration is shown on iOS the same as on Android.
/// Set to `false` to hide it on iOS.
const bool kAllowDoctorRegisterOnIos = true;

bool get canShowDoctorRegister =>
    kIsWeb ||
    defaultTargetPlatform != TargetPlatform.iOS ||
    kAllowDoctorRegisterOnIos;
