import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ScraperSource {
  final String id;
  final String name;
  final String logo;
  final bool searchEnabled;

  ScraperSource({
    required this.id,
    required this.name,
    required this.logo,
    required this.searchEnabled,
  });

  factory ScraperSource.fromJson(Map<String, dynamic> json) {
    return ScraperSource(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      logo: json['logo']?.toString() ?? '',
      searchEnabled: json['search_enabled'] == true,
    );
  }
}

class ScraperCard {
  final String title;
  final String link;
  final String poster;

  ScraperCard({
    required this.title,
    required this.link,
    required this.poster,
  });

  factory ScraperCard.fromJson(Map<String, dynamic> json) {
    return ScraperCard(
      title: json['title']?.toString() ?? '',
      link: json['link']?.toString() ?? '',
      poster: json['poster']?.toString() ?? '',
    );
  }
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

  static Future<List<ScraperCard>> fetchGrid(String sourceId, {int page = 1, String query = ''}) async {
    try {
      final qParam = Uri.encodeComponent(query);
      final url = '$_apiBase?action=fetch_grid&source=$sourceId&page=$page&query=$qParam';
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
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

  static Future<Map<String, String>?> resolveItem(String detailUrl) async {
    try {
      final url = '$_apiBase?action=resolve_item&url=${Uri.encodeComponent(detailUrl)}';
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['status'] == 'success' && data['qualities'] is Map) {
          final Map<String, String> map = {};
          (data['qualities'] as Map).forEach((k, v) {
            map[k.toString()] = v.toString();
          });
          return map;
        }
      }
    } catch (e) {
      print("resolveItem error: $e");
    }
    return null;
  }
}
