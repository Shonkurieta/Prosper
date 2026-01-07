import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
    notifyListeners();
  }

  // Light theme colors
  Color get backgroundColor => _isDarkMode ? const Color(0xFF0F0520) : const Color(0xFFF5F7FA);
  Color get cardColor => _isDarkMode ? const Color(0xFF1A1F3A) : Colors.white;
  Color get primaryColor => _isDarkMode ? const Color(0xFF14FFEC) : const Color(0xFF4ECDC4);
  Color get secondaryColor => _isDarkMode ? const Color(0xFF0D7377) : const Color(0xFF44A08D);
  Color get textPrimaryColor => _isDarkMode ? Colors.white : const Color(0xFF2D3436);
  Color get textSecondaryColor => _isDarkMode ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF636E72);
  Color get borderColor => _isDarkMode ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE0E5EC);
  Color get errorColor => const Color(0xFFFF6B6B);
  Color get successColor => _isDarkMode ? const Color(0xFF14FFEC) : const Color(0xFF4ECDC4);
  Color get warningColor => const Color(0xFFFFE66D);
  Color get inputBackgroundColor => _isDarkMode ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF5F7FA);
  Color get shadowColor => _isDarkMode ? Colors.black.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.04);
  
  // Decorative circle colors
  Color get decorativeCircle1 => _isDarkMode 
      ? const Color(0xFF9333EA).withValues(alpha: 0.4) 
      : const Color(0xFF4ECDC4).withValues(alpha: 0.15);
  Color get decorativeCircle2 => _isDarkMode 
      ? const Color(0xFFEC4899).withValues(alpha: 0.3) 
      : const Color(0xFFFFE66D).withValues(alpha: 0.2);
  Color get decorativeCircle3 => _isDarkMode 
      ? const Color(0xFFFF6B6B).withValues(alpha: 0.2) 
      : const Color(0xFFFF6B6B).withValues(alpha: 0.12);

  // Gradients
  List<Color> get primaryGradient => _isDarkMode
      ? [const Color(0xFF14FFEC), const Color(0xFF0D7377)]
      : [const Color(0xFF4ECDC4), const Color(0xFF44A08D)];

  List<Color> get backgroundGradient => _isDarkMode
      ? [
          const Color(0xFF0F0520),
          const Color(0xFF1A1F3A),
          const Color(0xFF2D1B69).withValues(alpha: 0.3),
        ]
      : [const Color(0xFFF5F7FA), const Color(0xFFF5F7FA)];

  BoxShadow get cardShadow => BoxShadow(
        color: shadowColor,
        blurRadius: _isDarkMode ? 20 : 10,
        offset: Offset(0, _isDarkMode ? 8 : 2),
      );

  Color getIconColor(bool isActive) {
    if (isActive) {
      return _isDarkMode ? const Color(0xFF14FFEC) : const Color(0xFF4ECDC4);
    }
    return textSecondaryColor;
  }

  TextStyle get headingStyle => TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w900,
        color: textPrimaryColor,
      );

  TextStyle get bodyStyle => TextStyle(
        fontSize: 15,
        color: textSecondaryColor,
      );

  InputDecoration getInputDecoration({
    required String hintText,
    IconData? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: textSecondaryColor.withValues(alpha: 0.5),
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: primaryColor, size: 22)
          : null,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: _isDarkMode
            ? BorderSide(color: borderColor, width: 1.5)
            : BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: errorColor, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: errorColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      filled: true,
      fillColor: inputBackgroundColor,
    );
  }

  ButtonStyle getPrimaryButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: primaryColor,
      foregroundColor: _isDarkMode ? Colors.white : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }

  BoxDecoration getCardDecoration() {
    return BoxDecoration(
      color: cardColor,
      borderRadius: BorderRadius.circular(16),
      border: _isDarkMode
          ? Border.all(color: borderColor, width: 1.5)
          : null,
      boxShadow: [cardShadow],
    );
  }
}