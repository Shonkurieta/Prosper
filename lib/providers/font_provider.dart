import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FontProvider extends ChangeNotifier {
  static const String _fontFamilyKey = 'reader_font_family';
  static const String _fontSizeKey = 'reader_font_size';
  
  // Доступные шрифты
  static const String defaultFont = 'System';
  static const String timesNewRoman = 'TimesNewRoman';
  static const String montserrat = 'Montserrat';
  static const String cormorantGaramond = 'CormorantGaramond';
  static const String merriweather = 'Merriweather';
  
  String _fontFamily = defaultFont;
  double _fontSize = 16.0;
  
  String get fontFamily => _fontFamily;
  double get fontSize => _fontSize;

  FontProvider() {
    _loadSettings();
  }

  // Загрузить настройки из SharedPreferences
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _fontFamily = prefs.getString(_fontFamilyKey) ?? defaultFont;
    _fontSize = prefs.getDouble(_fontSizeKey) ?? 16.0;
    notifyListeners();
  }

  // Изменить шрифт
  Future<void> setFontFamily(String family) async {
    _fontFamily = family;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fontFamilyKey, family);
    notifyListeners();
  }

  // Изменить размер шрифта
  Future<void> setFontSize(double size) async {
    _fontSize = size.clamp(12.0, 28.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontSizeKey, _fontSize);
    notifyListeners();
  }

  // Увеличить размер шрифта
  Future<void> increaseFontSize() async {
    await setFontSize(_fontSize + 2.0);
  }

  // Уменьшить размер шрифта
  Future<void> decreaseFontSize() async {
    await setFontSize(_fontSize - 2.0);
  }

  // Сбросить настройки
  Future<void> resetSettings() async {
    _fontFamily = defaultFont;
    _fontSize = 16.0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_fontFamilyKey);
    await prefs.remove(_fontSizeKey);
    notifyListeners();
  }

  // Получить отображаемое имя шрифта
  static String getFontDisplayName(String family) {
    switch (family) {
      case timesNewRoman:
        return 'Times New Roman';
      case montserrat:
        return 'Montserrat';
      case cormorantGaramond:
        return 'Cormorant Garamond';
      case merriweather:
        return 'Merriweather';
      case defaultFont:
      default:
        return 'По умолчанию';
    }
  }

  // Получить TextStyle с текущими настройками
  TextStyle getTextStyle({Color? color}) {
    return TextStyle(
      fontFamily: _fontFamily == defaultFont ? null : _fontFamily,
      fontSize: _fontSize,
      height: 1.8,
      color: color,
      letterSpacing: 0.3,
    );
  }
}