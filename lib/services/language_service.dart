import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageService with ChangeNotifier {
  static const _prefKey = 'language';

  Locale _locale = const Locale('es');

  Locale get locale => _locale;

  bool get isEnglish => _locale.languageCode == 'en';

  Future<void> loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey) ?? 'Español';
    if (saved == 'English') {
      _locale = const Locale('en');
    } else {
      _locale = const Locale('es');
    }
    notifyListeners();
  }

  Future<void> setLanguage(String languageLabel) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, languageLabel);
    if (languageLabel == 'English') {
      _locale = const Locale('en');
    } else {
      _locale = const Locale('es');
    }
    notifyListeners();
  }
}
