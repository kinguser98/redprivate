import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import 'luluvdo_resolver.dart';
import 'streamtape_service.dart';

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
    ],
    'hdmaal': [
      'https://hdmaal.gg',
    ],
    'uncut': [
      'https://uncutmasti.com',
      'https://uncutmasti.net',
    ],
  };

  /// Returns dynamic domain list for source prioritizing the domain set in App Settings
  static Future<List<String>> getDomainsFor(String source) async {
    final list = <String>[];
    try {
      final prefs = await SharedPreferences.getInstance();
      String? saved;
      if (source == 'uffmaal') {
        saved = prefs.getString('uffmaal_domain');
      } else if (source == 'hdmaal') {
        saved = prefs.getString('hdmaal_domain');
      } else if (source == 'uncut') {
        saved = prefs.getString('uncutmasti_domain');
      }

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
        final url = '$base/?s=${Uri.encodeComponent(query)}';
        final res = await http.get(
          Uri.parse(url),
          headers: {..._headers, 'Referer': '$base/'},
        ).timeout(const Duration(seconds: 10));

        if (res.statusCode != 200) continue;
        final html = res.body;

        final anchorReg = RegExp(
          r'''<a[^>]+href=['"](https?://[^\s'"]+)['"][^>]*>([\s\S]*?)<h2[^>]*class=['"]vtitle['"][^>]*>(.*?)</h2>''',
          caseSensitive: false,
        );

        for (final m in anchorReg.allMatches(html)) {
          final pageUrl = m.group(1)!.trim();
          final rawTitle = m.group(3)!.trim();
          final title = rawTitle
              .replaceAll(RegExp(r'<[^>]*>'), '')
              .replaceAll('&amp;', '&')
              .replaceAll('&#8211;', '–')
              .replaceAll('&#8217;', "'")
              .trim();

          if (title.isEmpty ||
              pageUrl.contains('/category/') ||
              pageUrl.contains('/tag/') ||
              pageUrl.contains('/topic/') ||
              seenUrls.contains(pageUrl)) {
            continue;
          }

          var poster = '';
          final block = m.group(2) ?? '';
          final imgM = RegExp(
            r'''<img[^>]+(?:src|data-src)=['"]([^'"]+)['"]''',
            caseSensitive: false,
          ).firstMatch(block);
          if (imgM != null) {
            poster = imgM.group(1)!.trim();
          } else {
            final bgM = RegExp(
              r'''background-image:\s*url\(['"]?([^'")]+)['"]?\)''',
              caseSensitive: false,
            ).firstMatch(block);
            if (bgM != null) poster = bgM.group(1)!.trim();
          }

          seenUrls.add(pageUrl);
          results.add(UffmaalItem(
            title: title,
            pageUrl: pageUrl,
            poster: poster,
            isEpisode: pageUrl.contains('/episode/'),
            source: 'hdmaal',
          ));
        }

        if (results.isNotEmpty) return results;
      } catch (_) {
        continue;
      }
    }

    // Fallback: PHP Backend API
    try {
      final res = await _callAdminApi('search_hdmaal_catalog', {'query': query});
      if (res['status'] == 'success' && res['data']?['items'] != null) {
        final items = res['data']['items'] as List<dynamic>;
        for (final item in items) {
          final pageUrl = (item['page_url'] ?? '').toString().trim();
          final title = (item['title'] ?? '').toString().trim();
          final poster = (item['poster'] ?? item['raw_poster'] ?? '').toString().trim();
          if (pageUrl.isNotEmpty && title.isNotEmpty && !seenUrls.contains(pageUrl)) {
            seenUrls.add(pageUrl);
            results.add(UffmaalItem(
              title: title,
              pageUrl: pageUrl,
              poster: poster,
              isEpisode: pageUrl.contains('/episode/'),
              source: 'hdmaal',
            ));
          }
        }
      }
    } catch (_) {}

    return results;
  }

  // ── Uncut Search (Backend Scraper API + Direct Fallback) ──
  static Future<List<UffmaalItem>> _searchUncut(String query,
      {String? customBase}) async {
    final results = <UffmaalItem>[];
    final seenUrls = <String>{};

    try {
      final res = await _callAdminApi('search_uncutmasti_catalog', {'query': query});
      if (res['status'] == 'success' && res['data']?['items'] != null) {
        final items = res['data']['items'] as List<dynamic>;
        for (final item in items) {
          final pageUrl = (item['page_url'] ?? '').toString().trim();
          final title = (item['title'] ?? '').toString().trim();
          final poster = (item['poster'] ?? '').toString().trim();
          if (pageUrl.isNotEmpty && title.isNotEmpty && !seenUrls.contains(pageUrl)) {
            seenUrls.add(pageUrl);
            results.add(UffmaalItem(
              title: title,
              pageUrl: pageUrl,
              poster: poster,
              isEpisode: pageUrl.contains('/episode/'),
              source: 'uncut',
            ));
          }
        }
      }
    } catch (_) {}

    if (results.isNotEmpty) return results;

    final dynamicDomains = await getDomainsFor('uncut');
    final domainList = [
      if (customBase != null && customBase.trim().isNotEmpty) customBase.trim(),
      ...dynamicDomains,
    ];

    for (final base in domainList) {
      try {
        final url = '$base/?s=${Uri.encodeComponent(query)}';
        final res = await http.get(
          Uri.parse(url),
          headers: {..._headers, 'Referer': '$base/'},
        ).timeout(const Duration(seconds: 10));

        if (res.statusCode != 200) continue;
        final html = res.body;

        final articleReg = RegExp(
          r'''<article[^>]*>[\s\S]*?<a[^>]+href=['"]([^'"]+)['"][^>]*>[\s\S]*?<img[^>]+(?:src|data-src)=['"]([^'"]+)['"][\s\S]*?<(?:h[1-4]|span)[^>]*>([^<]+)</(?:h[1-4]|span)>''',
          caseSensitive: false,
        );

        for (final m in articleReg.allMatches(html)) {
          _addResult(results, seenUrls, m.group(1), m.group(2), m.group(3), base, 'uncut');
        }

        if (results.isNotEmpty) return results;
      } catch (_) {
        continue;
      }
    }

    return results;
  }

  // ── UffMaal Search (Direct Multi-Domain Fast Query + Series Expansion + PHP Fallback) ──
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
        ).timeout(const Duration(seconds: 10));

        if (res.statusCode != 200) continue;
        final html = res.body;

        // 1. Match WordPress post-card articles
        final articleReg = RegExp(
          r'''<article[^>]*class="[^"]*post-card[^"]*"[^>]*>[\s\S]*?<a[^>]+href=['"]([^'"]+)['"][^>]*>[\s\S]*?<img[^>]+(?:src|data-src)=['"]([^'"]+)['"][\s\S]*?<h2>([^<]+)</h2>''',
          caseSensitive: false,
        );
        for (final m in articleReg.allMatches(html)) {
          _addResult(results, seenUrls, m.group(1), m.group(2), m.group(3), base, 'uffmaal');
        }

        // 2. Generic anchor fallback
        if (results.isEmpty) {
          final anchorReg = RegExp(
            r'''<a[^>]+href=['"]([^'"]+)['"][^>]*>[\s\S]*?<img[^>]+(?:src|data-src)=['"]([^'"]+)['"][\s\S]*?<(?:h[1-4]|b)[^>]*>([^<]+)</(?:h[1-4]|b)>''',
            caseSensitive: false,
          );
          for (final m in anchorReg.allMatches(html)) {
            _addResult(results, seenUrls, m.group(1), m.group(2), m.group(3), base, 'uffmaal');
          }
        }

        // 3. If any matched item is a series container, expand all its individual episodes
        if (results.isNotEmpty) {
          final seriesCards = results.where((r) => !r.pageUrl.contains('/episode/')).toList();
          for (final series in seriesCards) {
            final epList = await _fetchUffmaalSeriesEpisodes(series.pageUrl, base);
            for (final ep in epList) {
              if (!seenUrls.contains(ep.pageUrl)) {
                seenUrls.add(ep.pageUrl);
                results.add(ep);
              }
            }
          }
          return results;
        }
      } catch (_) {
        continue;
      }
    }

    // Fallback: PHP Backend API
    if (results.isEmpty) {
      try {
        final res = await _callAdminApi('search_uffmaal_catalog', {'query': query}, timeout: 12);
        if (res['status'] == 'success' && res['data']?['items'] != null) {
          final items = res['data']['items'] as List<dynamic>;
          for (final item in items) {
            final pageUrl = (item['page_url'] ?? '').toString().trim();
            final title = (item['title'] ?? '').toString().trim();
            final poster = (item['poster'] ?? '').toString().trim();
            if (pageUrl.isNotEmpty && title.isNotEmpty && !seenUrls.contains(pageUrl)) {
              seenUrls.add(pageUrl);
              results.add(UffmaalItem(
                title: title,
                pageUrl: pageUrl,
                poster: poster,
                isEpisode: pageUrl.contains('/episode/'),
                source: 'uffmaal',
              ));
            }
          }
        }
      } catch (_) {}
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
      ).timeout(const Duration(seconds: 8));

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
        r'''<div[^>]*class="[^"]*episode-card[^"]*"[^>]*>\s*<a[^>]+href=['"]([^'"]+)['"][^>]*>[\s\S]*?<img[^>]+(?:src|data-src)=['"]([^'"]+)['"][\s\S]*?<span[^>]*class="episode-number"[^>]*>([^<]+)</span>''',
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

  /// Extract direct stream link & poster from an UffMaal page URL with host resolving (Luluvdo, Streamtape, Playmate)
  static Future<Map<String, dynamic>> fetchUffmaalStreamAndPoster(
      String pageUrl, {String? customBase}) async {
    final cleanUrl = pageUrl.trim();
    if (cleanUrl.isEmpty) return {};

    // 1. Direct fetch if cleanUrl is already an absolute HTTP/HTTPS URL
    if (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://')) {
      final uri = Uri.tryParse(cleanUrl);
      final origin = uri != null ? uri.origin : 'https://uffmaal.com';
      try {
        final res = await http.get(
          Uri.parse(cleanUrl),
          headers: {..._headers, 'Referer': '$origin/'},
        ).timeout(const Duration(seconds: 12));

        if (res.statusCode == 200) {
          final data = await _extractUffmaalDataFromHtml(res.body, cleanUrl);
          if ((data['stream_url'] ?? '').toString().isNotEmpty ||
              (data['episodes'] as List<dynamic>? ?? []).isNotEmpty) {
            return data;
          }
        }
      } catch (_) {}
    }

    final dynamicUffmaalDomains = await getDomainsFor('uffmaal');
    final domainList = [
      if (customBase != null && customBase.trim().isNotEmpty) customBase.trim(),
      ...dynamicUffmaalDomains,
    ];

    final uri = Uri.tryParse(cleanUrl);
    final targetPath = uri != null ? (uri.path + (uri.hasQuery ? '?${uri.query}' : '')) : cleanUrl;

    for (final base in domainList) {
      try {
        final fetchUrl = cleanUrl.startsWith('http')
            ? (base != uri?.origin && uri != null ? '$base$targetPath' : cleanUrl)
            : '$base/$cleanUrl';

        final res = await http.get(
          Uri.parse(fetchUrl),
          headers: {..._headers, 'Referer': '$base/'},
        ).timeout(const Duration(seconds: 10));

        if (res.statusCode != 200) continue;
        final data = await _extractUffmaalDataFromHtml(res.body, fetchUrl);
        if ((data['stream_url'] ?? '').toString().isNotEmpty ||
            (data['episodes'] as List<dynamic>? ?? []).isNotEmpty) {
          return data;
        }
      } catch (_) {
        continue;
      }
    }

    // Fallback: Backend PHP API
    try {
      final sRes = await _callAdminApi('extract_uffmaal_details', {'page_url': cleanUrl}, timeout: 12);
      if (sRes['status'] == 'success' && sRes['data'] != null) {
        return sRes['data'];
      }
    } catch (_) {}

    return {};
  }

  static Future<Map<String, dynamic>> _extractUffmaalDataFromHtml(String html, String fetchUrl) async {
    String streamUrl = '';
    String poster = '';
    String title = '';
    final episodes = <Map<String, dynamic>>[];

    // Title
    final tMatch = RegExp(
      r'<h1[^>]*class="[^"]*entry-title[^"]*"[^>]*>([^<]+)</h1>|<h1[^>]*>([^<]+)</h1>',
      caseSensitive: false,
    ).firstMatch(html);
    if (tMatch != null) {
      title = (tMatch.group(1) ?? tMatch.group(2) ?? '').trim();
    }

    // Poster
    final vPoster = RegExp(r'''<video[^>]+poster=['"]([^'"]+)['"]''', caseSensitive: false).firstMatch(html);
    if (vPoster != null) {
      poster = vPoster.group(1)!.trim();
    }
    if (poster.isEmpty) {
      final og = RegExp(r'''<meta property="og:image" content=['"]([^'"]+)['"]''', caseSensitive: false).firstMatch(html);
      if (og != null) poster = og.group(1)!.trim();
    }

    // Episode cards
    final epMatches = RegExp(
      r'''<div[^>]*class="[^"]*episode-card[^"]*"[^>]*>\s*<a[^>]+href=['"]([^'"]+)['"][^>]*>[\s\S]*?<img[^>]+(?:src|data-src)=['"]([^'"]+)['"][\s\S]*?<span[^>]*class="episode-number"[^>]*>([^<]+)</span>''',
      caseSensitive: false,
    ).allMatches(html);
    for (final em in epMatches) {
      final epUrl = em.group(1)!.trim();
      final epPoster = em.group(2)!.trim();
      final epNum = em.group(3)!.trim();
      episodes.add({
        'episode_url': epUrl,
        'poster': epPoster,
        'episode_number': epNum,
        'title': title.isNotEmpty ? '$title Episode $epNum' : 'Episode $epNum',
      });
    }

    // 1. Direct <source src="...">
    final srcMatch = RegExp(r'''<source[^>]+src=['"]([^'"]+)['"]''', caseSensitive: false).firstMatch(html);
    if (srcMatch != null) {
      streamUrl = srcMatch.group(1)!.replaceAll('&#038;', '&').replaceAll('&amp;', '&').trim();
    }

    // 2. Direct MP4/M3U8 download links
    if (streamUrl.isEmpty) {
      final dlMatch = RegExp(r'''<a[^>]+href=['"]([^'"]+\.(?:mp4|m3u8|mkv)[^'"]*)['"]''', caseSensitive: false).firstMatch(html);
      if (dlMatch != null) {
        streamUrl = dlMatch.group(1)!.replaceAll('&#038;', '&').replaceAll('&amp;', '&').trim();
      }
    }

    // 3. Direct <video src="...">
    if (streamUrl.isEmpty) {
      final videoTag = RegExp(r'''<video[^>]+src=['"]([^'"]+)['"]''', caseSensitive: false).firstMatch(html);
      if (videoTag != null) {
        streamUrl = videoTag.group(1)!.replaceAll('&#038;', '&').replaceAll('&amp;', '&').trim();
      }
    }

    // 4. Embedded Luluvdo / LuluStream / Playmate / Streamtape
    if (streamUrl.isEmpty) {
      final hostMatch = RegExp(r'''(?:src|href)=['"]([^'"]*(?:luluvdo|lulustream|luluvids|streamtape|playmate|uplinks24|toolkitspro)[^'"]*)['"]''', caseSensitive: false).firstMatch(html);
      if (hostMatch != null) {
        final hostUrl = hostMatch.group(1)!.replaceAll('&#038;', '&').replaceAll('&amp;', '&').trim();
        if (hostUrl.contains('luluvdo') || hostUrl.contains('lulustream') || hostUrl.contains('luluvids') || hostUrl.contains('uplinks24') || hostUrl.contains('toolkitspro') || hostUrl.contains('playmate')) {
          final resolved = await LuluvdoResolver.resolveOnDevice(hostUrl);
          if (resolved != null && resolved.isNotEmpty) {
            streamUrl = resolved;
          }
        } else if (hostUrl.contains('streamtape')) {
          final resolved = await StreamtapeService.getDirectStreamUrl(hostUrl);
          if (resolved != null && resolved.isNotEmpty) {
            streamUrl = resolved;
          }
        }
      }
    }

    // 5. Iframe fallback
    if (streamUrl.isEmpty) {
      final iframeTag = RegExp(r'''<iframe[^>]+src=['"]([^'"]+)['"]''', caseSensitive: false).firstMatch(html);
      if (iframeTag != null) {
        final ifSrc = iframeTag.group(1)!.replaceAll('&#038;', '&').replaceAll('&amp;', '&').trim();
        if (ifSrc.contains('luluvdo') || ifSrc.contains('lulustream') || ifSrc.contains('playmate')) {
          final resolved = await LuluvdoResolver.resolveOnDevice(ifSrc);
          if (resolved != null && resolved.isNotEmpty) streamUrl = resolved;
        } else if (ifSrc.contains('streamtape')) {
          final resolved = await StreamtapeService.getDirectStreamUrl(ifSrc);
          if (resolved != null && resolved.isNotEmpty) streamUrl = resolved;
        } else {
          streamUrl = ifSrc;
        }
      }
    }

    return {
      'title': title,
      'poster': poster,
      'stream_url': streamUrl,
      'episodes': episodes,
      'page_url': fetchUrl,
    };
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
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final html = res.body;

        // 1. Check video tag poster
        final vPoster = RegExp(r'''<video[^>]+poster=['"]([^'"]+)['"]''', caseSensitive: false).firstMatch(html);
        if (vPoster != null) {
          final u = vPoster.group(1)!.trim();
          if (u.isNotEmpty && !seen.contains(u)) {
            seen.add(u);
            results.add(u);
          }
        }

        // 2. Check og:image meta tag
        final ogMatch = RegExp(r'''<meta property="og:image" content=['"]([^'"]+)['"]''', caseSensitive: false).firstMatch(html);
        if (ogMatch != null) {
          final u = ogMatch.group(1)!.trim();
          if (u.isNotEmpty && !seen.contains(u)) {
            seen.add(u);
            results.add(u);
          }
        }

        // 3. Extract all content screenshot images
        final imgReg = RegExp(
          r'''<img[^>]+(?:src|data-src|data-lazy-src)=['"](https?://[^'"]+\.(?:jpg|jpeg|png|webp)[^'"]*)['"]''',
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

    // Fallback: If results are empty and it's uncut, uffmaal, or hdmaal, check backend extractor
    if (results.isEmpty) {
      try {
        if (cleanUrl.contains('hdmaal')) {
          final res = await _callAdminApi('extract_hdmaal_details', {'page_url': cleanUrl});
          final p = (res['data']?['poster'] ?? res['data']?['raw_poster'] ?? '').toString().trim();
          if (p.isNotEmpty) results.add(p);
        } else if (cleanUrl.contains('uffmaal')) {
          final res = await _callAdminApi('extract_uffmaal_details', {'page_url': cleanUrl});
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
