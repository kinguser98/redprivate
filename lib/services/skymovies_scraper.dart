import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import 'headless_capture.dart';

class SkymoviesEntry {
  final String title;
  final String pageUrl;
  final String poster;

  SkymoviesEntry({
    required this.title,
    required this.pageUrl,
    required this.poster,
  });
}

class SkymoviesScraper {
  static const List<String> mirrors = [
    'https://skymovieshd.forex',
    'https://skymovieshd.bar',
    'https://skymovieshd.live',
    'https://skymovieshd.bid',
    'https://skymovieshd.ink',
    'https://skymovieshd.lat',
    'https://skymovieshd.tube',
    'https://skymovieshd.run',
    'https://skymovieshd.life',
  ];

  static String activeMirror = mirrors.first;

  /// Returns active mirror list dynamically prioritizing the domain set in App Settings
  static Future<List<String>> getMirrors() async {
    final list = <String>[];
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedDomain = prefs.getString('skymovies_domain')?.trim() ?? '';
      if (savedDomain.isNotEmpty && savedDomain.startsWith('http')) {
        list.add(savedDomain.endsWith('/') ? savedDomain.substring(0, savedDomain.length - 1) : savedDomain);
      }
    } catch (_) {}
    for (final m in mirrors) {
      if (!list.contains(m)) list.add(m);
    }
    if (list.isNotEmpty) activeMirror = list.first;
    return list;
  }

  /// Helper to call backend PHP API for guaranteed Skymovies results
  static Future<Map<String, dynamic>> _callAdminApi(
      String action, Map<String, dynamic> body,
      {int timeout = 15}) async {
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

  /// Helper to fetch URL and automatically follow JS redirect or tr_uuid challenge links
  static Future<String?> _fetchWithChallenge(String initialUrl, String domain) async {
    try {
      final res = await http.get(Uri.parse(initialUrl), headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'Referer': '$domain/',
      }).timeout(const Duration(seconds: 6));

      if (res.statusCode != 200) return null;
      var body = res.body;

      // 1. Check for "Click here to enter" or tr_uuid challenge in body
      final clickMatch = RegExp(
              r'<a\s+[^>]*href=[\x27\x22]([^\x27\x22]*tr_uuid[^\x27\x22]*)[\x27\x22]',
              caseSensitive: false)
          .firstMatch(body);
      if (clickMatch != null) {
        var entryUrl = clickMatch.group(1)!;
        if (entryUrl.startsWith('http://')) {
          entryUrl = entryUrl.replaceFirst('http://', 'https://');
        }
        final finalUri =
            Uri.parse(entryUrl.startsWith('http') ? entryUrl : '$domain$entryUrl');
        final res2 = await http.get(finalUri, headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          'Referer': initialUrl,
        }).timeout(const Duration(seconds: 6));
        if (res2.statusCode == 200) {
          return res2.body;
        }
      }

      // 2. Check for redirect_link in JS
      final redirectMatch =
          RegExp(r'redirect_link\s*=\s*[\x27\x22]([^\x27\x22]+)').firstMatch(body);
      if (redirectMatch != null) {
        var rUrl = redirectMatch.group(1)!;
        if (rUrl.startsWith('http://')) {
          rUrl = rUrl.replaceFirst('http://', 'https://');
        }
        final rUri = Uri.parse(rUrl.startsWith('http') ? rUrl : '$domain$rUrl');
        final res2 = await http.get(rUri, headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          'Referer': initialUrl,
        }).timeout(const Duration(seconds: 6));
        if (res2.statusCode == 200) {
          return res2.body;
        }
      }

      return body;
    } catch (_) {
      return null;
    }
  }

  /// Search SkymoviesHD for movies or series parts
  static Future<List<SkymoviesEntry>> search(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    final entries = <SkymoviesEntry>[];
    final seenUrls = <String>{};

    // Build intelligent query variations
    final queryList = <String>[cleanQuery];
    if (cleanQuery.contains(':')) {
      for (final part in cleanQuery.split(':')) {
        final p = part.trim();
        if (p.length > 3 && !queryList.contains(p)) queryList.add(p);
      }
    }
    if (cleanQuery.contains('-')) {
      for (final part in cleanQuery.split('-')) {
        final p = part.trim();
        if (p.length > 3 && !queryList.contains(p)) queryList.add(p);
      }
    }
    final words = cleanQuery.replaceAll(':', ' ').replaceAll('-', ' ').split(RegExp(r'\s+')).where((w) => w.length > 1).toList();
    if (words.length > 3) {
      final sub1 = words.sublist(2).join(' ').trim();
      if (sub1.length > 3 && !queryList.contains(sub1)) queryList.add(sub1);
      final sub2 = words.sublist(0, 2).join(' ').trim();
      if (sub2.length > 3 && !queryList.contains(sub2)) queryList.add(sub2);
      final sub3 = words.sublist(words.length - 3).join(' ').trim();
      if (sub3.length > 3 && !queryList.contains(sub3)) queryList.add(sub3);
    }

    // 1. PRIMARY FAST SEARCH: Backend PHP API (works without local ISP blocks)
    for (final q in queryList) {
      try {
        final res = await _callAdminApi('search_skymovies_catalog', {'query': q});
        if (res['status'] == 'success' && res['data']?['items'] != null) {
          final items = res['data']['items'] as List<dynamic>;
          for (final item in items) {
            final pageUrl = (item['page_url'] ?? item['url'] ?? '').toString().trim();
            final title = (item['title'] ?? '').toString().trim();
            var poster = (item['poster'] ?? '').toString().trim();

            if (pageUrl.contains('skybap') || pageUrl.contains('search.php') || title == 'Home' || title.length < 4) continue;
            if (poster.contains('arw.gif') || poster.contains('logo')) poster = '';

            if (pageUrl.isNotEmpty && title.isNotEmpty && !seenUrls.contains(pageUrl)) {
              seenUrls.add(pageUrl);
              entries.add(SkymoviesEntry(title: title, pageUrl: pageUrl, poster: poster));
            }
          }
        }
        if (entries.isNotEmpty) return entries;
      } catch (_) {}
    }

    // 2. DIRECT HTTP SCRAPING: Across all active mirrors with ?search= & ?find=
    final activeMirrors = await getMirrors();
    for (final q in queryList) {
      for (final domain in activeMirrors) {
        try {
          final searchUrls = [
            "$domain/search.php?search=${Uri.encodeComponent(q)}&cat=All",
            "$domain/search.php?find=${Uri.encodeComponent(q)}",
          ];

          for (final sUrl in searchUrls) {
            final html = await _fetchWithChallenge(sUrl, domain);
            if (html == null || html.isEmpty) continue;

            activeMirror = domain;

            // Regex for all result links
            final aReg = RegExp(
              r'<a\s+[^>]*href=["\x27]([^"\x27]*(?:/movie/|\.html)[^"\x27]*)["\x27][^>]*>([\s\S]*?)<\/a>',
              caseSensitive: false,
            );
            for (final m in aReg.allMatches(html)) {
              var pageUrl = m.group(1)!.trim();
              if (pageUrl.contains('search.php') ||
                  pageUrl.contains('disclaimer') ||
                  pageUrl.contains('contact') ||
                  pageUrl.contains('skybap')) continue;
              if (!pageUrl.startsWith('http')) {
                pageUrl = '$domain/${pageUrl.startsWith('/') ? pageUrl.substring(1) : pageUrl}';
              }
              final inner = m.group(2)!;

              // Extract title
              var title = '';
              final bMatch = RegExp(r'<b>([^<]+)</b>', caseSensitive: false).firstMatch(inner);
              if (bMatch != null) {
                title = bMatch.group(1)!.trim();
              } else {
                title = inner.replaceAll(RegExp(r'<[^>]*>'), '').trim();
              }

              // Extract img if present
              var poster = '';
              final imgMatch = RegExp(r'<img[^>]+(?:src|data-src)=["\x27]([^"\x27]+)["\x27]',
                      caseSensitive: false)
                  .firstMatch(inner);
              if (imgMatch != null) {
                poster = imgMatch.group(1)!.trim();
                if (poster.contains('arw.gif') || poster.contains('logo')) {
                  poster = '';
                } else if (poster.isNotEmpty && !poster.startsWith('http')) {
                  poster = '$domain/${poster.startsWith('/') ? poster.substring(1) : poster}';
                }
              }

              if (title.length > 3 && !seenUrls.contains(pageUrl)) {
                seenUrls.add(pageUrl);
                entries.add(SkymoviesEntry(title: title, pageUrl: pageUrl, poster: poster));
              }
            }

            if (entries.isNotEmpty) return entries;
          }
        } catch (_) {}
      }
    }

    // 3. Headless Fallback
    try {
      final js = '''
        setTimeout(function() {
          var items = [];
          var links = document.querySelectorAll('a');
          links.forEach(function(a) {
            var h = a.href || '';
            var t = (a.innerText || '').trim();
            var img = a.querySelector('img');
            var p = img ? (img.src || img.getAttribute('data-src') || '') : '';
            if (h && (h.indexOf('/movie/') !== -1 || h.indexOf('.html') !== -1) && t.length > 3 && h.indexOf('skybap') === -1) {
              items.push({title: t, pageUrl: h, poster: p.indexOf('arw.gif') === -1 ? p : ''});
            }
          });
          window.flutter_inappwebview.callHandler('onSkymoviesResult', JSON.stringify(items));
        }, 1800);
      ''';
      final capturedJson = await HeadlessCapture.capture(
        "${mirrors.first}/search.php?search=${Uri.encodeComponent(cleanQuery)}&cat=All",
        'onSkymoviesResult',
        js,
        timeout: const Duration(seconds: 7),
      );
      if (capturedJson != null && capturedJson.isNotEmpty) {
        final list = jsonDecode(capturedJson);
        if (list is List) {
          for (final it in list) {
            final title = (it['title'] ?? '').toString().trim();
            final pageUrl = (it['pageUrl'] ?? '').toString().trim();
            final poster = (it['poster'] ?? '').toString().trim();
            if (title.isNotEmpty && pageUrl.isNotEmpty && !seenUrls.contains(pageUrl)) {
              seenUrls.add(pageUrl);
              entries.add(SkymoviesEntry(title: title, pageUrl: pageUrl, poster: poster));
            }
          }
          if (entries.isNotEmpty) return entries;
        }
      }
    } catch (_) {}

    return [];
  }

  static Future<List<String>> fetchScreenshots(String pageUrl) async {
    final cleanUrl = pageUrl.trim();
    if (cleanUrl.isEmpty) return [];

    final screenshotUrls = <String>[];
    final seen = <String>{};

    try {
      final domain = Uri.parse(cleanUrl).origin;
      final html = await _fetchWithChallenge(cleanUrl, domain);

      if (html != null && html.isNotEmpty) {
        // Step 1: Collect inline images (posters, imageflix, postimg, etc.)
        final imgReg = RegExp(
          r'<img[^>]+(?:src|data-src)=[\x27\x22]?\s*(https?://[^\s\x27\x22<>]+\.(?:jpg|jpeg|png|webp)[^\s\x27\x22<>]*)',
          caseSensitive: false,
        );
        for (final m in imgReg.allMatches(html)) {
          final imgUrl = m.group(1)!.replaceAll('&amp;', '&').trim();
          final lower = imgUrl.toLowerCase();
          if (lower.contains('logo') ||
              lower.contains('icon') ||
              lower.contains('arrow') ||
              lower.contains('arw.gif') ||
              lower.contains('telegram') ||
              lower.contains('button') ||
              lower.contains('banner') ||
              lower.contains('avatar') ||
              lower.contains('ad')) continue;
          if (!seen.contains(imgUrl)) {
            seen.add(imgUrl);
            screenshotUrls.add(imgUrl);
          }
        }

        // Secondary regex in case any image URLs are in data attributes or raw text
        final rawImgReg = RegExp(
          r'https?://(?:i\.imageflix\.[a-z]+|i\.postimg\.cc|imgbox\.com|imagetwist\.com|imagebam\.com)[^\s\x27\x22<>]+\.(?:jpg|jpeg|png|webp)',
          caseSensitive: false,
        );
        for (final m in rawImgReg.allMatches(html)) {
          final imgUrl = m.group(0)!.trim();
          if (!seen.contains(imgUrl)) {
            seen.add(imgUrl);
            screenshotUrls.add(imgUrl);
          }
        }

        // Step 2: Follow image-host link-throughs (imagetwist, imagebam, pixhost, imx.to etc.)
        final hostLinkReg = RegExp(
          r'<a[^>]+href=[\x27\x22](https?://(?:imagetwist\.com|imagebam\.com|pixhost\.to|imx\.to|imgbox\.com|imageban\.ru|pixxxels\.cc)[^"\x27]*)[\x27\x22]',
          caseSensitive: false,
        );
        final hostLinks = <String>{};
        for (final m in hostLinkReg.allMatches(html)) {
          hostLinks.add(m.group(1)!.trim());
        }

        // Fetch each host page in parallel (up to 12) to grab the full-size URL
        if (hostLinks.isNotEmpty) {
          final futures = hostLinks.take(12).map((link) => _resolveHostImage(link));
          final resolved = await Future.wait(futures);
          for (final imgUrl in resolved) {
            if (imgUrl != null && imgUrl.isNotEmpty && !seen.contains(imgUrl)) {
              seen.add(imgUrl);
              screenshotUrls.add(imgUrl);
            }
          }
        }
      }

      if (screenshotUrls.isNotEmpty) return screenshotUrls;

      // Backend details extractor fallback
      try {
        final res = await _callAdminApi('extract_skymovies_details', {'page_url': cleanUrl});
        final p = (res['data']?['poster'] ?? res['data']?['raw_poster'] ?? '').toString().trim();
        if (p.isNotEmpty && !seen.contains(p)) {
          seen.add(p);
          screenshotUrls.add(p);
        }
      } catch (_) {}

      return screenshotUrls;
    } catch (_) {
      return [];
    }
  }

  /// Fetch a single image-hosting page (imagetwist/imagebam/pixhost etc.)
  /// and extract the full-size image URL from its HTML.
  static Future<String?> _resolveHostImage(String hostUrl) async {
    try {
      final res = await http.get(Uri.parse(hostUrl), headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'Referer': hostUrl,
      }).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return null;
      final body = res.body;

      // imagetwist: <img class="pic" src="...">
      final twistMatch = RegExp(
        r'<img[^>]+class=[\x27\x22]pic[\x27\x22][^>]+src=[\x27\x22](https?://[^"\x27]+\.(?:jpg|jpeg|png))[\x27\x22]',
        caseSensitive: false,
      ).firstMatch(body);
      if (twistMatch != null) return twistMatch.group(1)!.trim();

      // imagebam: <div class="image-container"><img src="...">
      final bamMatch = RegExp(
        r'<div[^>]+class=[\x27\x22][^"\x27]*image-container[^"\x27]*[\x27\x22][^>]*>[^<]*<img[^>]+src=[\x27\x22](https?://[^"\x27]+\.(?:jpg|jpeg|png))[\x27\x22]',
        caseSensitive: false,
      ).firstMatch(body);
      if (bamMatch != null) return bamMatch.group(1)!.trim();

      // pixhost: img#image or .image-box img
      final pixMatch = RegExp(
        r'<img[^>]+id=[\x27\x22]image[\x27\x22][^>]+src=[\x27\x22](https?://[^"\x27]+\.(?:jpg|jpeg|png))[\x27\x22]|<div[^>]+class=[\x27\x22][^"\x27]*image-box[^"\x27]*[\x27\x22][^>]*>[^<]*<img[^>]+src=[\x27\x22](https?://[^"\x27]+\.(?:jpg|jpeg|png))[\x27\x22]',
        caseSensitive: false,
      ).firstMatch(body);
      if (pixMatch != null) return (pixMatch.group(1) ?? pixMatch.group(2))?.trim();

      // Generic: biggest/first full img with .jpg/.png (not thumbnail)
      final genericMatch = RegExp(
        r'<img[^>]+src=[\x27\x22](https?://[^"\x27]+\.(?:jpg|jpeg|png))[\x27\x22][^>]*>',
        caseSensitive: false,
      ).firstMatch(body);
      if (genericMatch != null) {
        final u = genericMatch.group(1)!.trim();
        if (!u.contains('thumb') && !u.contains('tn_') && !u.contains('_t.')) return u;
      }

      return null;
    } catch (_) {
      return null;
    }
  }
}
