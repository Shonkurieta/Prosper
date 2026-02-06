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

  // Minimalist theme colors
  Color get backgroundColor => _isDarkMode ? const Color(0xFF0A0A0A) : const Color(0xFFFAFAFA);
  Color get cardColor => _isDarkMode ? const Color(0xFF141414) : const Color(0xFFFFFFFF);
  Color get primaryColor => _isDarkMode ? const Color(0xFFE0E0E0) : const Color(0xFF1A1A1A);
  Color get secondaryColor => _isDarkMode ? const Color(0xFF404040) : const Color(0xFF6B6B6B);
  Color get accentColor => _isDarkMode ? const Color(0xFF3B82F6) : const Color(0xFF2563EB);
  Color get textPrimaryColor => _isDarkMode ? const Color(0xFFE5E5E5) : const Color(0xFF1A1A1A);
  Color get textSecondaryColor => _isDarkMode ? const Color(0xFF888888) : const Color(0xFF6B6B6B);
  Color get borderColor => _isDarkMode ? const Color(0xFF252525) : const Color(0xFFE5E5E5);
  Color get errorColor => _isDarkMode ? const Color(0xFFEF4444) : const Color(0xFFDC2626);
  Color get successColor => _isDarkMode ? const Color(0xFF10B981) : const Color(0xFF059669);
  Color get warningColor => _isDarkMode ? const Color(0xFFF59E0B) : const Color(0xFFD97706);
  Color get inputBackgroundColor => _isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);
  Color get shadowColor => _isDarkMode ? Colors.black.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.03);
  
  // Subtle decorative elements
  Color get decorativeCircle1 => _isDarkMode 
      ? const Color(0xFF3B82F6).withValues(alpha: 0.08) 
      : const Color(0xFF2563EB).withValues(alpha: 0.04);
  Color get decorativeCircle2 => _isDarkMode 
      ? const Color(0xFF8B5CF6).withValues(alpha: 0.06) 
      : const Color(0xFF7C3AED).withValues(alpha: 0.03);
  Color get decorativeCircle3 => _isDarkMode 
      ? const Color(0xFF6366F1).withValues(alpha: 0.05) 
      : const Color(0xFF4F46E5).withValues(alpha: 0.025);

  // Action colors for management screens - balanced and theme-aware
  Color getActionColor(String action) {
    switch (action) {
      case 'chapters':
        return _isDarkMode ? const Color(0xFF3B82F6) : const Color(0xFF2563EB); // Blue
      case 'edit':
        return _isDarkMode ? const Color(0xFF8B5CF6) : const Color(0xFF7C3AED); // Purple
      case 'delete':
        return errorColor;
      default:
        return accentColor;
    }
  }

  // Management button colors - subtle and balanced
  List<Color> getManagementButtonGradient() {
    return _isDarkMode
        ? [const Color(0xFF2A2A2A), const Color(0xFF1F1F1F)]
        : [const Color(0xFF1A1A1A), const Color(0xFF0F0F0F)];
  }

  Color getManagementButtonTextColor() {
    return _isDarkMode ? const Color(0xFFE5E5E5) : const Color(0xFFFFFFFF);
  }

  // Minimal gradients
  List<Color> get primaryGradient => _isDarkMode
      ? [const Color(0xFF1A1A1A), const Color(0xFF0A0A0A)]
      : [const Color(0xFFFFFFFF), const Color(0xFFF5F5F5)];

  List<Color> get backgroundGradient => _isDarkMode
      ? [const Color(0xFF0A0A0A), const Color(0xFF0F0F0F)]
      : [const Color(0xFFFAFAFA), const Color(0xFFFFFFFF)];

  BoxShadow get cardShadow => BoxShadow(
        color: shadowColor,
        blurRadius: _isDarkMode ? 24 : 8,
        offset: Offset(0, _isDarkMode ? 4 : 1),
      );

  Color getIconColor(bool isActive) {
    if (isActive) {
      return accentColor;
    }
    return textSecondaryColor;
  }

  TextStyle get headingStyle => TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: textPrimaryColor,
        letterSpacing: -0.5,
      );

  TextStyle get bodyStyle => TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: textSecondaryColor,
        letterSpacing: 0.1,
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
          ? Icon(prefixIcon, color: textSecondaryColor, size: 20)
          : null,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: accentColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: errorColor, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: errorColor, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      filled: true,
      fillColor: inputBackgroundColor,
    );
  }

  ButtonStyle getPrimaryButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: _isDarkMode ? const Color(0xFFE5E5E5) : const Color(0xFF1A1A1A),
      foregroundColor: _isDarkMode ? const Color(0xFF0A0A0A) : const Color(0xFFFFFFFF),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    );
  }

  ButtonStyle getSecondaryButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: textPrimaryColor,
      side: BorderSide(color: borderColor, width: 1),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    );
  }

  BoxDecoration getCardDecoration() {
    return BoxDecoration(
      color: cardColor,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: borderColor, width: 1),
      boxShadow: [cardShadow],
    );
  }
}