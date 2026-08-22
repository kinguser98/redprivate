import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ScraperSource {
  final String id;
  final String name;
  final String logo;
  final bool searchEnabled;
  final String domain;
  final int sortOrder;

  ScraperSource({
    required this.id,
    required this.name,
    required this.logo,
    required this.searchEnabled,
    this.domain = '',
    this.sortOrder = 0,
  });

  factory ScraperSource.fromJson(Map<String, dynamic> json) {
    return ScraperSource(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      logo: json['logo']?.toString() ?? '',
      searchEnabled: json['search_enabled'] == true,
      domain: json['domain']?.toString() ?? '',
      sortOrder: int.tryParse(json['sort_order']?.toString() ?? '') ?? 0,
    );
  }
}

class ScraperCategory {
  final String slug;
  final String name;

  ScraperCategory({required this.slug, required this.name});

  factory ScraperCategory.fromJson(Map<String, dynamic> json) {
    return ScraperCategory(
      slug: json['slug']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}

class ScraperCard {
  final String title;
  final String link;
  final String poster;
  final String duration;

  ScraperCard({
    required this.title,
    required this.link,
    required this.poster,
    this.duration = '',
  });

  factory ScraperCard.fromJson(Map<String, dynamic> json) {
    return ScraperCard(
      title: json['title']?.toString() ?? '',
      link: json['link']?.toString() ?? '',
      poster: json['poster']?.toString() ?? '',
      duration: json['duration']?.toString() ?? '',
    );
  }
}

class ScraperResolveResult {
  final Map<String, String> qualities;
  final Map<String, String> headers;

  ScraperResolveResult({
    required this.qualities,
    this.headers = const {},
  });
}

class ScraperService {
  static String get _apiBase => '${ApiConfig.baseUrl}/scraper_api.php';

  static Future<List<ScraperSource>> fetchSources() async {
    try {
      final res = await http.get(Uri.parse('$_apiBase?action=list_sources')).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['status'] == 'success' && data['sources'] is List) {
          return (data['sources'] as List).map((s) => ScraperSource.fromJson(s)).toList();
        }
      }
    } catch (e) {
      print("fetchSources error: $e");
    }
    return [
      ScraperSource(id: 'fpo', name: 'FPO.xxx', logo: '', searchEnabled: true)
    ];
  }

  static Future<List<ScraperCategory>> fetchCategories(String sourceId) async {
    try {
      final url = '$_apiBase?action=fetch_categories&source=${Uri.encodeComponent(sourceId)}';
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['status'] == 'success' && data['categories'] is List) {
          return (data['categories'] as List)
              .map((c) => ScraperCategory.fromJson(c))
              .where((c) => c.slug.isNotEmpty)
              .toList();
        }
      }
    } catch (e) {
      print("fetchCategories error: $e");
    }
    return [];
  }

  static Future<List<ScraperCard>> fetchGrid(String sourceId,
      {int page = 1, String query = '', String category = ''}) async {
    try {
      final qParam = Uri.encodeComponent(query);
      var url = '$_apiBase?action=fetch_grid&source=$sourceId&page=$page&query=$qParam';
      if (category.isNotEmpty) {
        url += '&category=${Uri.encodeComponent(category)}';
      }
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 40));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['status'] == 'success' && data['items'] is List) {
          return (data['items'] as List).map((i) => ScraperCard.fromJson(i)).toList();
        }
      }
    } catch (e) {
      print("fetchGrid error: $e");
    }
    return [];
  }

  static Future<ScraperResolveResult?> resolveItem(String detailUrl) async {
    try {
      final url = '$_apiBase?action=resolve_item&url=${Uri.encodeComponent(detailUrl)}';
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 40));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['status'] == 'success' && data['qualities'] is Map) {
          final Map<String, String> map = {};
          (data['qualities'] as Map).forEach((k, v) {
            map[k.toString()] = v.toString();
          });
          final Map<String, String> headers = {};
          if (data['headers'] is Map) {
            (data['headers'] as Map).forEach((k, v) {
              headers[k.toString()] = v.toString();
            });
          }
          return ScraperResolveResult(qualities: map, headers: headers);
        }
      }
    } catch (e) {
      print("resolveItem error: $e");
    }
    return null;
  }

  /// Fire-and-forget analytics ping from the Fly Mode page. Never blocks the UI
  /// and never throws — a failed ping is silently dropped.
  static Future<void> logFlyModeEvent({
    required int userId,
    required String userName,
    required String sourceId,
    required String sourceName,
    required String videoTitle,
    required String videoLink,
    required String action,
  }) async {
    try {
      await http
          .post(
            Uri.parse(ApiConfig.adminUrl),
            body: json.encode({
              'action': 'log_fly_play',
              'user_id': userId,
              'user_name': userName,
              'source_id': sourceId,
              'source_name': sourceName,
              'video_title': videoTitle,
              'video_link': videoLink,
              'event_type': action,
            }),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      // Non-blocking analytics logging — ignore failures.
    }
  }
}
