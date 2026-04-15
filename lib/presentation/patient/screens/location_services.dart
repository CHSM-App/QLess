import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;


class LocationService {
  /// Returns the raw GPS [Position] (lat/lng) or null if unavailable.
  static Future<Position?> getCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 8),
            ),
          );
    } catch (_) {
      return null;
    }
  }

  static Future<String> getCurrentAddress() async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
      // Check GPS
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        final ip = await _maybeIpFallback();
        return ip ?? "Location Disabled";
      }

      // Permission check
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          final ip = await _maybeIpFallback();
          return ip ?? "Permission Denied";
        }
      }

      if (permission == LocationPermission.deniedForever) {
        final ip = await _maybeIpFallback();
        return ip ?? "Permission Permanently Denied";
      }

      if (permission == LocationPermission.unableToDetermine) {
        final ip = await _maybeIpFallback();
        return ip ?? "Permission Unavailable";
      }

      // Try last known for faster response if available
      Position? position = await Geolocator.getLastKnownPosition();

      position ??= await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );

      return _reverseGeocodeOrFallback(position);
    } on TimeoutException {
      final ip = await _maybeIpFallback();
      return ip ?? "Location Timeout";
    } on MissingPluginException {
      final ip = await _maybeIpFallback();
      return ip ?? "Location Unavailable";
    } catch (e) {
      final ip = await _maybeIpFallback();
      if (ip != null) return ip;
      if (kDebugMode) {
        // ignore: avoid_print
        print("Location error: $e");
      }
      return "Location Unavailable";
    }
  }

  static Future<String> _reverseGeocodeOrFallback(Position position) async {
    try {
      final placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isEmpty) {
        final ip = await _maybeIpFallback();
        return ip ?? _formatCoords(position);
      }
      final place = placemarks.first;
      final locality = place.locality?.trim();
      final admin = place.administrativeArea?.trim();
      if ((locality == null || locality.isEmpty) &&
          (admin == null || admin.isEmpty)) {
        final ip = await _maybeIpFallback();
        return ip ?? _formatCoords(position);
      }
      if (locality == null || locality.isEmpty) {
        return admin ?? _formatCoords(position);
      }
      if (admin == null || admin.isEmpty) return locality;
      return "$locality, $admin";
    } on MissingPluginException {
      final ip = await _maybeIpFallback();
      return ip ?? _formatCoords(position);
    } catch (_) {
      final ip = await _maybeIpFallback();
      return ip ?? _formatCoords(position);
    }
  }

  static Future<String?> _maybeIpFallback() async {
    if (!_shouldUseIpFallback()) return null;
    return _ipFallback();
  }

  static bool _shouldUseIpFallback() {
    if (kIsWeb) return true;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return false;
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return true;
    }
  }

  static String _formatCoords(Position position) {
    final lat = position.latitude.toStringAsFixed(5);
    final lon = position.longitude.toStringAsFixed(5);
    return "$lat, $lon";
  }

  static Future<String?> _ipFallback() async {
    try {
      final sources = <String>[
        'https://ipapi.co/json/',
        'https://ipwho.is/',
        'https://ipinfo.io/json',
      ];
      for (final url in sources) {
        final data = await _fetchJson(url);
        if (data == null) continue;
        final parsed = _extractCityRegion(data);
        if (parsed != null) return parsed;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static Future<Map<String, dynamic>?> _fetchJson(String url) async {
    try {
      final uri = Uri.parse(url);
      final res = await http
          .get(uri, headers: const {'User-Agent': 'qless-app'})
          .timeout(const Duration(seconds: 6));
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      return null;
    }
    return null;
  }

  static String? _extractCityRegion(Map<String, dynamic> data) {
    final success = data['success'];
    if (success is bool && !success) return null;
    final error = data['error'];
    if (error is bool && error) return null;

    String? city = (data['city'] as String?)?.trim();
    city ??= (data['town'] as String?)?.trim();
    city ??= (data['locality'] as String?)?.trim();
    city ??= (data['district'] as String?)?.trim();

    String? region = (data['region'] as String?)?.trim();
    region ??= (data['regionName'] as String?)?.trim();
    region ??= (data['state'] as String?)?.trim();
    region ??= (data['administrative'] as String?)?.trim();

    if ((city == null || city.isEmpty) && (region == null || region.isEmpty)) {
      return null;
    }
    if (city == null || city.isEmpty) return region;
    if (region == null || region.isEmpty) return city;
    return "$city, $region";
  }
}
