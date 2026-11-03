import 'package:flutter/foundation.dart';

/// Doctor self-registration is available on Android only; it is hidden on iOS.
/// Set to `true` to show it on iOS as well.
const bool kAllowDoctorRegisterOnIos = false;

bool get canShowDoctorRegister =>
    kIsWeb ||
    defaultTargetPlatform != TargetPlatform.iOS ||
    kAllowDoctorRegisterOnIos;
