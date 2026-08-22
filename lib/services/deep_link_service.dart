import 'package:flutter/material.dart';
import '../screens/details_screen.dart';

class DeepLinkService {
  static bool _initialHandled = false;

  static void init(GlobalKey<NavigatorState> navKey) {
    if (_initialHandled) return;
    _initialHandled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final defaultRoute = WidgetsBinding.instance.platformDispatcher.defaultRouteName;
      if (defaultRoute.isNotEmpty && defaultRoute != '/') {
        handleUriString(defaultRoute, navKey);
      }
    });
  }

  static void handleUriString(String uriStr, GlobalKey<NavigatorState> navKey) {
    try {
      final clean = uriStr.trim();
      if (clean.isEmpty) return;
      
      // Normalize redapp://watch?id=... or /watch?id=...
      Uri uri;
      if (clean.startsWith('redapp://')) {
        uri = Uri.parse(clean.replaceFirst('redapp://', 'http://'));
      } else if (clean.startsWith('/')) {
        uri = Uri.parse('http://watch$clean');
      } else {
        uri = Uri.parse(clean);
      }

      int? id;
      String type = 'series';

      if (uri.queryParameters.containsKey('id')) {
        id = int.tryParse(uri.queryParameters['id'] ?? '');
      }
      if (uri.queryParameters.containsKey('type')) {
        type = uri.queryParameters['type'] ?? 'series';
      }

      // Also support path format: watch/movie/123 or watch/123
      if (id == null && uri.pathSegments.isNotEmpty) {
        for (var segment in uri.pathSegments) {
          final parsed = int.tryParse(segment);
          if (parsed != null && parsed > 0) {
            id = parsed;
            break;
          }
          if (segment.toLowerCase() == 'movie') type = 'movie';
          if (segment.toLowerCase() == 'series') type = 'series';
        }
      }

      if (id != null && id > 0) {
        final ctx = navKey.currentContext;
        if (ctx != null) {
          Navigator.of(ctx).push(
            MaterialPageRoute(
              builder: (_) => DetailsScreen(contentId: id!, itemType: type),
            ),
          );
        }
      }
    } catch (_) {}
  }
}
