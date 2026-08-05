import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'details_theme.dart';

export 'details_theme.dart';

/// DetailsThemeManager manages both:
/// 1. The LAYOUT theme (which layout variant to use on the details page)
/// 2. Bridges to the global CinemaTheme (color system) via ThemeManager
class DetailsThemeManager extends ChangeNotifier {
  static const _detailsLayoutKey = 'details_theme';

  DetailsTheme _currentDetailsLayout = DetailsTheme.auroraGlass;
  DetailsThemeConfig? _config;

  DetailsTheme get currentTheme => _currentDetailsLayout;
  DetailsThemeConfig get config =>
      _config ?? DetailsThemeConfig.forTheme(_currentDetailsLayout);

  DetailsThemeManager() {
    // Re-notify listeners when global CinemaTheme changes
    ThemeManager.notifier.addListener(_onCinemaThemeChanged);
  }

  void _onCinemaThemeChanged() {
    notifyListeners();
  }

  Future<void> load() async {
    await ThemeManager.load();
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_detailsLayoutKey) ?? 'auroraGlass';
      _currentDetailsLayout = DetailsTheme.values.firstWhere(
        (t) => t.name == saved,
        orElse: () => DetailsTheme.auroraGlass,
      );
      _config = DetailsThemeConfig.forTheme(_currentDetailsLayout);
    } catch (_) {}
    notifyListeners();
  }

  /// Sets the details page layout theme
  Future<void> setDetailsLayout(DetailsTheme theme) async {
    _currentDetailsLayout = theme;
    _config = DetailsThemeConfig.forTheme(theme);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_detailsLayoutKey, theme.name);
    } catch (_) {}
  }

  /// Sets the global cinema color theme (accent color everywhere)
  Future<void> setTheme(CinemaTheme theme) async {
    await ThemeManager.setTheme(theme);
    notifyListeners();
  }

  @override
  void dispose() {
    ThemeManager.notifier.removeListener(_onCinemaThemeChanged);
    super.dispose();
  }
}