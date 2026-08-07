import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import 'auth/login_register_screen.dart';
import 'main_layout_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();

    // Start the settings fetch in parallel with the splash animation so it's
    // usually ready by the time we navigate. Never block startup on the network.
    final settingsFuture = ApiService.fetchAppSettings();

    Timer(const Duration(seconds: 2), () async {
      if (!mounted) return;

      Map<String, dynamic> settings = {};
      try {
        final sRes = await settingsFuture.timeout(const Duration(seconds: 3));
        if (sRes['status'] == 'success' && sRes['data']?['settings'] != null) {
          settings = sRes['data']['settings'];
        }
      } catch (_) {
        // Server unreachable/timeout — continue with stored session or login
      }

      final savedUser = await ApiService.getUserSession();

      if (savedUser != null) {
        // Verify the session is still valid on the server (device check included)
        final fresh = await ApiService.refreshUser(savedUser.id);
        if (!mounted) return;

        if (fresh == null) {
          // Session invalid or logged out on another device — go to login
          await ApiService.logout();
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginRegisterScreen()),
          );
          return;
        }

        // Preserve locally saved profile_pic if server returns empty
        final mergedPic = fresh.profilePic.isNotEmpty
            ? fresh.profilePic
            : savedUser.profilePic;
        final merged = UserModel(
          id: fresh.id,
          name: fresh.name,
          email: fresh.email,
          role: fresh.role,
          activeSubscription: fresh.activeSubscription,
          subscriptionExp: fresh.subscriptionExp,
          profilePic: mergedPic,
          subscriptionStart: fresh.subscriptionStart,
          subscriptionTime: fresh.subscriptionTime,
          subscriptionAmount: fresh.subscriptionAmount,
        );
        AppSession.user = merged;
        await ApiService.saveUserSession(merged);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => MainLayoutScreen(user: merged)),
        );
      } else {
        // First install/no saved session — launch fresh to Login/Register screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginRegisterScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE50914), Color(0xFF8B0000)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE50914).withOpacity(0.6),
                        blurRadius: 30,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      "R C",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 52,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        letterSpacing: -4.0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "RED CHILLIES",
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: const Color(0xFFE50914).withOpacity(0.8),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "STREAM UNLIMITED MOVIES & SERIES",
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 2,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
