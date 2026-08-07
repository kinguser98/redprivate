import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/movie_model.dart';
import '../models/user_model.dart';
import '../models/series_model.dart';

class ApiService {
  // Parked content (status=0) IDs cached from the admin server, used to
  // hide dead content across ALL sources (catalog, cast, OTT, fallbacks).
  static Set<int> _parkedMovieIds = {};
  static Set<int> _parkedSeriesIds = {};
  static Set<String> _parkedMovieNames = {};
  static Set<String> _parkedSeriesNames = {};

  static const String _parkedMoviesKey = 'parked_movie_ids';
  static const String _parkedSeriesKey = 'parked_series_ids';
  static const String _parkedMoviesNameKey = 'parked_movie_names';
  static const String _parkedSeriesNameKey = 'parked_series_names';

  static String? _cachedDeviceId;

  static Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;
    final prefs = await SharedPreferences.getInstance();
    String? stored = prefs.getString('device_unique_id');
    if (stored == null || stored.isEmpty) {
      final rand = Random.secure();
      stored = List.generate(32, (_) => rand.nextInt(16).toRadixString(16)).join();
      await prefs.setString('device_unique_id', stored);
    }
    _cachedDeviceId = stored;
    return stored;
  }

  static String getDeviceName() {
    try {
      return '${Platform.operatingSystem} / ${Platform.localHostname}';
    } catch (_) {
      return 'Unknown Device';
    }
  }

  static Future<void> refreshParkedIds() async {
    // 1. Load cached IDs first so filtering works even if server is unreachable
    await _loadCachedParkedIds();
    // 2. Try to refresh from the admin server
    try {
      final res = await _postWithFallback(
        ApiConfig.adminUrl,
        {'Content-Type': 'application/json'},
        json.encode({'action': 'get_parked_ids'}),
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['status'] == 'success' && data['data'] != null) {
          _parkedMovieIds = (data['data']['movie_ids'] as List? ?? [])
              .map((e) => int.tryParse('$e') ?? 0)
              .where((id) => id > 0)
              .toSet();
          _parkedSeriesIds = (data['data']['series_ids'] as List? ?? [])
              .map((e) => int.tryParse('$e') ?? 0)
              .where((id) => id > 0)
              .toSet();
          _parkedMovieNames = (data['data']['movie_names'] as List? ?? [])
              .map((e) => e.toString().trim().toLowerCase())
              .where((n) => n.isNotEmpty)
              .toSet();
          _parkedSeriesNames = (data['data']['series_names'] as List? ?? [])
              .map((e) => e.toString().trim().toLowerCase())
              .where((n) => n.isNotEmpty)
              .toSet();
          await _saveCachedParkedIds();
        }
      }
    } catch (e) {
      print("refreshParkedIds error: $e");
    }
  }

  /// Fast: load cached parked IDs from disk only (no network). Used on the
  /// home screen so filtering works instantly without blocking on the API.
  static Future<void> loadParkedIdsFromCache() => _loadCachedParkedIds();

  static Future<void> _loadCachedParkedIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _parkedMovieIds = (prefs.getStringList(_parkedMoviesKey) ?? [])
          .map((e) => int.tryParse(e) ?? 0)
          .where((id) => id > 0)
          .toSet();
      _parkedSeriesIds = (prefs.getStringList(_parkedSeriesKey) ?? [])
          .map((e) => int.tryParse(e) ?? 0)
          .where((id) => id > 0)
          .toSet();
      _parkedMovieNames = (prefs.getStringList(_parkedMoviesNameKey) ?? [])
          .map((e) => e.toLowerCase())
          .toSet();
      _parkedSeriesNames = (prefs.getStringList(_parkedSeriesNameKey) ?? [])
          .map((e) => e.toLowerCase())
          .toSet();
    } catch (_) {}
  }

  static Future<void> _saveCachedParkedIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
          _parkedMoviesKey, _parkedMovieIds.map((e) => '$e').toList());
      await prefs.setStringList(
          _parkedSeriesKey, _parkedSeriesIds.map((e) => '$e').toList());
      await prefs.setStringList(
          _parkedMoviesNameKey, _parkedMovieNames.toList());
      await prefs.setStringList(
          _parkedSeriesNameKey, _parkedSeriesNames.toList());
    } catch (_) {}
  }

  static bool isParkedItem(int id, bool isSeries, String name) {
    if (id > 0) {
      if (isSeries && _parkedSeriesIds.contains(id)) return true;
      if (!isSeries && _parkedMovieIds.contains(id)) return true;
    }
    final cleanName = name.trim().toLowerCase();
    if (cleanName.isEmpty) return false;
    if (isSeries) return _parkedSeriesNames.contains(cleanName);
    return _parkedMovieNames.contains(cleanName);
  }

  static bool isParked(MovieModel m) {
    final isSeries = m.itemType == 'series' || m.itemType == '2';
    return isParkedItem(m.id, isSeries, m.name);
  }

  static List<MovieModel> filterParked(List<MovieModel> list) {
    if (_parkedMovieIds.isEmpty &&
        _parkedSeriesIds.isEmpty &&
        _parkedMovieNames.isEmpty &&
        _parkedSeriesNames.isEmpty) {
      return list;
    }
    return list.where((m) => !isParked(m)).toList();
  }
  static Future<http.Response> _postWithFallback(
      String urlStr, Map<String, String> headers, String body) async {
    final uri = Uri.parse(urlStr);
    try {
      return await http
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 8));
    } catch (e1) {
      print("POST Attempt 1 failed ($e1)");
    }

    try {
      final alternateScheme = uri.scheme == 'https' ? 'http' : 'https';
      final altUri = uri.replace(scheme: alternateScheme);
      return await http
          .post(altUri, headers: headers, body: body)
          .timeout(const Duration(seconds: 8));
    } catch (e2) {
      print("POST Attempt 2 failed ($e2)");
    }

    if (!kIsWeb) {
      try {
        final client = HttpClient();
        client.badCertificateCallback = (cert, host, port) => true;
        // Direct IP bypass if carrier DNS/SNI blocks red.goprivate.fun
        final hostHeader = uri.host;
        final ipUrl = Uri.parse(
            "https://red.goprivate.fun${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}");
        print("POST Attempt 3 Direct URL: $ipUrl");
        final request =
            await client.postUrl(ipUrl).timeout(const Duration(seconds: 8));
        request.headers.set('Host', hostHeader);
        headers.forEach((k, v) {
          if (k.toLowerCase() != 'host') request.headers.set(k, v);
        });
        request.write(body);
        final response =
            await request.close().timeout(const Duration(seconds: 8));
        final resBody = await response
            .transform(utf8.decoder)
            .join()
            .timeout(const Duration(seconds: 8));
        return http.Response(resBody, response.statusCode);
      } catch (e3) {
        print("POST Attempt 3 failed ($e3)");
      }
    }
    throw Exception("Connection failed on all network attempts.");
  }

  static Future<http.Response> _getWithFallback(String urlStr) async {
    final uri = Uri.parse(urlStr);
    final headers = ApiConfig.headers;
    try {
      return await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 8));
    } catch (e1) {
      print("GET Attempt 1 failed ($e1)");
    }

    try {
      final alternateScheme = uri.scheme == 'https' ? 'http' : 'https';
      final altUri = uri.replace(scheme: alternateScheme);
      return await http
          .get(altUri, headers: headers)
          .timeout(const Duration(seconds: 8));
    } catch (e2) {
      print("GET Attempt 2 failed ($e2)");
    }

    if (!kIsWeb) {
      try {
        final client = HttpClient();
        client.badCertificateCallback = (cert, host, port) => true;
        final hostHeader = uri.host;
        final ipUrl = Uri.parse(
            "https://red.goprivate.fun${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}");
        print("GET Attempt 3 Direct URL: $ipUrl");
        final request =
            await client.getUrl(ipUrl).timeout(const Duration(seconds: 8));
        request.headers.set('Host', hostHeader);
        headers.forEach((k, v) {
          if (k.toLowerCase() != 'host') request.headers.set(k, v);
        });
        final response =
            await request.close().timeout(const Duration(seconds: 8));
        final resBody = await response
            .transform(utf8.decoder)
            .join()
            .timeout(const Duration(seconds: 8));
        return http.Response(resBody, response.statusCode);
      } catch (e3) {
        print("GET Attempt 3 failed ($e3)");
      }
    }
    throw Exception("Connection error on: $urlStr");
  }

  // Auth Services
  static Future<Map<String, dynamic>> login(
      String email, String password, {bool forceLogin = false}) async {
    try {
      final deviceId = await getDeviceId();
      final deviceName = getDeviceName();
      final body = 'action=login'
          '&email=${Uri.encodeComponent(email)}'
          '&password=${Uri.encodeComponent(password)}'
          '&device_id=${Uri.encodeComponent(deviceId)}'
          '&device_name=${Uri.encodeComponent(deviceName)}'
          '&force_login=${forceLogin ? 1 : 0}';
      final res = await _postWithFallback(
        ApiConfig.authUrl,
        {'Content-Type': 'application/x-www-form-urlencoded'},
        body,
      );
      if (res.statusCode == 200) {
        return json.decode(res.body);
      } else {
        return {
          'status': 'error',
          'message': 'HTTP ${res.statusCode}: ${res.reasonPhrase}'
        };
      }
    } catch (e) {
      return {'status': 'error', 'message': 'Connection error: $e'};
    }
  }

  static Future<Map<String, dynamic>> register(
      String name, String email, String password) async {
    try {
      final deviceId = await getDeviceId();
      final deviceName = getDeviceName();
      final body = 'action=register'
          '&name=${Uri.encodeComponent(name)}'
          '&email=${Uri.encodeComponent(email)}'
          '&password=${Uri.encodeComponent(password)}'
          '&device_id=${Uri.encodeComponent(deviceId)}'
          '&device_name=${Uri.encodeComponent(deviceName)}';
      final res = await _postWithFallback(
        ApiConfig.authUrl,
        {'Content-Type': 'application/x-www-form-urlencoded'},
        body,
      );
      if (res.statusCode == 200) {
        return json.decode(res.body);
      } else {
        return {
          'status': 'error',
          'message': 'HTTP ${res.statusCode}: ${res.reasonPhrase}'
        };
      }
    } catch (e) {
      return {'status': 'error', 'message': 'Connection error: $e'};
    }
  }

  // Log a content view (feeds trending on the home screen)
  static Future<void> logView(int contentId, String itemType) async {
    try {
      final uid = AppSession.user?.id?.toString() ?? '1';
      final type = (itemType == 'movie' || itemType == '1') ? 1 : 2;
      await _postWithFallback(
        ApiConfig.adminUrl,
        {'Content-Type': 'application/x-www-form-urlencoded'},
        'action=log_view&user_id=$uid&content_id=$contentId&content_type=$type',
      );
    } catch (e) {
      print("logView error: $e");
    }
  }

  // Favorites (user-wise)
  static Future<Map<String, dynamic>> addFavorite(
      int contentId, String itemType, {String name = '', String poster = ''}) async {
    final res = await _favoriteAction('add_favorite', contentId, itemType);
    await _updateLocalFavorites(contentId, itemType, name: name, poster: poster, remove: false);
    return res;
  }

  static Future<Map<String, dynamic>> removeFavorite(
      int contentId, String itemType) async {
    final res = await _favoriteAction('remove_favorite', contentId, itemType);
    await _updateLocalFavorites(contentId, itemType, remove: true);
    return res;
  }

  static Future<Map<String, dynamic>> _favoriteAction(
      String action, int contentId, String itemType) async {
    try {
      final uid = AppSession.user?.id?.toString() ?? '1';
      final type = (itemType == 'movie' || itemType == '1') ? 1 : 2;
      final res = await _postWithFallback(
        ApiConfig.adminUrl,
        {'Content-Type': 'application/x-www-form-urlencoded'},
        'action=$action&user_id=$uid&content_id=$contentId&content_type=$type',
      );
      if (res.statusCode == 200) return json.decode(res.body);
    } catch (e) {
      print("favoriteAction error: $e");
    }
    return {'status': 'error', 'message': 'Failed to update favorites'};
  }

  static Future<List<dynamic>> getFavorites() async {
    try {
      final uid = AppSession.user?.id?.toString() ?? '1';
      final res = await _postWithFallback(
        ApiConfig.adminUrl,
        {'Content-Type': 'application/x-www-form-urlencoded'},
        'action=get_favorites&user_id=$uid',
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['status'] == 'success' && data['data']?['favorites'] != null) {
          final list = data['data']['favorites'];
          await _saveLocalFavorites(list);
          return list;
        }
      }
    } catch (e) {
      print("getFavorites error: $e");
    }
    return _loadLocalFavorites();
  }

  // ── Local favorites cache (works offline / when server is slow) ──
  static const String _favKey = 'local_favorites';

  static Future<void> _saveLocalFavorites(List<dynamic> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_favKey, json.encode(list));
    } catch (_) {}
  }

  static Future<List<dynamic>> _loadLocalFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_favKey);
      if (str != null) {
        final decoded = json.decode(str);
        if (decoded is List) return decoded;
      }
    } catch (_) {}
    return [];
  }

  static Future<void> _updateLocalFavorites(int contentId, String itemType,
      {String name = '', String poster = '', required bool remove}) async {
    try {
      final type = (itemType == 'movie' || itemType == '1') ? 1 : 2;
      final list = await _loadLocalFavorites();
      list.removeWhere((f) =>
          int.tryParse('${f['content_id']}') == contentId &&
          int.tryParse('${f['content_type']}') == type);
      if (!remove) {
        list.insert(0, {
          'content_id': contentId,
          'content_type': type,
          'item_type': type == 1 ? 'movie' : 'series',
          'name': name,
          'poster': poster,
        });
      }
      await _saveLocalFavorites(list);
    } catch (_) {}
  }

  // Update profile (name, profile pic, password)
  static Future<Map<String, dynamic>> updateProfile({
    required String name,
    String profilePic = '',
    String currentPassword = '',
    String newPassword = '',
  }) async {
    try {
      final uid = AppSession.user?.id?.toString() ?? '1';
      final body =
          'action=update_profile&user_id=$uid&name=${Uri.encodeComponent(name)}'
          '&profile_pic=${Uri.encodeComponent(profilePic)}'
          '&current_password=${Uri.encodeComponent(currentPassword)}'
          '&new_password=${Uri.encodeComponent(newPassword)}';
      final res = await _postWithFallback(
        ApiConfig.authUrl,
        {'Content-Type': 'application/x-www-form-urlencoded'},
        body,
      );
      if (res.statusCode == 200) return json.decode(res.body);
      return {'status': 'error', 'message': 'HTTP ${res.statusCode}'};
    } catch (e) {
      return {'status': 'error', 'message': 'Connection error: $e'};
    }
  }

  // Subscription details (current plan + history + available plans)
  static Future<Map<String, dynamic>> getSubscriptionDetails() async {
    try {
      final uid = AppSession.user?.id?.toString() ?? '1';
      final res = await _postWithFallback(
        ApiConfig.adminUrl,
        {'Content-Type': 'application/x-www-form-urlencoded'},
        'action=get_subscription_details&user_id=$uid',
      );
      if (res.statusCode == 200) return json.decode(res.body);
    } catch (e) {
      print("getSubscriptionDetails error: $e");
    }
    return {'status': 'error', 'message': 'Failed to load subscription details'};
  }

  // Fetch the latest user (VIP status) from the server
  // Also validates the device session — returns null if kicked out by another login
  static Future<UserModel?> refreshUser(int userId) async {
    try {
      final deviceId = await getDeviceId();
      final res = await _postWithFallback(
        ApiConfig.authUrl,
        {'Content-Type': 'application/x-www-form-urlencoded'},
        'action=get_user&user_id=$userId&device_id=${Uri.encodeComponent(deviceId)}',
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['data']?['logged_out'] == true) {
          // Another device took over this session — force logout
          AppSession.triggerGlobalLogout();
          return null;
        }
        if (data['status'] == 'success' && data['data']?['user'] != null) {
          return UserModel.fromJson(data['data']['user']);
        }
      }
    } catch (e) {
      print("refreshUser error: $e");
    }
    return null;
  }

  // Home Screen Data
  static Future<Map<String, dynamic>> fetchHomeData(int userId) async {
    try {
      final url = "${ApiConfig.homeUrl}?user_id=$userId";
      print("Fetching Home Data from: $url");
      final res = await _getWithFallback(url);
      print("Home Data HTTP ${res.statusCode}");
      if (res.statusCode == 200) {
        final decoded = json.decode(res.body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }
      return {
        'status': 'error',
        'message': 'HTTP ${res.statusCode}: ${res.reasonPhrase}'
      };
    } catch (e) {
      print("Fetch home data error: $e");
      return {
        'status': 'error',
        'message': 'Network Error (Check Wi-Fi / Mobile Data): $e'
      };
    }
  }

  // Official Dooo REST API: Network (Cast Member) Contents
  static Future<List<MovieModel>> fetchNetworkContents(int networkId) async {
    try {
      final url = "${ApiConfig.baseUrl}/getAllContentsOfNetwork/$networkId";
      print("Fetching Cast Network Content from: $url");
      final res = await _getWithFallback(url);
      if (res.statusCode == 200) {
        final decoded = json.decode(res.body);
        if (decoded is List) {
          return filterParked(
              decoded.map((item) => MovieModel.fromJson(item)).toList());
        }
      }
    } catch (e) {
      print("fetchNetworkContents error: $e");
    }
    return [];
  }

  // Official Dooo REST API: Genre (OTT Platform) Contents
  static Future<List<MovieModel>> fetchGenreContents(String genreName) async {
    try {
      final url =
          "${ApiConfig.baseUrl}/getContentsReletedToGenre/${Uri.encodeComponent(genreName)}";
      print("Fetching OTT Genre Content from: $url");
      final res = await _getWithFallback(url);
      if (res.statusCode == 200) {
        final decoded = json.decode(res.body);
        if (decoded is List) {
          return filterParked(
              decoded.map((item) => MovieModel.fromJson(item)).toList());
        }
      }
    } catch (e) {
      print("fetchGenreContents error: $e");
    }
    return [];
  }

  static Future<List<dynamic>> fetchOttGenres() async {
    try {
      final res = await _postWithFallback(
        ApiConfig.adminUrl,
        {'Content-Type': 'application/json'},
        json.encode({'action': 'get_taxonomy'}),
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['status'] == 'success' && data['data'] != null) {
          // ott_platforms = OTT platforms (Voovi, Rabbit, Kooku etc. from genres table)
          final networks = (data['data']['ott_platforms'] as List? ?? []);
          return networks.where((o) {
            final name = (o['name'] ?? '').toString().trim();
            return name.isNotEmpty;
          }).toList();
        }
      }
    } catch (e) {
      print("fetchOttGenres error: $e");
    }
    return [];
  }

  // Catalog Search & Filters
  static Future<List<MovieModel>> fetchContent({
    String type = 'all',
    String search = '',
    String genre = '',
    int networkId = 0,
    String sort = 'latest',
    int page = 1,
  }) async {
    // 1. Primary: admin server catalog (movies + series mixed, date-ordered)
    try {
      String queryParams = "type=$type&sort=$sort&page=$page";
      if (search.isNotEmpty) {
        queryParams += "&search=${Uri.encodeComponent(search)}";
      }
      if (genre.isNotEmpty) {
        queryParams += "&genre=${Uri.encodeComponent(genre)}";
      }
      if (networkId > 0) {
        queryParams += "&network_id=$networkId";
      }
      final url = "${ApiConfig.contentUrl}?$queryParams";
      print("Fetching Content from: $url");
      final res = await _getWithFallback(url);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['status'] == 'success' && data['data']?['items'] != null) {
          final list = (data['data']['items'] as List)
              .map((item) => MovieModel.fromJson(item))
              .toList();
          if (list.isNotEmpty) return filterParked(list);
        }
      }
    } catch (e) {
      print("Fetch content error: $e");
    }

    // 2. Fallback: official Dooo REST API endpoints
    if (networkId > 0) {
      final list = await fetchNetworkContents(networkId);
      if (list.isNotEmpty) return list;
    }
    if (genre.isNotEmpty) {
      final list = await fetchGenreContents(genre);
      if (list.isNotEmpty) return list;
    }
    return [];
  }

  // Content Details
  static Future<Map<String, dynamic>> fetchDetails(int id, String type) async {
    try {
      final url = "${ApiConfig.detailsUrl}?id=$id&type=$type";
      print("Fetching Details from: $url");
      final res = await _getWithFallback(url);
      if (res.statusCode == 200) {
        return json.decode(res.body);
      }
      return {'status': 'error', 'message': 'HTTP ${res.statusCode}'};
    } catch (e) {
      print("Fetch details error: $e");
      return {'status': 'error', 'message': 'Network Error: $e'};
    }
  }

  // Official Dooo REST API: Upcoming Contents
  static Future<List<Map<String, dynamic>>> fetchUpcomingContents(
      {int page = 1}) async {
    try {
      final url = "${ApiConfig.baseUrl}/getAllUpcomingContents/$page";
      final res = await _getWithFallback(url);
      if (res.statusCode == 200) {
        final decoded = json.decode(res.body);
        if (decoded is List) {
          return List<Map<String, dynamic>>.from(decoded);
        }
      }
    } catch (e) {
      print("fetchUpcomingContents error: $e");
    }
    return [];
  }

  // Official Dooo REST API: Subscription Plans
  static Future<List<Map<String, dynamic>>> fetchSubscriptionPlans() async {
    try {
      final url = "${ApiConfig.baseUrl}/getSubscriptionPlans";
      final res = await _getWithFallback(url);
      if (res.statusCode == 200) {
        final decoded = json.decode(res.body);
        if (decoded is List) {
          return List<Map<String, dynamic>>.from(decoded);
        }
      }
    } catch (e) {
      print("fetchSubscriptionPlans error: $e");
    }
    return [];
  }

  // Admin API: Redeem Coupon (grants VIP via the admin backend)
  static Future<Map<String, dynamic>> redeemCoupon(
      int userId, String couponCode) async {
    try {
      final url = ApiConfig.adminUrl;
      final res = await _postWithFallback(
        url,
        {'Content-Type': 'application/json'},
        json.encode({
          'action': 'redeem_coupon',
          'user_id': userId,
          'coupon_code': couponCode,
        }),
      );
      if (res.statusCode == 200) {
        return json.decode(res.body);
      }
    } catch (e) {
      print("redeemCoupon error: $e");
    }
    return {'status': 'error', 'message': 'Failed to redeem coupon'};
  }

  // Report Content Link
  static Future<bool> submitReport(
      int userId, int contentId, int contentType, String message) async {
    try {
      final res = await _postWithFallback(
        ApiConfig.adminUrl,
        {'Content-Type': 'application/json'},
        json.encode({
          'action': 'submit_report',
          'user_id': userId,
          'content_id': contentId,
          'content_type': contentType,
          'message': message,
        }),
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        return data['status'] == 'success';
      }
    } catch (e) {
      print("submitReport error: $e");
    }
    return false;
  }

  // Fetch report replies (notifications) for the current user
  static Future<List<dynamic>> fetchUserReportReplies(int userId) async {
    try {
      final res = await _postWithFallback(
        ApiConfig.adminUrl,
        {'Content-Type': 'application/json'},
        json.encode({
          'action': 'get_user_notifications',
          'user_id': userId,
        }),
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['status'] == 'success' && data['data']?['notifications'] != null) {
          return data['data']['notifications'] as List;
        }
      }
    } catch (e) {
      print("fetchUserReportReplies error: $e");
    }
    return [];
  }

  // Fetch Series Catalog with Seasons, Episodes and Play Links
  static Future<List<SeriesItemModel>> fetchSeriesContent(
      {String search = '', String sort = 'latest'}) async {
    try {
      final url =
          "${ApiConfig.baseUrl}/series_content.php?search=${Uri.encodeComponent(search)}&sort=$sort";
      final res = await _getWithFallback(url);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['status'] == 'success' && data['data']?['items'] != null) {
          final list = (data['data']['items'] as List)
              .map((item) => SeriesItemModel.fromJson(item))
              .toList();
          return list.where((s) => !isParkedItem(s.id, true, s.name)).toList();
        }
      }
    } catch (e) {
      print("Fetch series content error: $e");
    }
    return [];
  }

  // Keep Alive Streamtape Links (Admin)
  static Future<bool> pingKeepAlive() async {
    try {
      final res = await http
          .get(Uri.parse("${ApiConfig.linkHealthUrl}?action=keep_alive"));
      final data = json.decode(res.body);
      return data['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  // Get Dead Links Queue (Admin)
  static Future<List<dynamic>> fetchDeadLinks() async {
    try {
      final res = await http
          .get(Uri.parse("${ApiConfig.linkHealthUrl}?action=get_dead_links"));
      final data = json.decode(res.body);
      if (data['status'] == 'success' && data['data']?['dead_links'] != null) {
        return data['data']['dead_links'];
      }
    } catch (e) {
      print("Fetch dead links error: $e");
    }
    return [];
  }

  // Replace Broken Link (Admin)
  static Future<bool> replaceLink(
      int linkId, String newUrl, String type) async {
    try {
      final res = await http.post(
        Uri.parse(ApiConfig.linkHealthUrl),
        body: json.encode({
          'action': 'replace_link',
          'link_id': linkId,
          'new_url': newUrl,
          'type': type
        }),
        headers: {'Content-Type': 'application/json'},
      );
      final data = json.decode(res.body);
      return data['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  // App Settings (from admin panel)
  static Future<Map<String, dynamic>> fetchAppSettings() async {
    try {
      final res = await _postWithFallback(
        ApiConfig.adminUrl,
        {'Content-Type': 'application/json'},
        json.encode({'action': 'get_app_settings'}),
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['status'] == 'success' && data['data']?['settings'] != null) {
          final s = data['data']['settings'];
          final prefs = await SharedPreferences.getInstance();
          if (s['streamtape_api_domains'] != null) {
            await prefs.setString('admin_streamtape_api_domains', s['streamtape_api_domains'].toString());
          }
          if (s['streamtape_family_domains'] != null) {
            await prefs.setString('admin_streamtape_family_domains', s['streamtape_family_domains'].toString());
          }
        }
        return data;
      }
    } catch (e) {
      print("fetchAppSettings error: $e");
    }
    return {'status': 'error', 'message': 'Failed to load settings'};
  }

  // User Local Storage Persistence
  static Future<void> saveUserSession(UserModel user) async {    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_data', json.encode(user.toJson()));
  }

  static Future<UserModel?> getUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('user_data');
    if (str != null) {
      return UserModel.fromJson(json.decode(str));
    }
    return null;
  }

  static Future<Map<String, dynamic>> clearWatchHistory(String userId) async {
    try {
      final url = "${ApiConfig.baseUrl}/home.php?action=clear_watch_history&user_id=$userId";
      final res = await http.post(Uri.parse(url));
      if (res.statusCode == 200) {
        return json.decode(res.body);
      }
      return {'status': 'error', 'message': 'HTTP ${res.statusCode}'};
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_data');
  }

  // Live Telemetry / Analytics
  static Future<void> sendHeartbeat(int userId, String currentView, {int? contentId, int? contentType}) async {
    if (userId <= 0) return;
    try {
      await _postWithFallback(
        ApiConfig.adminUrl,
        {'Content-Type': 'application/json'},
        json.encode({
          'action': 'heartbeat',
          'user_id': userId,
          'current_view': currentView,
          'app_version': ApiConfig.currentVersion,
          if (contentId != null) 'content_id': contentId,
          if (contentType != null) 'content_type': contentType,
        }),
      );
    } catch (_) {}
  }

  static Future<void> logPlayEvent(int userId, int contentId, int contentType, int durationSec, int completed) async {
    if (userId <= 0 || contentId <= 0) return;
    try {
      await _postWithFallback(
        ApiConfig.adminUrl,
        {'Content-Type': 'application/json'},
        json.encode({
          'action': 'log_play_event',
          'user_id': userId,
          'content_id': contentId,
          'content_type': contentType,
          'duration_seconds': durationSec,
          'completed': completed,
        }),
      );
    } catch (_) {}
  }

  static Future<void> logDownloadEvent(int userId, int contentId, int contentType, String status) async {
    if (userId <= 0 || contentId <= 0) return;
    try {
      await _postWithFallback(
        ApiConfig.adminUrl,
        {'Content-Type': 'application/json'},
        json.encode({
          'action': 'log_download_event',
          'user_id': userId,
          'content_id': contentId,
          'content_type': contentType,
          'status': status,
        }),
      );
    } catch (_) {}
  }
}
