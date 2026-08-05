// details_theme.dart
// The DetailsTheme enum controls which LAYOUT is shown on the details page.
// Colors are always driven by the global CinemaTheme (AppColors.accent).
import 'package:flutter/material.dart';
import 'app_colors.dart';

export 'app_colors.dart' show CinemaTheme, ThemeManager, AppColors;

enum DetailsTheme {
  auroraGlass,
  cinematic,
  floatingCards,
  immersive,
  minimalGlass,
  neonCinema,
  goXio,
}

extension DetailsThemeExtension on DetailsTheme {
  String get label {
    switch (this) {
      case DetailsTheme.auroraGlass:
        return 'Aurora Glass';
      case DetailsTheme.cinematic:
        return 'Cinematic';
      case DetailsTheme.floatingCards:
        return 'Floating Cards';
      case DetailsTheme.immersive:
        return 'Immersive Hero';
      case DetailsTheme.minimalGlass:
        return 'Minimal Glass';
      case DetailsTheme.neonCinema:
        return 'Neon Cinema';
      case DetailsTheme.goXio:
        return 'GoXio';
    }
  }

  IconData get icon {
    switch (this) {
      case DetailsTheme.auroraGlass:
        return Icons.blur_on_rounded;
      case DetailsTheme.cinematic:
        return Icons.theaters_rounded;
      case DetailsTheme.floatingCards:
        return Icons.style_rounded;
      case DetailsTheme.immersive:
        return Icons.fullscreen_rounded;
      case DetailsTheme.minimalGlass:
        return Icons.dashboard_rounded;
      case DetailsTheme.neonCinema:
        return Icons.lens_rounded;
      case DetailsTheme.goXio:
        return Icons.movie_rounded;
    }
  }

  Color get accentColor => AppColors.accent;
}

class DetailsThemeConfig {
  final DetailsTheme theme;
  final double glassOpacity;
  final double blurIntensity;
  final BorderRadius borderRadius;
  final EdgeInsets padding;
  final bool showLargePoster;
  final bool showBackdropZoom;

  const DetailsThemeConfig({
    required this.theme,
    this.glassOpacity = 0.22,
    this.blurIntensity = 20,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.padding = const EdgeInsets.all(16),
    this.showLargePoster = true,
    this.showBackdropZoom = true,
  });

  static DetailsThemeConfig forTheme(DetailsTheme theme) {
    switch (theme) {
      case DetailsTheme.auroraGlass:
        return const DetailsThemeConfig(
          theme: DetailsTheme.auroraGlass,
          glassOpacity: 0.22,
          blurIntensity: 25,
          borderRadius: BorderRadius.all(Radius.circular(28)),
          padding: EdgeInsets.all(16),
        );
      case DetailsTheme.cinematic:
        return const DetailsThemeConfig(
          theme: DetailsTheme.cinematic,
          glassOpacity: 0.28,
          blurIntensity: 30,
          borderRadius: BorderRadius.all(Radius.circular(20)),
          padding: EdgeInsets.all(20),
          showLargePoster: false,
        );
      case DetailsTheme.floatingCards:
        return const DetailsThemeConfig(
          theme: DetailsTheme.floatingCards,
          glassOpacity: 0.18,
          blurIntensity: 15,
          borderRadius: BorderRadius.all(Radius.circular(32)),
          padding: EdgeInsets.all(12),
        );
      case DetailsTheme.immersive:
        return const DetailsThemeConfig(
          theme: DetailsTheme.immersive,
          glassOpacity: 0.25,
          blurIntensity: 20,
          borderRadius: BorderRadius.all(Radius.circular(24)),
          padding: EdgeInsets.all(16),
          showLargePoster: false,
        );
      case DetailsTheme.minimalGlass:
        return const DetailsThemeConfig(
          theme: DetailsTheme.minimalGlass,
          glassOpacity: 0.18,
          blurIntensity: 12,
          borderRadius: BorderRadius.all(Radius.circular(26)),
          padding: EdgeInsets.all(20),
        );
      case DetailsTheme.neonCinema:
        return const DetailsThemeConfig(
          theme: DetailsTheme.neonCinema,
          glassOpacity: 0.25,
          blurIntensity: 20,
          borderRadius: BorderRadius.all(Radius.circular(20)),
          padding: EdgeInsets.all(16),
          showLargePoster: true,
          showBackdropZoom: true,
        );
      case DetailsTheme.goXio:
        return const DetailsThemeConfig(
          theme: DetailsTheme.goXio,
          glassOpacity: 0.20,
          blurIntensity: 18,
          borderRadius: BorderRadius.all(Radius.circular(16)),
          padding: EdgeInsets.all(16),
          showLargePoster: true,
          showBackdropZoom: true,
        );
    }
  }
}