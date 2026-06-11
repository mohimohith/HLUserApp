// language_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  String _selectedLanguage = "English";

  String get selectedLanguage => _selectedLanguage;

  LanguageProvider() {
    loadSelectedLanguage();
  }

  Future<void> loadSelectedLanguage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _selectedLanguage = prefs.getString('selected_language') ?? "English";
    notifyListeners();
  }

  Future<void> setLanguage(String language) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_language', language);
    _selectedLanguage = language;
    notifyListeners(); // This will notify all listeners (all screens)
  }

  String getText(String english, String telugu) {
    return _selectedLanguage == "Telugu" ? telugu : english;
  }
}