import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// An item extracted from HotUllu, MastiWala, or AagMaal.mba.
class HotulluMastiwalaItem {
  final String title;
  final String pageUrl;
  final String poster;
  final bool isEpisode;
  final String source; // 'hotullu' | 'mastiwala' | 'aagmaal'

  HotulluMastiwalaItem({
    required this.title,
    required this.pageUrl,
    required this.poster,
    this.isEpisode = false,
    required this.source,
  });
}

/// Extracted stream and media details.
class HotulluMastiwalaDetails {
  final String? streamUrl;
  final String? poster;
  final String? title;
  final List<String> screenshots;

  HotulluMastiwalaDetails({
    this.streamUrl,
    this.poster,
    this.title,
    this.screenshots = const [],
  });
}

class HotulluMastiwalaScraper {
  static const String hotulluBase = 'https://hotullu.cc';
  static const String mastiwalaBase = 'https://mastiwala.com';
  static const String aagmaalBase = 'https://aagmaal.mba';

  static final Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
  };

  /// Main search method across HotUllu, MastiWala, or AagMaal.mba
  static Future<List<HotulluMastiwalaItem>> search(String query, String source) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    switch (source.toLowerCase()) {
      case 'hotullu':
        return _searchHotullu(q);
      case 'mastiwala':
        return _searchMastiWala(q);
      case 'aagmaal':
        return _searchAagmaal(q);
      default:
        return _searchHotullu(q);
    }
  }

  // ── 1. HotUllu Search ──────────────────────────────────────────
  static Future<List<HotulluMastiwalaItem>> _searchHotullu(String query) async {
    final results = <HotulluMastiwalaItem>[];
    final seen = <String>{};

    for (final base in [hotulluBase, 'https://hotullu.tv']) {
      try {
        final url = '$base/?s=${Uri.encodeComponent(query)}';
        final res = await http.get(Uri.parse(url), headers: {
          ..._headers,
          'Referer': '$base/',
        }).timeout(const Duration(seconds: 10));

        if (res.statusCode != 200) continue;
        final html = res.body;

        final articleReg = RegExp(r'<article[^>]*>([\s\S]*?)</article>', caseSensitive: false);
        for (final m in articleReg.allMatches(html)) {
          final block = m.group(1) ?? '';
          final linkM = RegExp(r'<a[^>]+href=["\x27](https?://[^"\x27]+)["\x27]', caseSensitive: false).firstMatch(block);
          if (linkM == null) continue;
          final pageUrl = linkM.group(1)!.trim();
          if (seen.contains(pageUrl) || pageUrl.contains('/category/') || pageUrl.contains('/tag/')) continue;

          // Title
          var title = '';
          final titleM = RegExp(r'<(?:h2|h1|a)[^>]*class=["\x27][^"\x27]*(?:title|entry-title)[^"\x27]*["\x27][^>]*>([\s\S]*?)</', caseSensitive: false).firstMatch(block);
          if (titleM != null) {
            title = _cleanHtml(titleM.group(1)!);
          } else {
            final anyH2 = RegExp(r'<h2[^>]*>([\s\S]*?)</h2>', caseSensitive: false).firstMatch(block);
            if (anyH2 != null) title = _cleanHtml(anyH2.group(1)!);
          }

          // Image
          var poster = '';
          final imgM = RegExp(r'<img[^>]+(?:src|data-src)=["\x27](https?://[^"\x27]+)["\x27]', caseSensitive: false).firstMatch(block);
          if (imgM != null) poster = imgM.group(1)!.trim();

          if (title.isNotEmpty) {
            seen.add(pageUrl);
            results.add(HotulluMastiwalaItem(
              title: title,
              pageUrl: pageUrl,
              poster: poster,
              isEpisode: pageUrl.contains('episode') || pageUrl.contains('-part-'),
              source: 'hotullu',
            ));
          }
        }
        if (results.isNotEmpty) return results;
      } catch (e) {
        debugPrint('[HotulluScraper] search error on $base: $e');
      }
    }
    return results;
  }

  // ── 2. MastiWala Search ─────────────────────────────────────────
  static Future<List<HotulluMastiwalaItem>> _searchMastiWala(String query) async {
    final results = <HotulluMastiwalaItem>[];
    final seen = <String>{};

    try {
      final url = '$mastiwalaBase/?s=${Uri.encodeComponent(query)}';
      final res = await http.get(Uri.parse(url), headers: {
        ..._headers,
        'Referer': '$mastiwalaBase/',
      }).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final html = res.body;
        final articleReg = RegExp(r'<article[^>]*>([\s\S]*?)</article>', caseSensitive: false);
        for (final m in articleReg.allMatches(html)) {
          final block = m.group(1) ?? '';
          final linkM = RegExp(r'<a[^>]+href=["\x27](https?://[^"\x27]+)["\x27]', caseSensitive: false).firstMatch(block);
          if (linkM == null) continue;
          final pageUrl = linkM.group(1)!.trim();
          if (seen.contains(pageUrl) || pageUrl.contains('/category/') || pageUrl.contains('/tag/')) continue;

          var title = '';
          final h2M = RegExp(r'<h2[^>]*>([\s\S]*?)</h2>', caseSensitive: false).firstMatch(block);
          if (h2M != null) {
            title = _cleanHtml(h2M.group(1)!);
          } else {
            final titleM = RegExp(r'alt=["\x27]([^"\x27]+)["\x27]', caseSensitive: false).firstMatch(block);
            if (titleM != null) title = _cleanHtml(titleM.group(1)!);
          }

          var poster = '';
          final imgM = RegExp(r'<img[^>]+(?:src|data-src)=["\x27](https?://[^"\x27]+)["\x27]', caseSensitive: false).firstMatch(block);
          if (imgM != null) poster = imgM.group(1)!.trim();

          if (title.isNotEmpty) {
            seen.add(pageUrl);
            results.add(HotulluMastiwalaItem(
              title: title,
              pageUrl: pageUrl,
              poster: poster,
              isEpisode: pageUrl.contains('episode') || pageUrl.contains('-part-'),
              source: 'mastiwala',
            ));
          }
        }
      }
    } catch (e) {
      debugPrint('[MastiWalaScraper] search error: $e');
    }
    return results;
  }

  // ── 3. AagMaal.mba Search ───────────────────────────────────────
  static Future<List<HotulluMastiwalaItem>> _searchAagmaal(String query) async {
    final results = <HotulluMastiwalaItem>[];
    final seen = <String>{};

    for (final base in [aagmaalBase, 'https://aagmaal.bz', 'https://aagmaal.hot']) {
      try {
        final url = '$base/?s=${Uri.encodeComponent(query)}';
        final res = await http.get(Uri.parse(url), headers: {
          ..._headers,
          'Referer': '$base/',
        }).timeout(const Duration(seconds: 10));

        if (res.statusCode != 200) continue;
        final html = res.body;

        final articleReg = RegExp(r'<article[^>]*>([\s\S]*?)</article>', caseSensitive: false);
        for (final m in articleReg.allMatches(html)) {
          final block = m.group(1) ?? '';
          final linkM = RegExp(r'<a[^>]+href=["\x27](https?://[^"\x27]+)["\x27]', caseSensitive: false).firstMatch(block);
          if (linkM == null) continue;
          final pageUrl = linkM.group(1)!.trim();
          if (seen.contains(pageUrl) || pageUrl.contains('/category/') || pageUrl.contains('/tag/')) continue;

          var title = '';
          final h2M = RegExp(r'<(?:h2|h1|h3)[^>]*>([\s\S]*?)</(?:h2|h1|h3)>', caseSensitive: false).firstMatch(block);
          if (h2M != null) title = _cleanHtml(h2M.group(1)!);

          var poster = '';
          final imgM = RegExp(r'<img[^>]+(?:src|data-src)=["\x27](https?://[^"\x27]+)["\x27]', caseSensitive: false).firstMatch(block);
          if (imgM != null) poster = imgM.group(1)!.trim();

          if (title.isNotEmpty) {
            seen.add(pageUrl);
            results.add(HotulluMastiwalaItem(
              title: title,
              pageUrl: pageUrl,
              poster: poster,
              isEpisode: pageUrl.contains('episode') || pageUrl.contains('-part-'),
              source: 'aagmaal',
            ));
          }
        }
        if (results.isNotEmpty) return results;
      } catch (e) {
        debugPrint('[AagMaalScraper] search error on $base: $e');
      }
    }
    return results;
  }

  // ── Fetch Episode Stream & Poster Details ────────────────────────
  static Future<HotulluMastiwalaDetails?> fetchEpisodeDetails(String pageUrl) async {
    final cleanUrl = pageUrl.trim();
    if (cleanUrl.isEmpty) return null;

    try {
      final uri = Uri.parse(cleanUrl);
      final res = await http.get(uri, headers: {
        ..._headers,
        'Referer': '${uri.scheme}://${uri.host}/',
      }).timeout(const Duration(seconds: 12));

      if (res.statusCode != 200) return null;
      final html = res.body;

      // 1. Direct stream URLs (video.maalcdn.com or MP4 / M3U8)
      String? streamUrl;
      final videoM = RegExp(
        r'''(https?://[^\s"'<>]+\.(?:mp4|m3u8)(?:\?[^\s"'<>]*)?)''',
        caseSensitive: false,
      ).allMatches(html);

      for (final vm in videoM) {
        var rawUrl = vm.group(1)!.replaceAll('&amp;', '&').trim();
        if (rawUrl.contains('video.maalcdn.com') || rawUrl.contains('.mp4') || rawUrl.contains('.m3u8')) {
          streamUrl = rawUrl;
          break;
        }
      }

      // Check <source src="...">
      if (streamUrl == null || streamUrl.isEmpty) {
        final srcM = RegExp(r'''<source[^>]+src=["\x27](https?://[^"\x27]+)["\x27]''', caseSensitive: false).firstMatch(html);
        if (srcM != null) {
          streamUrl = srcM.group(1)!.replaceAll('&amp;', '&').trim();
        }
      }

      // Check iframe embeds
      if (streamUrl == null || streamUrl.isEmpty) {
        final iframeM = RegExp(r'''<iframe[^>]+src=["\x27](https?://[^"\x27]+)["\x27]''', caseSensitive: false).firstMatch(html);
        if (iframeM != null) {
          streamUrl = iframeM.group(1)!.replaceAll('&amp;', '&').trim();
        }
      }

      // 2. Poster / Og:Image
      String? poster;
      final ogM = RegExp(r'''<meta[^>]+property=["\x27]og:image["\x27][^>]+content=["\x27](https?://[^"\x27]+)["\x27]''', caseSensitive: false).firstMatch(html);
      if (ogM != null) {
        poster = ogM.group(1)!.trim();
      } else {
        final imgM = RegExp(r'''<img[^>]+(?:src|data-src)=["\x27](https?://[^"\x27]+\.(?:jpg|png|webp|jpeg))["\x27]''', caseSensitive: false).firstMatch(html);
        if (imgM != null) poster = imgM.group(1)!.trim();
      }

      // 3. Title
      String? title;
      final h1M = RegExp(r'''<h1[^>]*>([\s\S]*?)</h1>''', caseSensitive: false).firstMatch(html);
      if (h1M != null) title = _cleanHtml(h1M.group(1)!);

      // 4. Screenshots
      final screenshots = <String>[];
      final allImgs = RegExp(r'''<img[^>]+(?:src|data-src)=["\x27](https?://[^"\x27]+)["\x27]''', caseSensitive: false).allMatches(html);
      for (final im in allImgs) {
        final u = im.group(1)!.trim();
        if (u.contains('/uploads/') && !screenshots.contains(u)) {
          screenshots.add(u);
        }
      }

      return HotulluMastiwalaDetails(
        streamUrl: streamUrl,
        poster: poster,
        title: title,
        screenshots: screenshots,
      );
    } catch (e) {
      debugPrint('[HotulluMastiwalaScraper] fetchDetails error for $pageUrl: $e');
    }
    return null;
  }

  // ── Fetch Series Episodes ──────────────────────────────────────
  static Future<List<HotulluMastiwalaItem>> fetchSeriesEpisodes(String seriesUrl, String source) async {
    final episodes = <HotulluMastiwalaItem>[];
    try {
      final uri = Uri.parse(seriesUrl);
      final res = await http.get(uri, headers: {
        ..._headers,
        'Referer': '${uri.scheme}://${uri.host}/',
      }).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return [];
      final html = res.body;

      final epLinks = RegExp(r'''<a[^>]+href=["\x27](https?://[^"\x27]+)["\x27][^>]*>([\s\S]*?)</a>''', caseSensitive: false).allMatches(html);
      final seen = <String>{};

      for (final m in epLinks) {
        final href = m.group(1)!.trim();
        final label = _cleanHtml(m.group(2) ?? '');
        if (seen.contains(href) || href == seriesUrl) continue;

        final isEp = href.contains('episode') ||
            href.contains('-part-') ||
            label.toLowerCase().contains('episode') ||
            label.toLowerCase().contains('part');

        if (isEp && label.isNotEmpty) {
          seen.add(href);
          episodes.add(HotulluMastiwalaItem(
            title: label,
            pageUrl: href,
            poster: '',
            isEpisode: true,
            source: source,
          ));
        }
      }
    } catch (_) {}
    return episodes;
  }

  static String _cleanHtml(String raw) {
    return raw
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&#8211;', '–')
        .replaceAll('&#8217;', "'")
        .replaceAll('&quot;', '"')
        .replaceAll('&#038;', '&')
        .trim();
  }
}
