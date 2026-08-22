import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

/// A single search result item from UffMaal, HDMaal, or Uncut-based sites.
class UffmaalItem {
  final String title;
  final String pageUrl;
  final String poster;
  final bool isEpisode;
  final String source; // 'uffmaal' | 'hdmaal' | 'uncut'

  UffmaalItem({
    required this.title,
    required this.pageUrl,
    required this.poster,
    this.isEpisode = false,
    required this.source,
  });
}

/// Scraper for UffMaal / HDMaal / Uncut sites.
/// Matches the exact logic and formats used by the Link Extractor and Batch Importer.
class UffmaalScraper {
  static const Map<String, List<String>> _domains = {
    'uffmaal': [
      'https://uffmaal.com',
      'https://uffmaal.skin',
      'https://uffmaal.bond',
    ],
    'hdmaal': [
      'https://hdmaal.gg',
      'https://hdmaal.click',
      'https://hdmaal.co',
    ],
    'uncut': [
      'https://uncutmasti.net',
      'https://uncutmasti.com',
      'https://uncutmasti.in',
    ],
  };

  /// Returns dynamic domain list for source prioritizing the domain set in App Settings
  static Future<List<String>> getDomainsFor(String source) async {
    final list = <String>[];
    try {
      final prefs = await SharedPreferences.getInstance();
      String? saved;
      if (source == 'uffmaal') saved = prefs.getString('uffmaal_domain');
      else if (source == 'hdmaal') saved = prefs.getString('hdmaal_domain');
      else if (source == 'uncut') saved = prefs.getString('uncutmasti_domain');

      if (saved != null && saved.trim().isNotEmpty && saved.trim().startsWith('http')) {
        list.add(saved.trim().endsWith('/') ? saved.trim().substring(0, saved.trim().length - 1) : saved.trim());
      }
    } catch (_) {}

    final defaults = _domains[source] ?? [];
    for (final d in defaults) {
      if (!list.contains(d)) list.add(d);
    }
    return list;
  }

