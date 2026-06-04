import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'token_provider.dart';

/// Appends the current JWT to any URL pointing at our backend's /uploads/
/// bucket so Image.network(...) calls can authenticate against the now
/// auth-gated /uploads endpoint. Returns the URL unchanged for non-uploads
/// URLs, null/empty input, or when no access token is available.
///
/// Usage:
///   final url = ref.watch(authImageUrlProvider)(doctor.imageUrl);
///   Image.network(url ?? '')
///
/// Pure transform — no caching, no network — so it's safe to call inside
/// `build()` for every frame.
String? authImageUrlFor(String? url, String? accessToken) {
  if (url == null || url.isEmpty) return url;
  // Only sign URLs that hit our /uploads/ bucket. Leave third-party / asset
  // URLs alone so they don't get a stray ?token= appended.
  if (!url.contains('/uploads/')) return url;
  if (accessToken == null || accessToken.isEmpty) return url;
  final sep = url.contains('?') ? '&' : '?';
  return '$url${sep}token=${Uri.encodeQueryComponent(accessToken)}';
}


/// Reactive variant for widgets: `ref.watch(authImageUrlProvider)(url)`.
/// The closure rebuilds when the access token changes, so existing
/// `Image` widgets re-render with a fresh token after token refresh.
final authImageUrlProvider = Provider<String? Function(String?)>((ref) {
  final token = ref.watch(tokenProvider).accessToken;
  return (url) => authImageUrlFor(url, token);
});
