import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../screens/navigation_helper.dart';
import '../screens/details_screen.dart';
import '../screens/web_series_detail_screen.dart';

class DeepLinkService {
  static const MethodChannel _channel = MethodChannel('com.red.app/deeplink');
  static bool _initialized = false;
  static bool _isAppReady = false;
  static String? _pendingLink;
  static GlobalKey<NavigatorState>? _navKey;

  static void init(GlobalKey<NavigatorState> navKey) {
    if (_initialized) return;
    _initialized = true;
    _navKey = navKey;

    // Listen to native method calls (onLink from onNewIntent / warm start)
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onLink') {
        final link = call.arguments?.toString();
        if (link != null && link.isNotEmpty) {
          handleUriString(link);
        }
      }
    });

    // Check cold-start link from native method channel
    _checkInitialLink();

    // Fallback: check platform default route name
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final defaultRoute = WidgetsBinding.instance.platformDispatcher.defaultRouteName;
      if (defaultRoute.isNotEmpty && defaultRoute != '/') {
        handleUriString(defaultRoute);
      }
    });
  }

  static Future<void> _checkInitialLink() async {
    try {
      final link = await _channel.invokeMethod<String>('getInitialLink');
      if (link != null && link.isNotEmpty) {
        handleUriString(link);
      }
    } catch (_) {}
  }

  static void onAppReady(BuildContext context) {
    _isAppReady = true;
    if (_pendingLink != null) {
      final link = _pendingLink!;
      _pendingLink = null;
      _navigateToDetails(link, context);
    }
  }

  static void handleUriString(String uriStr) {
    final clean = uriStr.trim();
    if (clean.isEmpty) return;

    if (!_isAppReady) {
      _pendingLink = clean;
      return;
    }

    final ctx = _navKey?.currentContext;
    if (ctx != null && ctx.mounted) {
      _navigateToDetails(clean, ctx);
    } else {
      _pendingLink = clean;
    }
  }

  static void _navigateToDetails(String uriStr, BuildContext context) {
    try {
      final parsedData = parseDeepLink(uriStr);
      if (parsedData == null) return;

      final int id = parsedData['id'];
      final String type = parsedData['type'];

      if (type == 'series' || type == '2') {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => WebSeriesDetailScreen(contentId: id),
          ),
        );
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DetailsScreen(contentId: id, itemType: type),
          ),
        );
      }
    } catch (e) {
      print("DeepLink navigate error: $e");
    }
  }

  static Map<String, dynamic>? parseDeepLink(String uriStr) {
    try {
      final clean = uriStr.trim();
      if (clean.isEmpty) return null;

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

      // 1. Query parameters check: ?id=1321 or ?content_id=1321
      if (uri.queryParameters.containsKey('id')) {
        id = int.tryParse(uri.queryParameters['id'] ?? '');
      } else if (uri.queryParameters.containsKey('content_id')) {
        id = int.tryParse(uri.queryParameters['content_id'] ?? '');
      }

      if (uri.queryParameters.containsKey('type')) {
        type = uri.queryParameters['type'] ?? 'series';
      } else if (uri.queryParameters.containsKey('content_type')) {
        final ct = uri.queryParameters['content_type'];
        type = (ct == '1' || ct == 'movie') ? 'movie' : 'series';
      }

      // 2. Path segments check: e.g. /watch/movie/1321 or /watch/1321 or /series/1321
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
        return {'id': id, 'type': type};
      }
    } catch (_) {}
    return null;
  }
}
