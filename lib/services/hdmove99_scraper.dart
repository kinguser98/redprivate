import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

class Hdmove99Scraper {
  /// Resolves an uplinks24.com view URL to its protected source links
  static Future<List<String>> resolveUplinks24(String viewUrl) async {
    try {
      final client = HttpClient()..badCertificateCallback = (c, h, p) => true;
      client.connectionTimeout = const Duration(seconds: 10);
      final uri = Uri.parse(viewUrl.trim());
      final code = uri.pathSegments.where((s) => s.isNotEmpty).last;

      // 1. GET view page to obtain CSRF token & session cookies
      final getReq = await client.getUrl(uri);
      getReq.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
      getReq.headers.set('Referer', 'https://hdmove99.com/');
      final getResp = await getReq.close();
      final cookies = <Cookie>[];
      cookies.addAll(getResp.cookies);
      final html1 = await utf8.decodeStream(getResp);

      final fieldMatch = RegExp(r'name=[\x22\x27](_csrf_token_[^\x22\x27]+)[\x22\x27]').firstMatch(html1);
      final valMatch = RegExp(r'value=[\x22\x27]([a-f0-9]{32,40})[\x22\x27]').firstMatch(html1);

      if (fieldMatch != null && valMatch != null) {
        final field = fieldMatch.group(1)!;
        final val = valMatch.group(1)!;

        // 2. POST CSRF token to activate link generation
        final postReq = await client.postUrl(uri);
        postReq.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
        postReq.headers.set('Referer', viewUrl);
        postReq.headers.set('Content-Type', 'application/x-www-form-urlencoded');
        postReq.cookies.addAll(cookies);
        final bodyBytes = utf8.encode('$field=$val');
        postReq.contentLength = bodyBytes.length;
        postReq.add(bodyBytes);
        final postResp = await postReq.close();
        cookies.addAll(postResp.cookies);
        await postResp.drain();

        // 3. GET /save/$code to read destination URLs
        final saveUri = Uri.parse('https://uplinks24.com/save/$code');
        final saveReq = await client.getUrl(saveUri);
        saveReq.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
        saveReq.headers.set('Referer', viewUrl);
        saveReq.cookies.addAll(cookies);
        final saveResp = await saveReq.close();
        final html3 = await utf8.decodeStream(saveResp);
        client.close();

        final results = <String>[];
        for (final line in html3.split('\n')) {
          final l = line.trim();
          if (l.startsWith('http') && !l.endsWith('.jpg') && !l.endsWith('.png')) {
            results.add(l);
          }
        }
        return results;
      }
      client.close();
    } catch (e) {
      developer.log("Error resolving uplinks24 ($viewUrl): $e");
    }
    return [];
  }

  /// Resolves an uplinks24.com view URL to its screenshot image links
  static Future<List<String>> resolveUplinks24Screenshots(String viewUrl) async {
    try {
      final client = HttpClient()..badCertificateCallback = (c, h, p) => true;
      client.connectionTimeout = const Duration(seconds: 10);
      final uri = Uri.parse(viewUrl.trim());
      final code = uri.pathSegments.where((s) => s.isNotEmpty).last;

      final getReq = await client.getUrl(uri);
      getReq.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
      getReq.headers.set('Referer', 'https://hdmove99.com/');
      final getResp = await getReq.close();
      final cookies = <Cookie>[];
      cookies.addAll(getResp.cookies);
      final html1 = await utf8.decodeStream(getResp);

      final fieldMatch = RegExp(r'name=[\x22\x27](_csrf_token_[^\x22\x27]+)[\x22\x27]').firstMatch(html1);
      final valMatch = RegExp(r'value=[\x22\x27]([a-f0-9]{32,40})[\x22\x27]').firstMatch(html1);

      if (fieldMatch != null && valMatch != null) {
        final field = fieldMatch.group(1)!;
        final val = valMatch.group(1)!;

        final postReq = await client.postUrl(uri);
        postReq.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
        postReq.headers.set('Referer', viewUrl);
        postReq.headers.set('Content-Type', 'application/x-www-form-urlencoded');
        postReq.cookies.addAll(cookies);
        final bodyBytes = utf8.encode('$field=$val');
        postReq.contentLength = bodyBytes.length;
        postReq.add(bodyBytes);
        final postResp = await postReq.close();
        cookies.addAll(postResp.cookies);
        await postResp.drain();

        final saveUri = Uri.parse('https://uplinks24.com/save/$code');
        final saveReq = await client.getUrl(saveUri);
        saveReq.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
        saveReq.headers.set('Referer', viewUrl);
        saveReq.cookies.addAll(cookies);
        final saveResp = await saveReq.close();
        final html3 = await utf8.decodeStream(saveResp);
        client.close();

        final results = <String>[];
        for (final line in html3.split('\n')) {
          final l = line.trim();
          if (l.startsWith('http')) {
            final low = l.toLowerCase();
            if (low.endsWith('.jpg') ||
                low.endsWith('.jpeg') ||
                low.endsWith('.png') ||
                low.endsWith('.webp') ||
                low.contains('imgup') ||
                low.contains('image') ||
                low.contains('pixhost') ||
                low.contains('postimg') ||
                low.contains('blogger')) {
              results.add(l);
            }
          }
        }
        return results;
      }
      client.close();
    } catch (e) {
      developer.log("Error resolving uplinks24 screenshot ($viewUrl): $e");
    }
    return [];
  }

