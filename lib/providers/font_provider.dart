import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FontProvider extends ChangeNotifier {
  static const String _fontFamilyKey = 'reader_font_family';
  static const String _fontSizeKey = 'reader_font_size';

  // ── Font constants ──────────────────────────────────────────────────────────
  static const String defaultFont        = 'System';
  static const String timesNewRoman      = 'TimesNewRoman';
  static const String montserrat         = 'Montserrat';
  static const String cormorantGaramond  = 'CormorantGaramond';
  static const String merriweather       = 'Merriweather';
  static const String ebGaramond         = 'EBGaramond';
  static const String georgia            = 'Georgia';
  static const String helvetica          = 'Helvetica';
  static const String notoSans           = 'NotoSans';
  static const String oswald             = 'Oswald';
  static const String roboto             = 'Roboto';
  static const String zariaText          = 'ZAriaText';

  /// Ordered list used in the reader's font picker.
  static const List<String> allFonts = [
    defaultFont,
    georgia,
    timesNewRoman,
    ebGaramond,
    merriweather,
    cormorantGaramond,
    zariaText,
    notoSans,
    roboto,
    helvetica,
    montserrat,
    oswald,
  ];

  // ── State ───────────────────────────────────────────────────────────────────
  String _fontFamily = defaultFont;
  double _fontSize   = 16.0;

  String get fontFamily => _fontFamily;
  double get fontSize   => _fontSize;

  FontProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _fontFamily = prefs.getString(_fontFamilyKey) ?? defaultFont;
    _fontSize   = prefs.getDouble(_fontSizeKey)   ?? 16.0;
    notifyListeners();
  }

  Future<void> setFontFamily(String family) async {
    _fontFamily = family;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fontFamilyKey, family);
    notifyListeners();
  }

  Future<void> setFontSize(double size) async {
    _fontSize = size.clamp(12.0, 28.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontSizeKey, _fontSize);
    notifyListeners();
  }

  Future<void> increaseFontSize() async => setFontSize(_fontSize + 2.0);
  Future<void> decreaseFontSize() async => setFontSize(_fontSize - 2.0);

  Future<void> resetSettings() async {
    _fontFamily = defaultFont;
    _fontSize   = 16.0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_fontFamilyKey);
    await prefs.remove(_fontSizeKey);
    notifyListeners();
  }

  // ── Display helpers ─────────────────────────────────────────────────────────
  static String getFontDisplayName(String family) {
    switch (family) {
      case timesNewRoman:     return 'Times New Roman';
      case montserrat:        return 'Montserrat';
      case cormorantGaramond: return 'Cormorant Garamond';
      case merriweather:      return 'Merriweather';
      case ebGaramond:        return 'EB Garamond';
      case georgia:           return 'Georgia';
      case helvetica:         return 'Helvetica';
      case notoSans:          return 'Noto Sans';
      case oswald:            return 'Oswald';
      case roboto:            return 'Roboto';
      case zariaText:         return 'Zaria Text';
      case defaultFont:
      default:                return 'По умолчанию';
    }
  }

  TextStyle getTextStyle({Color? color}) {
    return TextStyle(
      fontFamily:    _fontFamily == defaultFont ? null : _fontFamily,
      fontSize:      _fontSize,
      height:        1.8,
      color:         color,
      letterSpacing: 0.3,
    );
  }
}
