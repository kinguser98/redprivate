import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dns_proxy.dart';
import 'luluvdo_resolver.dart';
import 'filemoon_resolver.dart';

class TellyhdScraper {
  static const String defaultDomain = 'https://tellyhd.at';

  static String _decodeHtmlEntities(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&#8211;', '-')
        .replaceAll('&#8212;', '—')
        .replaceAll('&#8216;', "'")
        .replaceAll('&#8217;', "'")
        .replaceAll('&#8220;', '"')
        .replaceAll('&#8221;', '"');
  }

  /// Cleans titles of common noise words for higher search hit rates
  static String cleanSearchQuery(String raw) {
    String clean = raw
        .replaceAll(RegExp(r'\b(s\d+|season\s*\d+|e\d+|episode\s*\d+|ep\s*\d+)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[.*?\]|\(.*?\)', caseSensitive: false), '')
        .replaceAll(
            RegExp(r'\b(480p|720p|1080p|2160p|4k|hevc|hdrip|web-dl|webrip|uncut|unrated|short\s*film|full\s*movie|hindi|telugu|tamil|bengali)\b',
                caseSensitive: false),
            '')
        .replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return clean;
  }

  /// Parses episode number from title or URL (e.g. "Episode 9", "Ep 02", "Part 3")
  static int? parseEpisodeNumber(String title, String url) {
    final combined = '$title $url'.toLowerCase();
    final epMatch = RegExp(r'(?:episode|ep|part)\s*[-_.:#]?\s*(\d+)', caseSensitive: false).firstMatch(combined);
    if (epMatch != null) {
      return int.tryParse(epMatch.group(1)!);
    }
    final sEpMatch = RegExp(r's\d+\s*[-_.]?\s*e(?:p)?(\d+)', caseSensitive: false).firstMatch(combined);
    if (sEpMatch != null) {
      return int.tryParse(sEpMatch.group(1)!);
    }
    final standalone = RegExp(r'\b(?:e|ep)(\d+)\b', caseSensitive: false).firstMatch(combined);
    if (standalone != null) {
      return int.tryParse(standalone.group(1)!);
    }
    return null;
  }

