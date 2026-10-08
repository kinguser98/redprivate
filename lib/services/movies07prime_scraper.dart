import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class Movies07PrimeItem {
  final int id;
  final String title;
  final String type; // 'movie' or 'series'
  final String releaseDate;
  final String poster;
  final String pageUrl;

  Movies07PrimeItem({
    required this.id,
    required this.title,
    required this.type,
    required this.releaseDate,
    required this.poster,
    required this.pageUrl,
  });
}

class Movies07PrimeScraper {
  static const String defaultBaseUrl = 'https://movies07prime.com';
  static String _currentDomain = defaultBaseUrl;

  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept': 'application/json, text/javascript, text/html, */*; q=0.01',
    'Accept-Language': 'en-US,en;q=0.9',
    'X-Requested-With': 'XMLHttpRequest',
  };

  /// Get currently configured domain from SharedPreferences
  static Future<String> getDomain() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('admin_movies07prime_domain');
      if (saved != null && saved.trim().isNotEmpty) {
        _currentDomain = _normalizeDomain(saved.trim());
        return _currentDomain;
      }
    } catch (_) {}
    _currentDomain = defaultBaseUrl;
    return _currentDomain;
  }

  /// Save new domain to SharedPreferences
  static Future<void> saveDomain(String domain) async {
    final normalized = _normalizeDomain(domain);
    _currentDomain = normalized;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('admin_movies07prime_domain', normalized);
    } catch (_) {}
  }

  /// Reset domain to default
  static Future<void> resetDomain() async {
    _currentDomain = defaultBaseUrl;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('admin_movies07prime_domain');
    } catch (_) {}
  }

  static String _normalizeDomain(String raw) {
    var d = raw.trim();
    if (d.isEmpty) return defaultBaseUrl;
    if (!d.startsWith('http://') && !d.startsWith('https://')) {
      d = 'https://$d';
    }
    return d.replaceAll(RegExp(r'/+$'), '');
  }

  /// Clean HTML entities and doubled domain prefixes in URLs
  static String _cleanText(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&#039;', "'")
        .replaceAll('&quot;', '"')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
  }

  static String _cleanUrl(String raw, String baseUrl) {
    var url = raw.trim();
    final doublePrefix = '$baseUrl/$baseUrl/';
    if (url.startsWith(doublePrefix)) {
      url = url.replaceFirst(doublePrefix, '$baseUrl/');
    }
    if (url.startsWith('https://movies07prime.com/https://movies07prime.com/')) {
      url = url.replaceFirst(
          'https://movies07prime.com/https://movies07prime.com/',
          'https://movies07prime.com/');
    }
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    if (url.startsWith('//')) {
      return 'https:$url';
    }
    if (url.startsWith('/')) {
      return '$baseUrl$url';
    }
    return '$baseUrl/$url';
  }

  /// Search Movies07Prime for portrait posters
  static Future<List<Movies07PrimeItem>> search(
    String query, {
    String? overrideDomain,
    Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)? adminApi,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    final baseUrl = overrideDomain != null && overrideDomain.trim().isNotEmpty
        ? _normalizeDomain(overrideDomain)
        : await getDomain();

    final results = <Movies07PrimeItem>[];
    final headers = Map<String, String>.from(_headers);
    headers['Referer'] = '$baseUrl/';
    headers['Origin'] = baseUrl;

    // 1. Try instant JSON suggestions API on the configured domain
    try {
      final apiUrl =
          '$baseUrl/search/suggestions?s=${Uri.encodeQueryComponent(cleanQuery)}';
      final res = await http
          .get(Uri.parse(apiUrl), headers: headers)
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200 && res.body.trim().startsWith('[')) {
        final List list = jsonDecode(res.body);
        for (final item in list) {
          if (item is Map) {
            final title = _cleanText((item['name'] ?? '').toString());
            final posterRaw = (item['series_poster'] ??
                    item['video_image_thumb'] ??
                    '')
                .toString();
            final poster = _cleanUrl(posterRaw, baseUrl);
            final type = (item['type'] ?? 'movie').toString();
            final releaseDate = (item['release_date'] ?? '').toString();
            final id = int.tryParse('${item['id']}') ?? 0;
            final pageUrl = _cleanUrl((item['url'] ?? '').toString(), baseUrl);

            if (poster.isNotEmpty && !results.any((it) => it.poster == poster)) {
              results.add(Movies07PrimeItem(
                id: id,
                title: title.isNotEmpty ? title : 'Untitled',
                type: type,
                releaseDate: releaseDate,
                poster: poster,
                pageUrl: pageUrl,
              ));
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Movies07Prime suggestions API error: $e");
    }

    // 2. Fallback to HTML search page if suggestions returned 0 results
    if (results.isEmpty) {
      try {
        final searchUrl =
            '$baseUrl/search?s=${Uri.encodeQueryComponent(cleanQuery)}';
        final res = await http
            .get(Uri.parse(searchUrl), headers: headers)
            .timeout(const Duration(seconds: 8));

        if (res.statusCode == 200) {
          final html = res.body;
          final matches = RegExp(
            r'<img[^>]+src=["\x27]([^"\x27]*video_thumb[^"\x27]*|[^"\x27]*uploads[^"\x27]*)["\x27][^>]*alt=["\x27]([^"\x27]*)["\x27]',
            caseSensitive: false,
          ).allMatches(html);

          int autoId = 1000;
          for (final m in matches) {
            final rawSrc = m.group(1) ?? '';
            final rawAlt = m.group(2) ?? '';
            final poster = _cleanUrl(rawSrc, baseUrl);
            final title = _cleanText(rawAlt);
            if (poster.isNotEmpty &&
                !results.any((it) => it.poster == poster)) {
              results.add(Movies07PrimeItem(
                id: autoId++,
                title: title.isNotEmpty ? title : 'Poster Image',
                type: title.toLowerCase().contains('s01') ||
                        title.toLowerCase().contains('s02') ||
                        title.toLowerCase().contains('series')
                    ? 'series'
                    : 'movie',
                releaseDate: '',
                poster: poster,
                pageUrl: '',
              ));
            }
          }
        }
      } catch (e) {
        debugPrint("Movies07Prime HTML search error: $e");
      }
    }

    // 3. Fallback via backend admin API proxy if provided
    if (results.isEmpty && adminApi != null) {
      try {
        final apiRes = await adminApi('search_07prime', {
          'query': cleanQuery,
          'domain': baseUrl,
        });
        if (apiRes['status'] == 'success' && apiRes['data']?['items'] is List) {
          final List list = apiRes['data']['items'];
          for (final it in list) {
            if (it is Map) {
              final poster = _cleanUrl((it['poster'] ?? '').toString(), baseUrl);
              if (poster.isNotEmpty && !results.any((r) => r.poster == poster)) {
                results.add(Movies07PrimeItem(
                  id: int.tryParse('${it['id']}') ?? 1000,
                  title: _cleanText((it['title'] ?? cleanQuery).toString()),
                  type: (it['type'] ?? 'movie').toString(),
                  releaseDate: (it['release_date'] ?? '').toString(),
                  poster: poster,
                  pageUrl: (it['url'] ?? '').toString(),
                ));
              }
            }
          }
        }
      } catch (e) {
        debugPrint("Backend 07prime search error: $e");
      }
    }

    // 4. Fallback: Search engine targeted query for 07prime domain posters
    if (results.isEmpty) {
      try {
        final host = Uri.tryParse(baseUrl)?.host ?? 'movies07prime.com';
        final bingUrl =
            'https://www.bing.com/images/search?q=${Uri.encodeQueryComponent("$cleanQuery site:$host")}&form=HDRSC2';
        final res = await http.get(Uri.parse(bingUrl), headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          'Accept-Language': 'en-US,en;q=0.9',
        }).timeout(const Duration(seconds: 8));

        if (res.statusCode == 200) {
          final html = res.body;
          final murls = RegExp(r'murl&quot;:&quot;(https?:\/\/[^&]+?)&quot;')
              .allMatches(html);
          int autoId = 2000;
          for (final m in murls) {
            final u = m.group(1) ?? '';
            if (u.isNotEmpty && !results.any((it) => it.poster == u)) {
              results.add(Movies07PrimeItem(
                id: autoId++,
                title: '$cleanQuery (07Prime)',
                type: 'movie',
                releaseDate: '',
                poster: u,
                pageUrl: '',
              ));
            }
          }
        }
      } catch (_) {}
    }

    return results;
  }
}
