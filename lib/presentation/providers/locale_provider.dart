import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('en')) {
    _loadLocale();
  }

  static const String _localeKey = 'selectedLanguage';
  
  final Map<String, String> languageCodes = {
    'English': 'en',
    'Hindi': 'hi',
    'Marathi': 'mr',
    'Bengali': 'bn',
    'Tamil': 'ta',
    'Telugu': 'te',
    'Urdu': 'ur',
  };

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLanguage = prefs.getString(_localeKey);
    if (savedLanguage != null) {
      final localeCode = languageCodes[savedLanguage] ?? 'en';
      state = Locale(localeCode);
    }
  }

  Future<void> setLocale(String language) async {
    final localeCode = languageCodes[language] ?? 'en';
    state = Locale(localeCode);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, language);
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});
