import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// A single search result item from any Maal Network site.
class MaalNetworkItem {
  final String title;
  final String pageUrl;
  final String poster;
  final String siteName;
  final String siteDomain;
  final bool isEpisode;

  MaalNetworkItem({
    required this.title,
    required this.pageUrl,
    required this.poster,
    required this.siteName,
    required this.siteDomain,
    this.isEpisode = false,
  });
}

/// Stream details extracted from a Maal Network episode page.
class MaalNetworkEpisodeDetails {
  final String? streamUrl;
  final String? poster;
  final String? title;
  final List<String> images;
  final String? referer;

  MaalNetworkEpisodeDetails({
    this.streamUrl,
    this.poster,
    this.title,
    this.images = const [],
    this.referer,
  });
}

/// ══════════════════════════════════════════════════════════════
///   All 56 known Maal Network sites (from xmaal.net/sites.json)
///   Grouped by category for UI display.
/// ══════════════════════════════════════════════════════════════
class MaalNetworkScraper {
  // ── Site Registry (Name → Domain, grouped by category) ──────
  static const List<Map<String, String>> allSites = [
    // ── Premium / Most Content ──────────────────────────────────
    {'name': 'UffMaal',      'domain': 'uffmaal.com',        'group': 'Premium'},
    {'name': 'AagMaal',      'domain': 'aagmaal.hot',        'group': 'Premium'},
    {'name': 'BMaal',        'domain': 'bmaal.net',          'group': 'Premium'},
    {'name': 'NewMaal',      'domain': 'newmaal.com',        'group': 'Premium'},
    {'name': 'WOWMaal',      'domain': 'wowmaal.net',        'group': 'Premium'},
    {'name': 'HMaal',        'domain': 'hmaal.co',           'group': 'Premium'},
    {'name': 'OTTDude',      'domain': 'ottdude.com',        'group': 'Premium'},
    {'name': 'GoldMaal',     'domain': 'goldmaal.com.co',    'group': 'Premium'},
    {'name': 'OTTMela',      'domain': 'ottmela.co',         'group': 'Premium'},
    {'name': 'MXSeries',     'domain': 'mxseries.to',        'group': 'Premium'},
    {'name': 'HotOTT',       'domain': 'hotott.net',         'group': 'Premium'},
    // ── Hindi Web Series ─────────────────────────────────────────
    {'name': 'SeriesWala',   'domain': 'serieswala.com',     'group': 'Hindi Series'},
    {'name': 'WebSeriess',   'domain': 'webseriess.net',     'group': 'Hindi Series'},
    {'name': 'WEBxSERIES',   'domain': 'webxseries.hot',     'group': 'Hindi Series'},
    {'name': 'MazaTV',       'domain': 'mazatv.com',         'group': 'Hindi Series'},
    {'name': 'ZMasti',       'domain': 'zmasti.net',         'group': 'Hindi Series'},
    {'name': 'ZMaal',        'domain': 'zmaal.net',          'group': 'Hindi Series'},
    {'name': 'HitMaal',      'domain': 'hitmaal.tv',         'group': 'Hindi Series'},
    {'name': 'PlayMaal',     'domain': 'playmaal.co',        'group': 'Hindi Series'},
    {'name': 'VMaal',        'domain': 'vmaal.co',           'group': 'Hindi Series'},
    {'name': 'JIOMaal',      'domain': 'jiomaal.cc',         'group': 'Hindi Series'},
    {'name': 'YesMaal',      'domain': 'yesmaal.cc',         'group': 'Hindi Series'},
    {'name': 'LoveMaal',     'domain': 'lovemaal.tv',        'group': 'Hindi Series'},
    {'name': 'YMaal',        'domain': 'ymaal.co',           'group': 'Hindi Series'},
    {'name': 'HotMaal',      'domain': 'hotmaal.hot',        'group': 'Hindi Series'},
    {'name': 'OTTMaal',      'domain': 'ottmaal.app',        'group': 'Hindi Series'},
    {'name': 'HotUllu',      'domain': 'hotullu.tv',         'group': 'Hindi Series'},
    // ── Streaming / CDN ─────────────────────────────────────────
    {'name': 'MaalVDO',      'domain': 'maalvdo.com',        'group': 'Streaming'},
    {'name': 'HDMaal',       'domain': 'hdmaal.com.co',      'group': 'Streaming'},
    {'name': 'OPMaal',       'domain': 'opmaal.net',         'group': 'Streaming'},
    {'name': 'DMaal',        'domain': 'dmaal.net',          'group': 'Streaming'},
    {'name': 'MaalTV',       'domain': 'maaltv.hot',         'group': 'Streaming'},
    {'name': 'BotMaal',      'domain': 'botmaal.hot',        'group': 'Streaming'},
    {'name': 'RedMaal',      'domain': 'redmaal.com.co',     'group': 'Streaming'},
    // ── Uncut / Adult ────────────────────────────────────────────
    {'name': 'UncutRaza',    'domain': 'uncutraza.net',      'group': 'Uncut'},
    {'name': 'UncutMaza',    'domain': 'uncutmaza.com.co',   'group': 'Uncut'},
    {'name': 'XKahani',      'domain': 'xkahani.net',        'group': 'Uncut'},
    {'name': 'XMaza',        'domain': 'xmazaa.io',          'group': 'Uncut'},
    {'name': 'XMasti',       'domain': 'xmaasti.net',        'group': 'Uncut'},
    {'name': 'XReels',       'domain': 'xreels.co',          'group': 'Uncut'},
    {'name': 'HotMaza',      'domain': 'hotmaza.net',        'group': 'Uncut'},
    {'name': 'MastiWala',    'domain': 'mastiwala.com',      'group': 'Uncut'},
    {'name': 'StoryWala',    'domain': 'storywala.net',      'group': 'Uncut'},
    {'name': 'Fapstory',     'domain': 'fapstory.co',        'group': 'Uncut'},
    {'name': 'Wataa',        'domain': 'wataa.io',           'group': 'Uncut'},
    {'name': 'BadFans',      'domain': 'badfans.net',        'group': 'Uncut'},
    {'name': 'FSIVideo',     'domain': 'fsivideo.net',       'group': 'Uncut'},
    // ── Hentai / International ──────────────────────────────────
    {'name': 'OGHentai',     'domain': 'oghentai.com',       'group': 'International'},
    {'name': 'C95',          'domain': 'c95.to',             'group': 'International'},
    {'name': 'OGPorn',       'domain': 'ogporn.com',         'group': 'International'},
    {'name': 'MXPorn',       'domain': 'mxporn.io',          'group': 'International'},
    {'name': 'ThotHub',      'domain': 'thothub.com.co',     'group': 'International'},
    {'name': 'Antarvasna',   'domain': 'antarvasna.co',      'group': 'International'},
    {'name': 'OnlyHindiSex', 'domain': 'onlyhindisex.com',  'group': 'International'},
    {'name': 'Bharti Jha',   'domain': 'bhartijha.co',      'group': 'International'},
    {'name': 'BF Videos',    'domain': 'bfvideo.co',         'group': 'International'},
  ];

