import 'package:shared_preferences/shared_preferences.dart';

class LocationStorage {
  static const String key = "user_location";

  static Future<void> saveLocation(String location) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, location);
  }

  static Future<String?> getLocation() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }
}