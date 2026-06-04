import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Available Chat Themes
enum ChatTheme { Default, Blue, Purple, Green, Red, Orange }

class ThemeProvider extends ChangeNotifier {
  static const _themeKey = 'chat_theme';
  static const _darkModeKey = 'dark_mode';

  // ─────────────────────────────────────────────
  // APP MODE (LIGHT / DARK)
  // ─────────────────────────────────────────────
  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  // ─────────────────────────────────────────────
  // CHAT THEME
  // ─────────────────────────────────────────────
  ChatTheme _chatTheme = ChatTheme.Default;
  ChatTheme get chatTheme => _chatTheme;

  // ─────────────────────────────────────────────
  // INIT (LOAD SAVED STATE)
  // ─────────────────────────────────────────────
  ThemeProvider() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    final savedThemeIndex = prefs.getInt(_themeKey);
    final savedDarkMode = prefs.getBool(_darkModeKey);

    if (savedThemeIndex != null) {
      _chatTheme = ChatTheme.values[savedThemeIndex];
    }

    if (savedDarkMode != null) {
      _themeMode = savedDarkMode ? ThemeMode.dark : ThemeMode.light;
    }

    notifyListeners();
  }

  // ─────────────────────────────────────────────
  // UPDATE METHODS (SAVE STATE)
  // ─────────────────────────────────────────────
  Future<void> toggleTheme(bool isDark) async {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, isDark);
  }

  Future<void> setChatTheme(ChatTheme theme) async {
    _chatTheme = theme;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, theme.index);
  }

  // ─────────────────────────────────────────────
  // COLORS / GRADIENTS
  // ─────────────────────────────────────────────
  static const Map<ChatTheme, List<Color>> _chatGradients = {
    ChatTheme.Default: [Color(0xFF4A6CF7), Color(0xFF6A5AE0)],
    ChatTheme.Blue: [Color(0xFF4FACFE), Color(0xFF00F2FE)],
    ChatTheme.Purple: [Color(0xFF7F00FF), Color(0xFFE100FF)],
    ChatTheme.Green: [Color(0xFF11998E), Color(0xFF38EF7D)],
    ChatTheme.Red: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
    ChatTheme.Orange: [Color(0xFFF7971E), Color(0xFFFFD200)],
  };

  static const Map<ChatTheme, Color> _accentColors = {
    ChatTheme.Default: Color(0xFF6A5AE0),
    ChatTheme.Blue: Color(0xFF00F2FE),
    ChatTheme.Purple: Color(0xFFE100FF),
    ChatTheme.Green: Color(0xFF38EF7D),
    ChatTheme.Red: Color(0xFFFF416C),
    ChatTheme.Orange: Color(0xFFFFD200),
  };

  static const Map<ChatTheme, Color> _chatBackgrounds = {
    ChatTheme.Default: Color(0xFFF4F6FF),
    ChatTheme.Blue: Color(0xFFE7F3FF),
    ChatTheme.Purple: Color(0xFFF5E6FF),
    ChatTheme.Green: Color(0xFFE9FFF3),
    ChatTheme.Red: Color(0xFFFFE8E8),
    ChatTheme.Orange: Color(0xFFFFF4E3),
  };

  Color get chatBackground => _chatBackgrounds[_chatTheme]!;
  Color get accentColor => _accentColors[_chatTheme]!;
  Color get myBubbleTextColor => Colors.white;

  Gradient get chatGradient => LinearGradient(
    colors: _chatGradients[_chatTheme]!,
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  Color othersBubbleBackground(bool isDark) =>
      isDark ? Colors.white12 : Colors.grey.shade200;

  Color othersBubbleTextColor(bool isDark) =>
      isDark ? Colors.white : Colors.black87;

  // ─────────────────────────────────────────────
  // CHAT APP BAR
  // ─────────────────────────────────────────────
  Gradient? get chatAppBarGradient =>
      isDarkMode ? null : chatGradient;

  Color get chatAppBarColor =>
      isDarkMode ? const Color(0xFF0C1220) : _chatGradients[_chatTheme]!.first;

  Color get chatAppBarTextColor => Colors.white;

  // ─────────────────────────────────────────────
  // SETTINGS HELPERS
  // ─────────────────────────────────────────────
  Gradient chatGradientFor(ChatTheme theme) => LinearGradient(
    colors: _chatGradients[theme]!,
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  String getThemeName(ChatTheme theme) {
    switch (theme) {
      case ChatTheme.Default:
        return "Whisp Default";
      case ChatTheme.Blue:
        return "Ocean Blue";
      case ChatTheme.Purple:
        return "Neon Purple";
      case ChatTheme.Green:
        return "Fresh Green";
      case ChatTheme.Red:
        return "Energy Red";
      case ChatTheme.Orange:
        return "Sunset Orange";
    }
  }
}