  static final Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
  };

  /// Helper to call backend PHP API (same as Link Extractor)
  static Future<Map<String, dynamic>> _callAdminApi(
      String action, Map<String, dynamic> body,
      {int timeout = 25}) async {
    try {
      final res = await http.post(
        Uri.parse(ApiConfig.adminUrl),
        body: json.encode({...body, 'action': action}),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: timeout));

      final raw = res.body.trim();
      if (raw.startsWith('{') && raw.endsWith('}')) {
        return json.decode(raw);
      }
      return {'status': 'error', 'message': raw};
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  /// Search across [source] = 'uffmaal' | 'hdmaal' | 'uncut'.
  /// [customBase] lets callers override the primary domain.
  /// Returns a list of [UffmaalItem] with title, poster, and page URL.
  static Future<List<UffmaalItem>> search(String query, String source,
      {String? customBase}) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    if (source == 'hdmaal') {
      return _searchHdmaal(q, customBase: customBase);
    } else if (source == 'uncut') {
      return _searchUncut(q, customBase: customBase);
    } else {
      return _searchUffmaal(q, customBase: customBase);
    }
  }

  // ── HDMaal Search (Direct Regex + PHP Backend Fallback) ──
  static Future<List<UffmaalItem>> _searchHdmaal(String query,
      {String? customBase}) async {
    final results = <UffmaalItem>[];
    final seenUrls = <String>{};

    final dynamicDomains = await getDomainsFor('hdmaal');
    final domainList = [
      if (customBase != null && customBase.trim().isNotEmpty) customBase.trim(),
      ...dynamicDomains,
    ];

    for (final base in domainList) {
      try {
        final uri = Uri.parse("$base/?s=${Uri.encodeComponent(query)}");
        final res = await http.get(uri, headers: {
          ..._headers,
          'Referer': '$base/',
        }).timeout(const Duration(seconds: 12));

        if (res.statusCode != 200) continue;
        final html = res.body;

        // HDMaal video card format: <a class="video" href="..." title="..." style="background-image: url(...)">
        final reg = RegExp(
          r'<a[^>]+class="[^"]*video[^"]*"[^>]*href="([^"]+)"[^>]*title="([^"]*)"[^>]*style="([^"]*)"|<a[^>]+class="[^"]*video[^"]*"[^>]*style="([^"]*)"[^>]*title="([^"]*)"[^>]*href="([^"]+)"',
          caseSensitive: false,
        );

        for (final match in reg.allMatches(html)) {
          final url = (match.group(1) ?? match.group(6) ?? '').trim();
          final title = (match.group(2) ?? match.group(5) ?? '')
              .replaceAll('&amp;', '&')
              .replaceAll('&#8211;', '–')
              .replaceAll('&#8217;', "'")
              .trim();
          final style = match.group(3) ?? match.group(4) ?? '';
          var poster = '';
          final bgMatch = RegExp(r'''background-image:\s*url\(['"]?([^'")]+)['"]?\)''')
              .firstMatch(style);
          if (bgMatch != null) {
            poster = bgMatch.group(1) ?? '';
          }

          if (url.isNotEmpty && title.isNotEmpty && !seenUrls.contains(url)) {
            seenUrls.add(url);
            results.add(UffmaalItem(
              title: title,
              pageUrl: url,
              poster: poster,
              isEpisode: true,
              source: 'hdmaal',
            ));
          }
        }

        if (results.isNotEmpty) return results;
      } catch (_) {
        continue;
      }
    }

    // Backend PHP fallback (matches Link Extractor)
    try {
      final res = await _callAdminApi('search_hdmaal_catalog', {'query': query});
      if (res['status'] == 'success' && res['data']?['items'] != null) {
        final items = res['data']['items'] as List<dynamic>;
        for (final item in items) {
          final url = (item['page_url'] ?? item['url'] ?? '').toString().trim();
          final title = (item['title'] ?? '').toString().trim();
          final poster = (item['poster'] ?? '').toString().trim();
          if (url.isNotEmpty && title.isNotEmpty && !seenUrls.contains(url)) {
            seenUrls.add(url);
            results.add(UffmaalItem(
              title: title,
              pageUrl: url,
              poster: poster,
              isEpisode: true,
              source: 'hdmaal',
            ));
          }
        }
      }
    } catch (_) {}

    return results;
  }

  // ── Uncut Search (PHP Backend + Direct Fallback) ──
  static Future<List<UffmaalItem>> _searchUncut(String query,
      {String? customBase}) async {
    final results = <UffmaalItem>[];
    final seenUrls = <String>{};

    // 1. Backend PHP API (Primary, exact same endpoint used in Link Extractor)
    try {
      final res = await _callAdminApi('search_uncutmasti_catalog', {'query': query});
      if (res['status'] == 'success' && res['data']?['items'] != null) {
        final items = res['data']['items'] as List<dynamic>;
        for (final item in items) {
          final url = (item['page_url'] ?? item['url'] ?? '').toString().trim();
          final title = (item['title'] ?? '').toString().trim();
          final poster = (item['poster'] ?? '').toString().trim();
          if (url.isNotEmpty && title.isNotEmpty && !seenUrls.contains(url)) {
            seenUrls.add(url);
            results.add(UffmaalItem(
              title: title,
              pageUrl: url,
              poster: poster,
              isEpisode: true,
              source: 'uncut',
            ));
          }
        }
      }
    } catch (_) {}

    if (results.isNotEmpty) return results;

    // 2. Direct client scraping fallback across mirrors
    final dynamicUncutDomains = await getDomainsFor('uncut');
    final domainList = [
      if (customBase != null && customBase.trim().isNotEmpty) customBase.trim(),
      ...dynamicUncutDomains,
    ];

    for (final base in domainList) {
      try {
        final url = '$base/?s=${Uri.encodeComponent(query)}';
        final res = await http.get(
          Uri.parse(url),
          headers: {..._headers, 'Referer': '$base/'},
        ).timeout(const Duration(seconds: 12));

        if (res.statusCode != 200) continue;
        final html = res.body;

        // Post-card articles or standard WordPress search cards
        final articleReg = RegExp(
          r'<article[^>]*class="[^"]*post-card[^"]*"[^>]*>[\s\S]*?<a[^>]+href=["\x27]([^"\x27]+)["\x27][^>]*>[\s\S]*?<img[^>]+(?:src|data-src)=["\x27]([^"\x27]+)["\x27][\s\S]*?<h2>([^<]+)</h2>',
          caseSensitive: false,
        );
        for (final m in articleReg.allMatches(html)) {
          _addResult(results, seenUrls, m.group(1), m.group(2), m.group(3), base, 'uncut');
        }

        // Standard WordPress search result layout
        final stdReg = RegExp(
          r'<h2[^>]*class="[^"]*entry-title[^"]*"[^>]*>\s*<a[^>]+href=["\x27]([^"\x27]+)["\x27][^>]*>([^<]+)</a>[\s\S]*?<img[^>]+(?:src|data-src)=["\x27]([^"\x27]+)["\x27]',
          caseSensitive: false,
        );
        for (final m in stdReg.allMatches(html)) {
          _addResult(results, seenUrls, m.group(1), m.group(3), m.group(2), base, 'uncut');
        }

        if (results.isNotEmpty) return results;

        // Generic anchor with img & header
        final anchorReg = RegExp(
          r'<a[^>]+href=["\x27]([^"\x27]+)["\x27][^>]*>[\s\S]*?<img[^>]+(?:src|data-src)=["\x27]([^"\x27]+)["\x27][\s\S]*?<(?:h[1-4]|b)[^>]*>([^<]+)</(?:h[1-4]|b)>',
          caseSensitive: false,
        );
        for (final m in anchorReg.allMatches(html)) {
          _addResult(results, seenUrls, m.group(1), m.group(2), m.group(3), base, 'uncut');
        }

        if (results.isNotEmpty) return results;
      } catch (_) {
        continue;
      }
    }

    return results;
  }

  // ── UffMaal Search (Direct Post-Cards + Multi-Episode Series Expansion) ──
  static Future<List<UffmaalItem>> _searchUffmaal(String query,
      {String? customBase}) async {
    final results = <UffmaalItem>[];
    final seenUrls = <String>{};

    final dynamicUffmaalDomains = await getDomainsFor('uffmaal');
    final domainList = [
      if (customBase != null && customBase.trim().isNotEmpty) customBase.trim(),
      ...dynamicUffmaalDomains,
    ];

    for (final base in domainList) {
      try {
        final url = '$base/?s=${Uri.encodeComponent(query)}';
        final res = await http.get(
          Uri.parse(url),
          headers: {..._headers, 'Referer': '$base/'},
        ).timeout(const Duration(seconds: 12));

        if (res.statusCode != 200) continue;
        final html = res.body;

        // Match WordPress post-card articles
        final articleReg = RegExp(
          r'<article[^>]*class="[^"]*post-card[^"]*"[^>]*>[\s\S]*?<a[^>]+href=["\x27]([^"\x27]+)["\x27][^>]*>[\s\S]*?<img[^>]+(?:src|data-src)=["\x27]([^"\x27]+)["\x27][\s\S]*?<h2>([^<]+)</h2>',
          caseSensitive: false,
        );
        for (final m in articleReg.allMatches(html)) {
          _addResult(results, seenUrls, m.group(1), m.group(2), m.group(3), base, 'uffmaal');
        }

        // If results contain a series page, also extract all individual episode cards
        if (results.isNotEmpty) {
          final firstSeries = results.firstWhere(
            (r) => !r.pageUrl.contains('/episode/'),
            orElse: () => results.first,
          );
          if (firstSeries.pageUrl.isNotEmpty) {
            final epList = await _fetchUffmaalSeriesEpisodes(firstSeries.pageUrl, base);
            if (epList.isNotEmpty) {
              // Prepend all individual episodes so user sees every single episode poster!
              for (final ep in epList) {
                if (!seenUrls.contains(ep.pageUrl)) {
                  seenUrls.add(ep.pageUrl);
                  results.insert(0, ep);
                }
              }
            }
          }
          return results;
        }

        // Generic fallback
        final anchorReg = RegExp(
          r'<a[^>]+href=["\x27]([^"\x27]+)["\x27][^>]*>[\s\S]*?<img[^>]+(?:src|data-src)=["\x27]([^"\x27]+)["\x27][\s\S]*?<(?:h[1-4]|b)[^>]*>([^<]+)</(?:h[1-4]|b)>',
          caseSensitive: false,
        );
        for (final m in anchorReg.allMatches(html)) {
          _addResult(results, seenUrls, m.group(1), m.group(2), m.group(3), base, 'uffmaal');
        }

        if (results.isNotEmpty) return results;
      } catch (_) {
        continue;
      }
    }

    return results;
  }

  /// Helper to extract all episode cards from an UffMaal series page
  static Future<List<UffmaalItem>> _fetchUffmaalSeriesEpisodes(
      String seriesUrl, String base) async {
    final episodes = <UffmaalItem>[];
    try {
      final res = await http.get(
        Uri.parse(seriesUrl),
        headers: {..._headers, 'Referer': '$base/'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return [];
      final html = res.body;

      var mainTitle = '';
      final tMatch = RegExp(
        r'<h1[^>]*class="[^"]*entry-title[^"]*"[^>]*>([^<]+)</h1>|<h1[^>]*>([^<]+)</h1>',
        caseSensitive: false,
      ).firstMatch(html);
      if (tMatch != null) {
        mainTitle = (tMatch.group(1) ?? tMatch.group(2) ?? '').trim();
      }

      final epMatches = RegExp(
        r'<div[^>]*class="[^"]*episode-card[^"]*"[^>]*>\s*<a[^>]+href=["\x27]([^"\x27]+)["\x27][^>]*>[\s\S]*?<img[^>]+(?:src|data-src)=["\x27]([^"\x27]+)["\x27][\s\S]*?<span[^>]*class="episode-number"[^>]*>([^<]+)</span>',
        caseSensitive: false,
      ).allMatches(html);

      for (final em in epMatches) {
        final epUrl = em.group(1)!.trim();
        final epPoster = em.group(2)!.trim();
        final epNum = em.group(3)!.trim();
        final epTitle = mainTitle.isNotEmpty
            ? '$mainTitle Episode $epNum'
            : 'Episode $epNum';
        episodes.add(UffmaalItem(
          title: epTitle,
          pageUrl: epUrl,
          poster: epPoster,
          isEpisode: true,
          source: 'uffmaal',
        ));
      }
    } catch (_) {}
    return episodes;
  }

  static void _addResult(
    List<UffmaalItem> results,
    Set<String> seenUrls,
    String? rawUrl,
    String? rawPoster,
    String? rawTitle,
    String base,
    String source,
  ) {
    if (rawUrl == null || rawTitle == null) return;
    var url = rawUrl.trim();
    var title = rawTitle
        .replaceAll('&amp;', '&')
        .replaceAll('&#8211;', '–')
        .replaceAll('&#8217;', "'")
        .trim();
    var poster = (rawPoster ?? '').trim();

    if (url.isEmpty || title.length < 3) return;
    if (!url.startsWith('http')) {
      url = '$base/${url.startsWith('/') ? url.substring(1) : url}';
    }
    if (poster.isNotEmpty && !poster.startsWith('http')) {
      poster = '$base/${poster.startsWith('/') ? poster.substring(1) : poster}';
    }
    // Skip navigation/pagination links
    if (url.contains('/page/') ||
        url.contains('/category/') ||
        url.contains('/tag/') ||
        url == '$base/' ||
        url == base) return;

    if (seenUrls.contains(url)) return;
    seenUrls.add(url);
    results.add(UffmaalItem(
      title: title,
      pageUrl: url,
      poster: poster,
      isEpisode: url.contains('/episode/'),
      source: source,
    ));
  }

  /// Fetch all screenshot/image URLs from a detail page.
  /// Works across HDMaal, Uncut, and UffMaal detail pages.
  static Future<List<String>> fetchPageImages(String pageUrl) async {
    final cleanUrl = pageUrl.trim();
    if (cleanUrl.isEmpty) return [];

    final results = <String>[];
    final seen = <String>{};

    try {
      final base = Uri.parse(cleanUrl).origin;
      final res = await http.get(
        Uri.parse(cleanUrl),
        headers: {..._headers, 'Referer': '$base/'},
      ).timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        final html = res.body;

        // 1. Check video tag poster
        final vPoster = RegExp(r'<video[^>]+poster=["\x27]([^"\x27]+)["\x27]', caseSensitive: false).firstMatch(html);
        if (vPoster != null) {
          final u = vPoster.group(1)!.trim();
          if (u.isNotEmpty && !seen.contains(u)) {
            seen.add(u);
            results.add(u);
          }
        }

        // 2. Check og:image meta tag
        final ogMatch = RegExp(r'<meta property="og:image" content=["\x27]([^"\x27]+)["\x27]', caseSensitive: false).firstMatch(html);
        if (ogMatch != null) {
          final u = ogMatch.group(1)!.trim();
          if (u.isNotEmpty && !seen.contains(u)) {
            seen.add(u);
            results.add(u);
          }
        }

        // 3. Extract all content screenshot images
        final imgReg = RegExp(
          r'<img[^>]+(?:src|data-src|data-lazy-src)=["\x27](https?://[^"\x27]+\.(?:jpg|jpeg|png|webp)[^"\x27]*)["\x27]',
          caseSensitive: false,
        );
        for (final m in imgReg.allMatches(html)) {
          final u = m.group(1)!.replaceAll('&amp;', '&').trim();
          final lower = u.toLowerCase();
          if (lower.contains('logo') ||
              lower.contains('icon') ||
              lower.contains('banner') ||
              lower.contains('avatar') ||
              lower.contains('button') ||
              lower.contains('arrow') ||
              lower.contains('telegram') ||
              lower.contains('ad')) continue;
          if (!seen.contains(u)) {
            seen.add(u);
            results.add(u);
          }
        }
      }
    } catch (_) {}

    // Fallback: If results are empty and it's uncut or hdmaal, check backend extractor
    if (results.isEmpty) {
      try {
        if (cleanUrl.contains('hdmaal')) {
          final res = await _callAdminApi('extract_hdmaal_details', {'page_url': cleanUrl});
          final p = (res['data']?['poster'] ?? res['data']?['raw_poster'] ?? '').toString().trim();
          if (p.isNotEmpty) results.add(p);
        } else if (cleanUrl.contains('uncut')) {
          final res = await _callAdminApi('extract_uncutmasti_details', {'page_url': cleanUrl});
          final p = (res['data']?['poster'] ?? res['data']?['raw_poster'] ?? '').toString().trim();
          if (p.isNotEmpty) results.add(p);
        }
      } catch (_) {}
    }

    return results;
  }
}