  /// Fetches HTML with standard browser headers and DoH proxy bypass for blocked ISPs
  static Future<String> _fetchHtml(String url, {String referer = 'https://tellyhd.at/'}) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) return '';

    // 1. Try via CustomDnsProxy (DoH) first if running, bypassing ISP DNS blocks
    final p = CustomDnsProxy().port;
    if (p != null) {
      try {
        final proxyUrl = 'http://127.0.0.1:$p/ep?u=${Uri.encodeComponent(cleanUrl)}&r=${Uri.encodeComponent(referer)}';
        final client = HttpClient()..badCertificateCallback = (c, h, p) => true;
        client.connectionTimeout = const Duration(seconds: 5);
        final req = await client.getUrl(Uri.parse(proxyUrl));
        final resp = await req.close().timeout(const Duration(seconds: 5));
        if (resp.statusCode == 200) {
          final html = await utf8.decodeStream(resp);
          client.close();
          if (html.isNotEmpty) return html;
        }
        client.close();
      } catch (e) {
        developer.log("CustomDnsProxy fetch failed for $cleanUrl, trying direct: $e");
      }
    }

    // 2. Direct fetch fallback with fast 5s timeout
    try {
      final client = HttpClient()..badCertificateCallback = (c, h, p) => true;
      client.connectionTimeout = const Duration(seconds: 5);
      final req = await client.getUrl(Uri.parse(cleanUrl));
      req.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36');
      req.headers.set('Referer', referer);
      req.headers.set('Accept', 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8');
      final resp = await req.close().timeout(const Duration(seconds: 5));
      if (resp.statusCode >= 300 && resp.statusCode < 400 && resp.headers.value('location') != null) {
        String loc = resp.headers.value('location')!;
        if (!loc.startsWith('http')) {
          loc = Uri.parse(cleanUrl).resolve(loc).toString();
        }
        client.close();
        return _fetchHtml(loc, referer: cleanUrl);
      }
      final html = await utf8.decodeStream(resp);
      client.close();
      return html;
    } catch (e) {
      developer.log("Direct fetch error for TellyHD URL ($cleanUrl): $e");
    }
    return '';
  }

  /// Searches TellyHD catalog client-side
  static Future<List<Map<String, dynamic>>> searchCatalog(String query, {String? customDomain}) async {
    final base = (customDomain != null && customDomain.trim().isNotEmpty) ? customDomain.trim().replaceAll(RegExp(r'/+$'), '') : defaultDomain;
    final results = <Map<String, dynamic>>[];
    final cleanQ = cleanSearchQuery(query);

    Future<List<Map<String, dynamic>>> doSearch(String q) async {
      final items = <Map<String, dynamic>>[];
      if (q.trim().isEmpty) return items;
      try {
        final searchUrl = '$base/?s=${Uri.encodeComponent(q.trim())}';
        final html = await _fetchHtml(searchUrl, referer: '$base/');
        if (html.isEmpty) return items;

        // 1. Look for DooPlay search result-item blocks
        final resultItemRegex = RegExp(r'<div class=["\x27]result-item["\x27]>(.*?)</div>\s*</div>\s*</article>', caseSensitive: false, dotAll: true);
        final itemMatches = resultItemRegex.allMatches(html).toList();

        final rawBlocks = <String>[];
        if (itemMatches.isNotEmpty) {
          for (final im in itemMatches) {
            rawBlocks.add(im.group(1)!);
          }
        } else {
          // Fallback: match <article> tags that are NOT sidebar widgets (w_item)
          final artRegex = RegExp(r'<article([^>]*)>(.*?)</article>', caseSensitive: false, dotAll: true);
          for (final am in artRegex.allMatches(html)) {
            final tagAttrs = am.group(1)!;
            if (tagAttrs.contains('w_item')) continue; // skip sidebar trending widgets
            rawBlocks.add(am.group(2)!);
          }
        }

        for (final artContent in rawBlocks) {
          final urlMatch = RegExp(r'''href=["\x27](https?://[^\s"\x27]+)["\x27]''', caseSensitive: false).firstMatch(artContent);
          if (urlMatch == null) continue;
          final postUrl = urlMatch.group(1)!;
          if (!postUrl.contains('/movies/') && !postUrl.contains('/tvshows/') && !postUrl.contains('/episodes/')) {
            continue;
          }

          final titleMatch = RegExp(r'''<div class=["\x27]title["\x27]>\s*<a[^>]*>(.*?)</a>''', caseSensitive: false, dotAll: true).firstMatch(artContent) ??
              RegExp(r'''alt=["\x27](.*?)["\x27]''', caseSensitive: false).firstMatch(artContent) ??
              RegExp(r'''<h3>(.*?)</h3>''', caseSensitive: false, dotAll: true).firstMatch(artContent);

          String title = titleMatch != null ? titleMatch.group(1)!.replaceAll(RegExp(r'<[^>]+>'), '').trim() : 'TellyHD Content';
          title = _decodeHtmlEntities(title);

          final imgMatch = RegExp(r'''src=["\x27](https?://[^\s"\x27]+)["\x27]''', caseSensitive: false).firstMatch(artContent);
          final poster = imgMatch != null ? imgMatch.group(1)! : '';

          final yearMatch = RegExp(r'''<span class=["\x27]year["\x27]>(\d{4})</span>''', caseSensitive: false).firstMatch(artContent);
          final year = yearMatch != null ? yearMatch.group(1)! : '';

          final epNum = parseEpisodeNumber(title, postUrl);

          items.add({
            'id': postUrl.hashCode.toString(),
            'title': title,
            'page_url': postUrl,
            'poster': poster,
            'year': year,
            'date': year,
            'ep_num': epNum,
          });
        }
      } catch (e) {
        developer.log("Error querying TellyHD search: $e");
      }
      return items;
    }

    // 1. Try search with clean query first
    if (cleanQ.isNotEmpty) {
      results.addAll(await doSearch(cleanQ));
    }

    // 2. If clean query returned empty and differs from original query, try original
    if (results.isEmpty && query.trim() != cleanQ && query.trim().isNotEmpty) {
      results.addAll(await doSearch(query.trim()));
    }

    // 3. Fallback: try first 2 words if query is long
    if (results.isEmpty) {
      final words = cleanQ.split(' ').where((w) => w.length > 2).toList();
      if (words.length > 2) {
        final shortQ = words.take(2).join(' ');
        results.addAll(await doSearch(shortQ));
      }
    }

    // Smart Relevance Ranking & Filtering
    final queryWords = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.length >= 2).toList();
    if (queryWords.isNotEmpty && results.isNotEmpty) {
      bool hasExactMatches = false;
      for (final it in results) {
        int score = 0;
        final tLower = (it['title'] ?? '').toString().toLowerCase();
        final uLower = (it['page_url'] ?? '').toString().toLowerCase();
        for (final kw in queryWords) {
          if (tLower.contains(kw)) score += 15;
          if (uLower.contains(kw)) score += 10;
        }
        it['match_score'] = score;
        if (score > 0) hasExactMatches = true;
      }

      var filtered = results;
      if (hasExactMatches) {
        filtered = results.where((it) => ((it['match_score'] as int?) ?? 0) > 0).toList();
      }

      filtered.sort((a, b) {
        final scoreComp = ((b['match_score'] as int?) ?? 0).compareTo((a['match_score'] as int?) ?? 0);
        if (scoreComp != 0) return scoreComp;
        return ((a['ep_num'] as int?) ?? 0).compareTo((b['ep_num'] as int?) ?? 0);
      });
      return filtered;
    }

    return results;
  }

  /// Extracts TellyHD post details with Server 1 (Pixeldrain), Server 2 (Vidara), Server 3 (Cdntelly)
  static Future<Map<String, dynamic>> extractDetails(
    String pageUrl, {
    Map<String, dynamic>? phpDetails,
  }) async {
    String title = '';
    String description = '';
    String poster = '';
    String rawPoster = '';
    String releaseDate = '';
    List<dynamic> playLinks = [];

    // Seed from PHP backend response if available
    if (phpDetails != null) {
      title = (phpDetails['title'] ?? '').toString().trim();
      description = (phpDetails['description'] ?? '').toString().trim();
      poster = (phpDetails['poster'] ?? '').toString().trim();
      rawPoster = (phpDetails['raw_poster'] ?? '').toString().trim();
      releaseDate = (phpDetails['release_date'] ?? '').toString().trim();
      if (phpDetails['play_links'] is List) {
        playLinks = List<dynamic>.from(phpDetails['play_links']);
      }
    }

    // If backend already returned play links with Server 1 (Pixeldrain) or Vidara, use them directly
    if (playLinks.isNotEmpty) {
      return {
        'title': title,
        'description': description.isNotEmpty ? description : "Watch $title online in HD.",
        'poster': poster.isNotEmpty ? poster : rawPoster,
        'raw_poster': rawPoster,
        'release_date': releaseDate,
        'stream_url': playLinks.first['url'] ?? '',
        'play_links': playLinks,
        'page_url': pageUrl,
      };
    }

    // Otherwise, fetch HTML to resolve on-device
    try {
      final html = await _fetchHtml(pageUrl.trim());
      if (html.isEmpty) return phpDetails ?? {};

      if (title.isEmpty) {
        final h1Match = RegExp(r'<h1[^>]*>(.*?)</h1>', caseSensitive: false, dotAll: true).firstMatch(html);
        if (h1Match != null) {
          title = h1Match.group(1)!.replaceAll(RegExp(r'<[^>]+>'), '').trim();
        } else {
          final tMatch = RegExp(r'<title>\s*(.*?)\s*</title>', caseSensitive: false).firstMatch(html);
          if (tMatch != null) {
            title = tMatch.group(1)!.replaceAll(RegExp(r' - TellyHD|TellyHD', caseSensitive: false), '').trim();
          }
        }
        title = _decodeHtmlEntities(title);
      }

      if (poster.isEmpty && rawPoster.isEmpty) {
        final pMatch = RegExp(r'''<meta\s+property=["\x27]og:image["\x27]\s+content=["\x27]([^"\x27]+)["\x27]''', caseSensitive: false).firstMatch(html) ??
            RegExp(r'''<div class=["\x27]poster["\x27]>\s*<img[^>]+src=["\x27]([^"\x27]+)["\x27]''', caseSensitive: false).firstMatch(html);
        if (pMatch != null) {
          rawPoster = pMatch.group(1)!;
          poster = rawPoster;
        }
      }

      if (releaseDate.isEmpty) {
        final dMatch = RegExp(r'''<meta\s+property=["\x27]article:published_time["\x27]\s+content=["\x27]([^"\x27]+)["\x27]''', caseSensitive: false).firstMatch(html);
        if (dMatch != null) {
          releaseDate = dMatch.group(1)!.split('T').first;
        } else {
          final yearMatch = RegExp(r'\((\d{4})\)').firstMatch(title);
          if (yearMatch != null) releaseDate = '${yearMatch.group(1)!}-01-01';
        }
      }

      // Check for dotelly.cfd intermediate protector link
      String candidateHtml = html;
      final dotellyMatch = RegExp(r'''https?://dotelly\.cfd/[^\s"'\x3c\x3e]+''', caseSensitive: false).firstMatch(html);
      if (dotellyMatch != null) {
        final dotellyUrl = dotellyMatch.group(0)!;
        final dotellyHtml = await _fetchHtml(dotellyUrl, referer: pageUrl);
        if (dotellyHtml.isNotEmpty) {
          candidateHtml += '\n$dotellyHtml';
        }
      }

      // Extract candidates
      String pixeldrainUrl = '';
      String vidaraUrl = '';
      String cdntellyUrl = '';
      String filemoonUrl = '';

      final pdMatch = RegExp(r'''https?://pixeldrain\.com/u/([a-zA-Z0-9]+)''', caseSensitive: false).firstMatch(candidateHtml);
      if (pdMatch != null) {
        pixeldrainUrl = 'https://pixeldrain.com/api/file/${pdMatch.group(1)!}';
      }

      final vMatch = RegExp(r'''https?://(?:vidara\.to|merivo\.to)/v/([a-zA-Z0-9]+)''', caseSensitive: false).firstMatch(candidateHtml) ??
          RegExp(r'''https?://mxzhxco8dft\.com/e/([a-zA-Z0-9]+)''', caseSensitive: false).firstMatch(candidateHtml);
      if (vMatch != null) {
        vidaraUrl = vMatch.group(0)!;
      }

      final cMatch = RegExp(r'''https?://cdntelly\.sbs/(?:[dv]/)?([a-zA-Z0-9]+)''', caseSensitive: false).firstMatch(candidateHtml);
      if (cMatch != null) {
        cdntellyUrl = cMatch.group(0)!;
      }

      final fMatch = RegExp(r'''https?://(?:filemoon\.(?:to|sx)|bysezoxexe\.com)/(?:[dv]/)?([a-zA-Z0-9]+)''', caseSensitive: false).firstMatch(candidateHtml);
      if (fMatch != null) {
        filemoonUrl = fMatch.group(0)!;
      }

      final resultLinks = <Map<String, dynamic>>[];
      int sNum = 1;

      // Server 1: Pixeldrain direct stream & download link (Primary)
      if (pixeldrainUrl.isNotEmpty) {
        resultLinks.add({
          'name': 'Server $sNum',
          'quality': '720p',
          'url': pixeldrainUrl,
          'resolved_url': pixeldrainUrl,
          'type': 'MP4/MKV Direct Link',
        });
        sNum++;
      }

      // Server 2: Vidara stream
      if (vidaraUrl.isNotEmpty) {
        resultLinks.add({
          'name': 'Server $sNum',
          'quality': '720p',
          'url': vidaraUrl,
          'resolved_url': vidaraUrl,
          'type': 'Vidara Stream',
        });
        sNum++;
      }

      // Server 3: Cdntelly LuluStream mirror
      if (cdntellyUrl.isNotEmpty) {
        String? resolvedLulu;
        try {
          resolvedLulu = await LuluvdoResolver.resolveOnDevice(cdntellyUrl);
        } catch (_) {}
        resultLinks.add({
          'name': 'Server $sNum',
          'quality': '720p',
          'url': cdntellyUrl,
          'resolved_url': (resolvedLulu != null && resolvedLulu.isNotEmpty) ? resolvedLulu : cdntellyUrl,
          'type': (resolvedLulu != null && resolvedLulu.isNotEmpty) ? 'HLS/M3U8 Stream' : 'Luluvdo Stream',
        });
        sNum++;
      }

      // Server 4: Filemoon
      if (filemoonUrl.isNotEmpty) {
        String? resolvedFm;
        try {
          resolvedFm = await FilemoonResolver.resolveStream(filemoonUrl);
        } catch (_) {}
        resultLinks.add({
          'name': 'Server $sNum',
          'quality': '1080p',
          'url': filemoonUrl,
          'resolved_url': (resolvedFm != null && resolvedFm.isNotEmpty) ? resolvedFm : filemoonUrl,
          'type': (resolvedFm != null && resolvedFm.isNotEmpty) ? 'HLS/M3U8 Stream' : 'Filemoon Stream',
        });
        sNum++;
      }

      return {
        'title': title,
        'description': description.isNotEmpty ? description : "Watch $title online in HD.",
        'poster': poster.isNotEmpty ? poster : rawPoster,
        'raw_poster': rawPoster,
        'release_date': releaseDate,
        'stream_url': resultLinks.isNotEmpty ? resultLinks.first['url'] : '',
        'play_links': resultLinks,
        'page_url': pageUrl,
      };
    } catch (e) {
      developer.log("Error extracting TellyHD details: $e");
    }

    return phpDetails ?? {};
  }
}
