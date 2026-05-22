import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class IdeInfo {
  final String label;
  final List<String> commands;
  final String primaryCommand;
  IdeInfo(this.label, this.commands) : primaryCommand = commands.first;

  bool available = false;
}

class SettingsService extends ChangeNotifier {
  static const _themeKey = 'theme_mode';
  static const _usernameKey = 'username';
  static const _langKey = 'default_language';
  static const _ideKey = 'ide_command';

  ThemeMode _themeMode = ThemeMode.light;
  String _username = 'Разработчик';
  String _defaultLanguage = 'dart';
  String _ideCommand = 'code';

  final List<IdeInfo> ideOptions = [
    IdeInfo('VS Code', ['code']),
    IdeInfo('Cursor', ['cursor']),
    IdeInfo('Windsurf', ['windsurf']),
    IdeInfo('Zed', ['zed', 'zeditor', 'flatpak run com.zedapp.Zed']),
    IdeInfo('Fleet', ['fleet']),
    IdeInfo('IntelliJ IDEA', ['idea']),
    IdeInfo('PyCharm', ['pycharm']),
    IdeInfo('WebStorm', ['webstorm']),
    IdeInfo('Android Studio', ['android-studio', 'studio']),
    IdeInfo('VSCodium', ['codium']),
    IdeInfo('Emacs', ['emacs']),
    IdeInfo('Vim', ['vim', 'gvim', 'nvim']),
  ];

  ThemeMode get themeMode => _themeMode;
  String get username => _username;
  String get defaultLanguage => _defaultLanguage;
  String get ideCommand => _ideCommand;

  List<IdeInfo> get availableIdeOptions =>
      ideOptions.where((o) => o.available).toList();

  Future<void> init() async {
    await _detectIdes();
    final prefs = await SharedPreferences.getInstance();
    final themeStr = prefs.getString(_themeKey) ?? 'light';
    _themeMode = _parseTheme(themeStr);
    _username = prefs.getString(_usernameKey) ?? 'Разработчик';
    _defaultLanguage = prefs.getString(_langKey) ?? 'dart';
    _ideCommand = prefs.getString(_ideKey) ?? _firstAvailable();
    notifyListeners();
  }

  String _firstAvailable() {
    final found = availableIdeOptions;
    return found.isNotEmpty ? found.first.primaryCommand : 'code';
  }

  Future<void> _detectIdes() async {
    for (final ide in ideOptions) {
      for (final cmd in ide.commands) {
        try {
          final result = await Process.run('which', [cmd.split(' ').first]);
          if (result.exitCode == 0) {
            ide.available = true;
            break;
          }
        } catch (_) {}
      }
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.name);
  }

  Future<void> setUsername(String name) async {
    _username = name;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usernameKey, name);
  }

  Future<void> setDefaultLanguage(String lang) async {
    _defaultLanguage = lang;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_langKey, lang);
  }

  Future<void> setIdeCommand(String cmd) async {
    _ideCommand = cmd;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ideKey, cmd);
  }

  Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _themeMode = ThemeMode.light;
    _username = 'Разработчик';
    _defaultLanguage = 'dart';
    _ideCommand = _firstAvailable();
    notifyListeners();
  }

  ThemeMode _parseTheme(String s) {
    switch (s) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.light;
    }
  }
}
