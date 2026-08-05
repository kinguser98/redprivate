import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'home_screen.dart';
import 'all_movies_series_screen.dart';
import 'settings_screen.dart';

class MainLayoutScreen extends StatefulWidget {
  final UserModel user;
  const MainLayoutScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> {
  int _currentIndex = 0;

  @override
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