  // Common browser headers for bypassing hotlink protection
  static const Map<String, String> _commonHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
  };

  // ──────────────────────────────────────────────────────────────
  //  GROUP HELPERS
  // ──────────────────────────────────────────────────────────────

  /// All unique group names in order
  static List<String> get groups {
    final seen = <String>{};
    return allSites
        .map((s) => s['group']!)
        .where((g) => seen.add(g))
        .toList();
  }

  /// Check if a given URL matches any registered Maal Network domain
  static bool matchesAny(String url) {
    final lower = url.toLowerCase();
    return allSites.any((s) => lower.contains(s['domain']!.toLowerCase()));
  }

  // ──────────────────────────────────────────────────────────────
  //  SEARCH (via server-side PHP, or client-side fallback)
  // ──────────────────────────────────────────────────────────────

  /// Search across one or multiple Maal Network sites.
  /// [siteDomains]: list of domains to search. Empty = search all premium sites.
  static Future<List<MaalNetworkItem>> search(
    String query, {
    List<String>? siteDomains,
    int maxSites = 5,
  }) async {
    final domains = (siteDomains == null || siteDomains.isEmpty)
        ? allSites
            .where((s) => s['group'] == 'Premium')
            .map((s) => s['domain']!)
            .take(maxSites)
            .toList()
        : siteDomains;

    final results = <MaalNetworkItem>[];
    // Try server-side first for speed
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/admin_api.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'search_maal_network',
          'query': query,
          'domains': domains,
        }),
      ).timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['success'] == true && data['items'] is List) {
          for (final item in data['items']) {
            final siteInfo = _infoForDomain(item['site_domain'] ?? '');
            results.add(MaalNetworkItem(
              title: item['title'] ?? '',
              pageUrl: item['page_url'] ?? '',
              poster: item['poster'] ?? '',
              siteName: siteInfo?['name'] ?? item['site_name'] ?? '',
              siteDomain: item['site_domain'] ?? '',
              isEpisode: item['is_episode'] == true,
            ));
          }
          return results;
        }
      }
    } catch (e) {
      debugPrint('MaalNetwork server search failed, falling back to client: $e');
    }

    // Client-side fallback: search each domain individually
    for (final domain in domains) {
      try {
        final siteResults = await _searchSite(query, domain);
        results.addAll(siteResults);
      } catch (_) {}
    }
    return results;
  }

  static String _unescapeHtml(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&#8217;', "'")
        .replaceAll('&#8216;', "'")
        .replaceAll('&#8220;', '"')
        .replaceAll('&#8221;', '"')
        .replaceAll('&#8211;', '-')
        .replaceAll('&#8212;', '—')
        .replaceAll('&nbsp;', ' ');
  }

  /// Client-side scrape search on a single site
  static Future<List<MaalNetworkItem>> _searchSite(
      String query, String domain) async {
    final siteInfo = _infoForDomain(domain) ?? {'name': domain, 'domain': domain};
    final baseUrl = 'https://$domain';
    final searchUrl = '$baseUrl/?s=${Uri.encodeComponent(query)}';

    try {
      final res = await http.get(
        Uri.parse(searchUrl),
        headers: {
          ..._commonHeaders,
          'Referer': baseUrl,
        },
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode != 200) return [];

      final body = res.body;
      final items = <MaalNetworkItem>[];

      // 1. Extract WordPress article cards (e.g. BMaal, UffMaal)
      final articlePattern = RegExp(
        r'<article[^>]*>.*?<a\s+href="([^"]+)"[^>]*>.*?<img[^>]+(?:src|data-src)="([^"]+)"[^>]*>.*?(?:<h[1-6][^>]*>(.*?)</h[1-6]>|title="([^"]+)").*?</article>',
        dotAll: true,
        caseSensitive: false,
      );

      for (final m in articlePattern.allMatches(body)) {
        final href = m.group(1) ?? '';
        final img = m.group(2) ?? '';
        final rawTitle = m.group(3) ?? m.group(4) ?? '';
        final cleanTitle = _unescapeHtml(rawTitle.replaceAll(RegExp(r'<[^>]+>'), '').trim());

        if (href.isEmpty || cleanTitle.isEmpty) continue;
        if (!href.startsWith('http') && !href.startsWith('/')) continue;

        final fullUrl = href.startsWith('http') ? href : '$baseUrl$href';

        items.add(MaalNetworkItem(
          title: cleanTitle,
          pageUrl: fullUrl,
          poster: img.startsWith('http') ? img : '$baseUrl$img',
          siteName: siteInfo['name'] ?? domain,
          siteDomain: domain,
        ));
      }

      // 2. Extract post-card layouts (e.g. WOWMaal, NewMaal)
      if (items.isEmpty) {
        final postCardPattern = RegExp(
          r'<a\b[^>]+href="([^"]+)"[^>]*class="[^"]*post-card[^"]*"[^>]*>.*?<img[^>]+(?:src|data-src)="([^"]+)"[^>]*>.*?<h[1-6][^>]*class="[^"]*post-card-title[^"]*"[^>]*>(.*?)</h[1-6]>',
          dotAll: true,
          caseSensitive: false,
        );
        for (final m in postCardPattern.allMatches(body)) {
          final href = m.group(1) ?? '';
          final img = m.group(2) ?? '';
          final rawTitle = m.group(3) ?? '';
          final cleanTitle = _unescapeHtml(rawTitle.replaceAll(RegExp(r'<[^>]+>'), '').trim());

          if (href.isEmpty || cleanTitle.isEmpty) continue;
          final fullUrl = href.startsWith('http') ? href : '$baseUrl$href';

          items.add(MaalNetworkItem(
            title: cleanTitle,
            pageUrl: fullUrl,
            poster: img.startsWith('http') ? img : '$baseUrl$img',
            siteName: siteInfo['name'] ?? domain,
            siteDomain: domain,
          ));
        }
      }

      // 3. Fallback: simpler link+image extraction
      if (items.isEmpty) {
        final simplePattern = RegExp(
          r'href="(https?://[^"]*' + RegExp.escape(domain) + r'[^"]*)"[^>]*>[^<]*<[^>]*>[^<]*<img[^>]+(?:src|data-src)="([^"]+)"',
          caseSensitive: false,
        );
        for (final m in simplePattern.allMatches(body).take(20)) {
          final href = m.group(1) ?? '';
          final img = m.group(2) ?? '';
          if (href.isEmpty) continue;
          items.add(MaalNetworkItem(
            title: _titleFromUrl(href),
            pageUrl: href,
            poster: img,
            siteName: siteInfo['name'] ?? domain,
            siteDomain: domain,
          ));
        }
      }

      return items.take(15).toList();
    } catch (e) {
      debugPrint('MaalNetwork client search [$domain]: $e');
      return [];
    }
  }

  // ──────────────────────────────────────────────────────────────
  //  EPISODE DETAILS (stream URL + poster)
  // ──────────────────────────────────────────────────────────────

  /// Extract stream URL and poster from an episode page.
  static Future<MaalNetworkEpisodeDetails?> fetchEpisodeDetails(
      String pageUrl) async {
    // Try server first
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/admin_api.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'extract_maal_network_episode',
          'page_url': pageUrl,
        }),
      ).timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['success'] == true && (data['stream_url'] ?? '').isNotEmpty) {
          return MaalNetworkEpisodeDetails(
            streamUrl: _unescapeHtml(data['stream_url']),
            poster: data['poster'],
            title: data['title'],
            images: List<String>.from(data['images'] ?? []),
            referer: data['referer'],
          );
        }
      }
    } catch (e) {
      debugPrint('MaalNetwork server extract failed: $e');
    }

    // Client-side fallback
    return _fetchEpisodeDetailsClient(pageUrl);
  }

  static Future<MaalNetworkEpisodeDetails?> _fetchEpisodeDetailsClient(
      String pageUrl) async {
    try {
      final uri = Uri.parse(pageUrl);
      final baseUrl = '${uri.scheme}://${uri.host}';

      final res = await http.get(
        Uri.parse(pageUrl),
        headers: {
          ..._commonHeaders,
          'Referer': baseUrl,
        },
      ).timeout(const Duration(seconds: 20));

      if (res.statusCode != 200) return null;

      final body = res.body;

      // 1. JSON-LD Schema embedUrl (e.g. BMaal, AzMaal)
      final jsonLdMatch = RegExp(
        r'"embedUrl"\s*:\s*"([^"]+)"',
        caseSensitive: false,
      ).firstMatch(body);
      if (jsonLdMatch != null) {
        final rawStream = _unescapeHtml(jsonLdMatch.group(1)!);
        final streamUrl = _resolveUrl(rawStream, baseUrl);
        final poster = _extractPoster(body, baseUrl);
        final images = _extractImages(body, baseUrl, uri.host);
        return MaalNetworkEpisodeDetails(
          streamUrl: streamUrl,
          poster: poster,
          images: images,
          referer: baseUrl,
        );
      }

      // 2. Direct <source src="..."> or <video src="..."> (e.g. WOWMaal, NewMaal)
      final sourceMatch = RegExp(
              r'<source[^>]+src=["\x27]([^"\x27]+\.(?:mp4|m3u8)[^"\x27]*)["\x27]',
              caseSensitive: false)
          .firstMatch(body);
      if (sourceMatch != null) {
        final rawStream = _unescapeHtml(sourceMatch.group(1)!);
        final streamUrl = _resolveUrl(rawStream, baseUrl);
        final poster = _extractPoster(body, baseUrl);
        final images = _extractImages(body, baseUrl, uri.host);
        return MaalNetworkEpisodeDetails(
          streamUrl: streamUrl,
          poster: poster,
          images: images,
          referer: baseUrl,
        );
      }

      // 3. video src="..."
      final videoSrcMatch =
          RegExp(r'<video[^>]+src=["\x27]([^"\x27]+)["\x27]', caseSensitive: false)
              .firstMatch(body);
      if (videoSrcMatch != null) {
        final url = _unescapeHtml(videoSrcMatch.group(1)!);
        if (url.contains('.mp4') || url.contains('.m3u8')) {
          return MaalNetworkEpisodeDetails(
            streamUrl: _resolveUrl(url, baseUrl),
            poster: _extractPoster(body, baseUrl),
            images: _extractImages(body, baseUrl, uri.host),
            referer: baseUrl,
          );
        }
      }

      // 4. file: "URL" (jwplayer style)
      final jwMatch = RegExp(
              r'''file\s*:\s*["']([^"']+\.(?:mp4|m3u8)[^"']*)["']''',
              caseSensitive: false)
          .firstMatch(body);
      if (jwMatch != null) {
        final rawStream = _unescapeHtml(jwMatch.group(1)!);
        return MaalNetworkEpisodeDetails(
          streamUrl: _resolveUrl(rawStream, baseUrl),
          poster: _extractPoster(body, baseUrl),
          images: _extractImages(body, baseUrl, uri.host),
          referer: baseUrl,
        );
      }

      // 5. data-src or data-file
      final dataSrcMatch = RegExp(
              r'''data-(?:src|file|video)=["']([^"']+\.(?:mp4|m3u8)[^"']*)["']''',
              caseSensitive: false)
          .firstMatch(body);
      if (dataSrcMatch != null) {
        final rawStream = _unescapeHtml(dataSrcMatch.group(1)!);
        return MaalNetworkEpisodeDetails(
          streamUrl: _resolveUrl(rawStream, baseUrl),
          poster: _extractPoster(body, baseUrl),
          images: _extractImages(body, baseUrl, uri.host),
          referer: baseUrl,
        );
      }

      // 6. Look for embedded iframe (player pages)
      final iframeMatch =
          RegExp(r'<iframe[^>]+src=["\x27]([^"\x27]+)["\x27]', caseSensitive: false)
              .firstMatch(body);
      if (iframeMatch != null) {
        final iframeSrc = _unescapeHtml(iframeMatch.group(1)!);
        // Known embed hosts
        if (iframeSrc.contains('cdn.') ||
            iframeSrc.contains('player.') ||
            iframeSrc.contains('ivdo.cc') ||
            iframeSrc.contains('/embed/')) {
          return MaalNetworkEpisodeDetails(
            streamUrl: _resolveUrl(iframeSrc, baseUrl),
            poster: _extractPoster(body, baseUrl),
            images: _extractImages(body, baseUrl, uri.host),
            referer: baseUrl,
          );
        }
      }

      return null;
    } catch (e) {
      debugPrint('MaalNetwork client extract [$pageUrl]: $e');
      return null;
    }
  }

  // ──────────────────────────────────────────────────────────────
  //  HELPERS
  // ──────────────────────────────────────────────────────────────

  static Map<String, String>? _infoForDomain(String domain) {
    try {
      return allSites.firstWhere((s) => s['domain'] == domain);
    } catch (_) {
      return null;
    }
  }

  static String _resolveUrl(String url, String baseUrl) {
    if (url.startsWith('http')) return url;
    if (url.startsWith('//')) return 'https:$url';
    if (url.startsWith('/')) return '$baseUrl$url';
    return '$baseUrl/$url';
  }

  static String? _extractPoster(String body, String baseUrl) {
    final ogMatch = RegExp(
            r'<meta[^>]+property=["\x27]og:image["\x27][^>]+content=["\x27]([^"\x27]+)["\x27]',
            caseSensitive: false)
        .firstMatch(body);
    if (ogMatch != null) return ogMatch.group(1);

    final posterMatch = RegExp(
            r'poster=["\x27]([^"\x27]+\.(?:jpg|jpeg|png|webp)[^"\x27]*)["\x27]',
            caseSensitive: false)
        .firstMatch(body);
    if (posterMatch != null) return _resolveUrl(posterMatch.group(1)!, baseUrl);
    return null;
  }

  static List<String> _extractImages(
      String body, String baseUrl, String host) {
    final imgs = <String>[];
    final pattern = RegExp(
        r'<img[^>]+src=["\x27]([^"\x27]+\.(?:jpg|jpeg|png|webp)[^"\x27]*)["\x27]',
        caseSensitive: false);
    for (final m in pattern.allMatches(body)) {
      final src = m.group(1) ?? '';
      if (src.isEmpty || src.contains('logo') || src.contains('icon')) continue;
      imgs.add(_resolveUrl(src, baseUrl));
      if (imgs.length >= 10) break;
    }
    return imgs;
  }

  static String _titleFromUrl(String url) {
    try {
      final path = Uri.parse(url).pathSegments.lastWhere((s) => s.isNotEmpty,
          orElse: () => 'Episode');
      return path.replaceAll(RegExp(r'[-_]'), ' ').trim();
    } catch (_) {
      return 'Episode';
    }
  }
}
