import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'auth/login_register_screen.dart';
import 'details_screen.dart';
import 'web_series_detail_screen.dart';

/// Navigate to a movie or series detail screen.
/// Guests (not logged in) are redirected to login first.
/// After logging in they come back to where they were via the Navigator stack.
void navigateToContent(BuildContext context, int contentId, String itemType) {
  if (!AppSession.isLoggedIn) {
    // Show a brief hint then push login on top (user can go back)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Login to watch movies & series"),
        backgroundColor: Colors.redAccent,
        duration: Duration(seconds: 2),
      ),
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginRegisterScreen()),
    );
    return;
  }

  _pushContent(context, contentId, itemType);
}

void _pushContent(BuildContext context, int contentId, String itemType) {
  if (itemType == 'series' || itemType == '2') {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WebSeriesDetailScreen(contentId: contentId),
      ),
    );
  } else {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailsScreen(contentId: contentId, itemType: itemType),
      ),
    );
  }
}
