# R8 / ProGuard keep rules layered on top of Flutter + plugin consumer rules.
# Most plugins ship their own consumer-proguard-rules.pro (Firebase,
# flutter_local_notifications, google_maps_flutter, image_picker,
# permission_handler, etc.) so this file only carries belt-and-suspenders
# rules and project-specific keeps.
#
# If a release build crashes with ClassNotFoundException, NoSuchMethodError,
# or "MissingPluginException" that doesn't repro in debug, R8 stripped
# something. Find the offender in the crash, then add a -keep rule here.

# --- Flutter framework ---------------------------------------------------
# Defense-in-depth. Flutter's embedding ships consumer rules but pinning
# these explicitly costs nothing and catches edge cases on older AGP.
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.**    { *; }
-keep class io.flutter.plugins.**   { *; }
-dontwarn io.flutter.embedding.**

# --- Firebase Messaging --------------------------------------------------
# FCM uses reflection to instantiate the service. Consumer rules cover
# this, but a project-side keep is cheap insurance against AGP/R8 quirks.
-keep class com.google.firebase.messaging.** { *; }
-keep class * extends com.google.firebase.messaging.FirebaseMessagingService { *; }

# --- AndroidX lifecycle --------------------------------------------------
# Some plugins reflect on DefaultLifecycleObserver implementations.
-keep class androidx.lifecycle.DefaultLifecycleObserver

# --- Crash reporting hygiene --------------------------------------------
# Keep file + line numbers in stack traces so mapping.txt can resolve them.
-keepattributes SourceFile,LineNumberTable
# Rename the source file attribute to obscure original paths while still
# allowing R8's retrace tool to de-obfuscate via mapping.txt.
-renamesourcefileattribute SourceFile