  /// Extracts screenshot images from an HDMove99 post
  static Future<List<String>> fetchScreenshots(String pageUrl) async {
    final screenshots = <String>[];
    try {
      final client = HttpClient()..badCertificateCallback = (c, h, p) => true;
      client.connectionTimeout = const Duration(seconds: 10);
      final req = await client.getUrl(Uri.parse(pageUrl.trim()));
      req.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
      final resp = await req.close();
      final html = await utf8.decodeStream(resp);
      client.close();

      // 1. Look for explicit screenshot links
      final shotCodes = <String>{};
      final linkMatches = RegExp(
        r'''<a[^>]+href=[\x22\x27]https?://uplinks24\.com/view/([a-zA-Z0-9]+)[\x22\x27][^>]*>(.*?)</a>''',
        caseSensitive: false,
        dotAll: true,
      ).allMatches(html);

      for (final m in linkMatches) {
        final code = m.group(1)!;
        final text = m.group(2)!.toLowerCase();
        if (text.contains('screen') || text.contains('shot')) {
          shotCodes.add(code);
        }
      }

      // If no link explicitly said screen, check all uplinks codes on page
      if (shotCodes.isEmpty) {
        final allCodes = RegExp(r'uplinks24\.com/view/([a-zA-Z0-9]+)', caseSensitive: false).allMatches(html);
        for (final m in allCodes) {
          shotCodes.add(m.group(1)!);
        }
      }

      for (final code in shotCodes) {
        final shots = await resolveUplinks24Screenshots("https://uplinks24.com/view/$code");
        for (final s in shots) {
          if (!screenshots.contains(s)) screenshots.add(s);
        }
      }

      // If uplinks24 returned screenshots, this is the single merged screenshot sheet!
      if (screenshots.isNotEmpty) {
        return screenshots;
      }

      // 2. Fallback: check only inside the article / post body for screenshot hosts (imgup, imagetwist, pixhost)
      final mainMatch = RegExp(r'<main[^>]*>(.*?)</main>', caseSensitive: false, dotAll: true).firstMatch(html)
          ?? RegExp(r'<article[^>]*>(.*?)</article>', caseSensitive: false, dotAll: true).firstMatch(html);
      final searchArea = mainMatch?.group(1) ?? html;

      final imgMatches = RegExp(r'''<img[^>]+src=[\x22\x27]([^\x22\x27]+)[\x22\x27]''', caseSensitive: false).allMatches(searchArea);
      for (final m in imgMatches) {
        final src = m.group(1)!.trim();
        final low = src.toLowerCase();
        if (src.startsWith('http') &&
            !low.contains('logo') &&
            !low.contains('icon') &&
            !low.contains('avatar') &&
            !low.contains('ads') &&
            !screenshots.contains(src)) {
          if (low.contains('imgup') || low.contains('imagetwist') || low.contains('pixhost') || low.contains('postimg')) {
            screenshots.add(src);
          }
        }
      }
    } catch (e) {
      developer.log("Error fetching HDMove99 screenshots: $e");
    }
    return screenshots;
  }

