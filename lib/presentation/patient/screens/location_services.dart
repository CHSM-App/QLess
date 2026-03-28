import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';


class LocationService {
  static Future<String> getCurrentAddress() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check GPS
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return "Location Disabled";
    }

    // Permission check
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return "Permission Denied";
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return "Permission Permanently Denied";
    }

    // Get position
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    // Convert to address
    final placemarks =
        await placemarkFromCoordinates(position.latitude, position.longitude);
    if (placemarks.isEmpty) {
      return "Unknown Location";
    }
    final place = placemarks.first;
    final locality = place.locality?.trim();
    final admin = place.administrativeArea?.trim();
    if ((locality == null || locality.isEmpty) &&
        (admin == null || admin.isEmpty)) {
      return "Unknown Location";
    }
    if (locality == null || locality.isEmpty) return admin ?? "Unknown Location";
    if (admin == null || admin.isEmpty) return locality;
    return "$locality, $admin";
  }
}
