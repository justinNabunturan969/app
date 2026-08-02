import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the user's [ThemeMode] preference and persists it across launches
/// using [shared_preferences].
///
/// Values stored on disk: `light`, `dark`, or `system`. Defaults to
/// [ThemeMode.system] when nothing is stored or the stored value is invalid.
class ThemeController extends ChangeNotifier {
  ThemeController({this.prefs});

  static const String _prefsKey = 'theme_mode';

  // Resolved lazily on first [load] / [_persist]. Kept package-private so
  // subclasses / tests can pre-seed it; not part of the public surface.
  // ignore: prefer_public_field_for_controllers
  SharedPreferences? prefs;
  ThemeMode _mode = ThemeMode.system;

  /// The active theme mode the [MaterialApp] should resolve against.
  ThemeMode get mode => _mode;

  /// Whether the resolved brightness (taking `system` into account) is dark.
  bool isDark(BuildContext context) =>
      _mode == ThemeMode.dark ||
      (_mode == ThemeMode.system &&
          MediaQuery.platformBrightnessOf(context) == Brightness.dark);

  /// Hydrate from disk. Safe to call multiple times.
  Future<void> load() async {
    prefs ??= await SharedPreferences.getInstance();
    final raw = prefs!.getString(_prefsKey);
    final next = _decode(raw);
    if (next != _mode) {
      _mode = next;
      notifyListeners();
    }
  }

  /// Replace the current mode and persist it.
  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    await _persist();
  }

  /// Cycle light → dark → system → light. Handy for a single toggle button.
  Future<void> cycle() async {
    switch (_mode) {
      case ThemeMode.light:
        await setMode(ThemeMode.dark);
      case ThemeMode.dark:
        await setMode(ThemeMode.system);
      case ThemeMode.system:
        await setMode(ThemeMode.light);
    }
  }

  /// Convenience for a binary light/dark toggle that ignores `system`.
  Future<void> toggleLightDark() async {
    await setMode(
      _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
    );
  }

  Future<void> _persist() async {
    prefs ??= await SharedPreferences.getInstance();
    await prefs!.setString(_prefsKey, _encode(_mode));
  }

  static String _encode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  static ThemeMode _decode(String? raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }
}
