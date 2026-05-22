import 'package:flutter/material.dart';

// Global navigator + scaffold messenger keys.
//
// Extracted to a leaf file so non-UI layers (the Dio interceptor, FCM
// handlers, etc.) can navigate without importing main.dart and creating
// an import cycle.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
