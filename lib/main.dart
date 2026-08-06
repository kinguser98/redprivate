import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'models/user_model.dart';
import 'services/api_service.dart';
import 'services/dns_proxy.dart';
import 'services/streamtape_service.dart';
import 'themes/theme_manager.dart';
import 'screens/auth/login_register_screen.dart';
import 'screens/splash_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  // Register global logout so any refreshUser call can force logout on session takeover
  AppSession.onGlobalLogout = () async {
    await ApiService.logout();
    AppSession.user = null;
    final ctx = navigatorKey.currentContext;
    if (ctx != null && ctx.mounted) {
      Navigator.of(ctx).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginRegisterScreen()),
        (route) => false,
      );
    }
  };

  final dnsProxy = CustomDnsProxy();
  await dnsProxy.start();
  if (dnsProxy.port != null) {
    HttpOverrides.global = MyHttpOverrides(dnsProxy.port!);
  }

  // Load saved theme before app starts
  await ThemeManager.load();

  // Load custom Streamtape domains
  await StreamtapeService.init();

  // Cache parked-content IDs so dead movies/series stay hidden app-wide
  unawaited(ApiService.refreshParkedIds());

  final themeManager = DetailsThemeManager();

  runApp(
    ChangeNotifierProvider<DetailsThemeManager>.value(
      value: themeManager,
      child: const RedApp(),
    ),
  );
}

class RedApp extends StatelessWidget {
  const RedApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CinemaTheme>(
      valueListenable: ThemeManager.notifier,
      builder: (context, theme, _) {
        return MaterialApp(
          title: 'Red App',
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: AppColors.background,
            primaryColor: theme.accent,
            colorScheme: ColorScheme.dark(
              primary: theme.accent,
              secondary: theme.accentBright,
              surface: AppColors.surface,
            ),
          ),
          home: const SplashScreen(),
          navigatorKey: navigatorKey,
        );
      },
    );
  }
}