  /// Extracts HDMove99 post details with Server 1 (Vidara) and Server 2 (Luluvideo)
  static Future<Map<String, dynamic>> extractHdmove99Details(
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

    // Check if we already have both Server 1 Vidara and Server 2 Luluvdo from backend
    bool hasVidara = playLinks.any((pl) => (pl['url'] ?? '').toString().contains('vidara') || (pl['type'] ?? '').toString().contains('Vidara'));
    bool hasLulu = playLinks.any((pl) => (pl['url'] ?? '').toString().contains('lulu') || (pl['type'] ?? '').toString().contains('Lulu'));

    if (hasVidara && hasLulu) {
      // Re-order to guarantee Server 1 is Vidara and Server 2 is Luluvideo
      final vidaraLink = playLinks.firstWhere(
        (pl) => (pl['url'] ?? '').toString().contains('vidara') || (pl['type'] ?? '').toString().contains('Vidara'),
      );
      final luluLink = playLinks.firstWhere(
        (pl) => (pl['url'] ?? '').toString().contains('lulu') || (pl['type'] ?? '').toString().contains('Lulu'),
      );
      final others = playLinks.where((pl) => pl != vidaraLink && pl != luluLink).toList();

      final reordered = <Map<String, dynamic>>[
        {
          'name': 'Server 1',
          'quality': '720p',
          'url': (vidaraLink['url'] ?? '').toString().trim(),
          'resolved_url': (vidaraLink['resolved_url'] ?? vidaraLink['url'] ?? '').toString().trim(),
          'type': 'Vidara Stream',
        },
        {
          'name': 'Server 2',
          'quality': '720p',
          'url': (luluLink['url'] ?? '').toString().trim(),
          'resolved_url': (luluLink['resolved_url'] ?? luluLink['url'] ?? '').toString().trim(),
          'type': 'Luluvdo Stream',
        },
      ];
      for (int i = 0; i < others.length; i++) {
        final o = others[i];
        reordered.add({
          'name': 'Server ${i + 3}',
          'quality': o['quality'] ?? '720p',
          'url': (o['url'] ?? '').toString().trim(),
          'resolved_url': (o['resolved_url'] ?? o['url'] ?? '').toString().trim(),
          'type': o['type'] ?? 'Streamtape Stream',
        });
      }

      return {
        'title': title,
        'description': description.isNotEmpty ? description : "Watch $title online in HD.",
        'poster': poster.isNotEmpty ? poster : rawPoster,
        'raw_poster': rawPoster,
        'release_date': releaseDate,
        'stream_url': reordered.first['url'],
        'play_links': reordered,
        'page_url': pageUrl,
      };
    }

    // Otherwise, fetch HTML to resolve on-device or enrich missing servers
    try {
      final client = HttpClient()..badCertificateCallback = (c, h, p) => true;
      client.connectionTimeout = const Duration(seconds: 10);
      final req = await client.getUrl(Uri.parse(pageUrl.trim()));
      req.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
      final resp = await req.close();
      final html = await utf8.decodeStream(resp);
      client.close();

      if (title.isEmpty) {
        final tMatch = RegExp(r'<title>\s*(.*?)\s*<\/title>', caseSensitive: false).firstMatch(html);
        if (tMatch != null) {
          title = tMatch.group(1)!.replaceAll(RegExp(r' - HDmovie99\.Com| - HDMove99|HDmovie99|HDMove99', caseSensitive: false), '').trim();
        }
      }
      if (poster.isEmpty && rawPoster.isEmpty) {
        final pMatch = RegExp(r'''<meta\s+property=[\x22\x27]og:image[\x22\x27]\s+content=[\x22\x27]([^\x22\x27]+)[\x22\x27]''', caseSensitive: false).firstMatch(html);
        if (pMatch != null) {
          rawPoster = pMatch.group(1)!;
          poster = rawPoster;
        }
      }

      // Collect raw links from all uplinks24 codes on the page
      final allRaw = <String>[];
      final uMatches = RegExp(r'uplinks24\.com\/view\/([a-zA-Z0-9]+)', caseSensitive: false).allMatches(html);
      final codes = <String>{};
      for (final m in uMatches) {
        codes.add(m.group(1)!);
      }

      for (final code in codes) {
        final uUrls = await resolveUplinks24("https://uplinks24.com/view/$code");
        for (final u in uUrls) {
          if (!allRaw.contains(u)) allRaw.add(u);
        }
      }

      // Also check hrefs on page
      final hrefMatches = RegExp(r'''href=[\x22\x27]([^\x22\x27]+)[\x22\x27]''', caseSensitive: false).allMatches(html);
      for (final m in hrefMatches) {
        final href = m.group(1)!.trim();
        if (href.startsWith('http') && !allRaw.contains(href)) {
          final low = href.toLowerCase();
          if (low.contains('vidara') || low.contains('merivo') || low.contains('lulu') || low.contains('streamtape')) {
            allRaw.add(href);
          }
        }
      }

      String vidaraUrl = '';
      String luluUrl = '';
      final otherUrls = <String>[];

      for (final r in allRaw) {
        final low = r.toLowerCase();
        if (vidaraUrl.isEmpty && (low.contains('vidara') || low.contains('merivo') || low.contains('as9u'))) {
          vidaraUrl = r;
        } else if (luluUrl.isEmpty && (low.contains('lulu') || low.contains('tnmr.org'))) {
          luluUrl = r;
        } else if (!otherUrls.contains(r) && (low.contains('streamtape') || low.contains('tpead') || low.contains('.mp4') || low.contains('.m3u8'))) {
          otherUrls.add(r);
        }
      }

      // If backend already had a lulu link and we didn't find one in allRaw, keep it
      if (luluUrl.isEmpty) {
        for (final pl in playLinks) {
          final u = (pl['url'] ?? '').toString();
          if (u.contains('lulu') || u.contains('tnmr.org')) {
            luluUrl = u;
            break;
          }
        }
      }

      final resultLinks = <Map<String, dynamic>>[];
      int sNum = 1;

      // Server 1: Vidara source link (Primary)
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

      // Server 2: Luluvideo link
      if (luluUrl.isNotEmpty) {
        resultLinks.add({
          'name': 'Server $sNum',
          'quality': '720p',
          'url': luluUrl,
          'resolved_url': luluUrl,
          'type': 'Luluvdo Stream',
        });
        sNum++;
      }

      // Fallback servers
      for (final ou in otherUrls) {
        resultLinks.add({
          'name': 'Server $sNum',
          'quality': '720p',
          'url': ou,
          'resolved_url': ou,
          'type': 'Streamtape Stream',
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
      developer.log("Error scraping HDMove99 details: $e");
    }

    return phpDetails ?? {};
  }

  /// Cleans titles of common noise like Season, Episode, quality, codec tags for higher search hit rates
  static String cleanSearchQuery(String raw) {
    String clean = raw
        .replaceAll(RegExp(r'\b(s\d+|season\s*\d+|e\d+|episode\s*\d+|ep\s*\d+)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[.*?\]|\(.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\b(480p|720p|1080p|2160p|4k|hevc|hdrip|web-dl|webrip|uncut|unrated|short\s*film|full\s*movie|hindi|telugu|tamil|bengali)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return clean;
  }

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

  /// Searches HDMove99 catalog client-side via WordPress REST API with HTML fallback
  static Future<List<Map<String, dynamic>>> searchCatalog(String query) async {
    final results = <Map<String, dynamic>>[];
    final cleanQ = cleanSearchQuery(query);
    if (cleanQ.isEmpty && query.trim().isEmpty) return results;

    Future<List<Map<String, dynamic>>> queryWpRest(String q) async {
      try {
        final client = HttpClient()..badCertificateCallback = (c, h, p) => true;
        client.connectionTimeout = const Duration(seconds: 10);
        final uri = Uri.parse('https://hdmove99.com/wp-json/wp/v2/posts?search=${Uri.encodeComponent(q.trim())}&per_page=25');
        final req = await client.getUrl(uri);
        req.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
        req.headers.set('Referer', 'https://hdmove99.com/');
        final resp = await req.close();
        if (resp.statusCode != 200) {
          client.close();
          return [];
        }
        final raw = await utf8.decodeStream(resp);
        client.close();
        final jsonList = jsonDecode(raw);
        if (jsonList is List) {
          final items = <Map<String, dynamic>>[];
          for (final item in jsonList) {
            if (item is Map) {
              final titleObj = item['title'];
              String title = '';
              if (titleObj is Map) {
                title = (titleObj['rendered'] ?? '').toString();
              } else {
                title = (item['title'] ?? '').toString();
              }
              title = _decodeHtmlEntities(title);

              final link = (item['link'] ?? '').toString();
              if (link.isEmpty) continue;

              String poster = '';
              String screenshotViewUrl = '';
              final contentObj = item['content'];
              String content = '';
              if (contentObj is Map) {
                content = (contentObj['rendered'] ?? '').toString();
              }
              if (content.isNotEmpty) {
                final imgM = RegExp(r'''<img[^>]+src=[\x22\x27]([^\x22\x27]+)[\x22\x27]''', caseSensitive: false).firstMatch(content);
                if (imgM != null) {
                  poster = imgM.group(1)!.trim();
                }
                final shotM = RegExp(r'''https?://uplinks24\.com/view/([a-zA-Z0-9]+)''', caseSensitive: false).firstMatch(content);
                if (shotM != null) {
                  screenshotViewUrl = shotM.group(0)!;
                }
              }

              items.add({
                'id': item['id'],
                'title': title.isNotEmpty ? title : 'HDMove99 Content',
                'page_url': link,
                'poster': poster,
                'screenshot_view_url': screenshotViewUrl,
                'date': (item['date'] ?? '').toString(),
              });
            }
          }
          return items;
        }
      } catch (e) {
        developer.log("Error querying HDMove99 WP REST API: $e");
      }
      return [];
    }

    // 1. Try clean query first
    if (cleanQ.isNotEmpty) {
      results.addAll(await queryWpRest(cleanQ));
    }

    // 2. If clean query returned empty and differs from original query, try original
    if (results.isEmpty && query.trim() != cleanQ && query.trim().isNotEmpty) {
      results.addAll(await queryWpRest(query.trim()));
    }

    // 3. If still empty and clean query has multiple words, try first 2 words
    if (results.isEmpty) {
      final words = cleanQ.split(' ').where((w) => w.length > 2).toList();
      if (words.length > 2) {
        final shortQ = words.take(2).join(' ');
        results.addAll(await queryWpRest(shortQ));
      }
    }

    // 4. Fallback to HTML scraper if WP REST API failed or returned 0
    if (results.isEmpty) {
      try {
        final client = HttpClient()..badCertificateCallback = (c, h, p) => true;
        client.connectionTimeout = const Duration(seconds: 10);
        final uri = Uri.parse('https://hdmove99.com/?s=${Uri.encodeComponent((cleanQ.isNotEmpty ? cleanQ : query).trim())}');
        final req = await client.getUrl(uri);
        req.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
        final resp = await req.close();
        final html = await utf8.decodeStream(resp);
        client.close();

        final articleMatches = RegExp(r'<article[^>]*>(.*?)</article>', caseSensitive: false, dotAll: true).allMatches(html);
        for (final a in articleMatches) {
          final aHtml = a.group(1)!;
          final linkMatch = RegExp(r'''href=[\x22\x27](https://hdmove99\.com/[^/\x22\x27]+/)[\x22\x27]''').firstMatch(aHtml);
          final imgMatch = RegExp(r'''<img[^>]+src=[\x22\x27]([^\x22\x27]+)[\x22\x27]''').firstMatch(aHtml);
          final titleMatch = RegExp(r'''<h\d[^>]*>.*?<a[^>]*>(.*?)</a>''', caseSensitive: false, dotAll: true).firstMatch(aHtml)
              ?? RegExp(r'''title=[\x22\x27]([^\x22\x27]+)[\x22\x27]''').firstMatch(aHtml);
          if (linkMatch != null) {
            final url = linkMatch.group(1)!;
            if (url.contains('how-to') || url.contains('about-us') || url.contains('dmca') || url.contains('disclaimer')) continue;
            final poster = imgMatch?.group(1) ?? '';
            final rawTitle = titleMatch?.group(1)?.replaceAll(RegExp(r'<[^>]*>'), '').trim() ?? 'HDMove99 Content';
            results.add({
              'title': _decodeHtmlEntities(rawTitle),
              'page_url': url,
              'poster': poster,
              'date': '',
            });
          }
        }
      } catch (e) {
        developer.log("Error in HTML search fallback: $e");
      }
    }

    return results;
  }
}
