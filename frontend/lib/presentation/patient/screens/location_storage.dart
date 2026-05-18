import 'package:shared_preferences/shared_preferences.dart';

class LocationStorage {
  static const String key = "user_location";
  static const String sourceKey = "user_location_source";
  static const String sourceManual = "manual";
  static const String sourceAuto = "auto";

  static Future<void> saveLocation(String location, {bool isManual = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, location);
    await prefs.setString(sourceKey, isManual ? sourceManual : sourceAuto);
  }

  static Future<String?> getLocation() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  static Future<bool> isManual() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(sourceKey) == sourceManual;
  }

  static Future<void> clearLocation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
    await prefs.remove(sourceKey);
  }
}
