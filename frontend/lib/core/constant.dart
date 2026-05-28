// Backend base URL — injected at build time so the same source tree builds
// dev, staging, and prod APKs/IPAs. NEVER hardcode a LAN IP here; release
// builds were previously shipping with the dev server address.
//
// Defaults to the LAN dev server for `flutter run` ergonomics. Override per
// build:
//
//   flutter run                                                # default (dev LAN)
//   flutter run --dart-define=API_URL=http://localhost:3000/   # local backend
//   flutter build apk --release \
//     --dart-define=API_URL=https://qless.vengurlatech.com/    # prod
//
// Trailing slash is required — retrofit composes paths with it.
//
// NOTE: `String.fromEnvironment` is evaluated at compile time, so changing
// the value requires a full rebuild (hot reload won't pick it up).
const String baseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'https://qless.vengurlatech.com/',
);

