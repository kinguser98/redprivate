import 'package:flutter/material.dart';
import 'dart:io';
import '../models/user_model.dart';
import 'home_screen.dart';
import 'all_movies_series_screen.dart';
import 'settings_screen.dart';
import '../widgets/update_dialog.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';

class MainLayoutScreen extends StatefulWidget {
  final UserModel user;
  const MainLayoutScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUpdates();
    });
  }

  Future<void> _checkUpdates() async {
    try {
      // APK updates only for Android; iOS uses App Store
      if (!Platform.isAndroid) return;
      final res = await ApiService.fetchAppSettings();
      if (res['status'] == 'success' && res['data']?['settings'] != null) {
        final s = res['data']['settings'];
        final latest = s['latest_version']?.toString() ?? '1.0.0';
        if (_hasUpdate(ApiConfig.currentVersion, latest)) {
          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: s['update_skippable']?.toString() == '1',
              builder: (_) => UpdateDialog(settings: s),
            );
          }
        }
      }
    } catch (_) {}
  }

  bool _hasUpdate(String current, String latest) {
    try {
      List<int> currParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      List<int> latParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      for (int i = 0; i < 3; i++) {
        int cVal = i < currParts.length ? currParts[i] : 0;
        int lVal = i < latParts.length ? latParts[i] : 0;
        if (lVal > cVal) return true;
        if (cVal > lVal) return false;
      }
    } catch (_) {}
    return false;
  }
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(user: widget.user),
      const AllMoviesSeriesScreen(),
      SettingsScreen(user: widget.user),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF14141C),
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08), width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: const Color(0xFFE50914),
          unselectedItemColor: Colors.grey.shade600,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              activeIcon: Icon(Icons.home_rounded, size: 28),
              label: "Home",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_rounded),
              activeIcon: Icon(Icons.grid_view_rounded, size: 28),
              label: "Catalog",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded),
              activeIcon: Icon(Icons.person_rounded, size: 28),
              label: "Settings",
            ),
          ],
        ),
      ),
    );
  }
}
