import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// An item returned from a Filmywap search or category listing.
class FilmywapItem {
  final String title;
  final String pageUrl;
  final String poster;

  FilmywapItem({
    required this.title,
    required this.pageUrl,
    required this.poster,
  });
}

/// An episode or file quality variant extracted from a Filmywap series / movie page.
class FilmywapEpisodeItem {
  final String title;
  final String pageUrl;
  final String poster;
  final int epNum;
  final String quality;

  FilmywapEpisodeItem({
    required this.title,
    required this.pageUrl,
    required this.poster,
    required this.epNum,
    this.quality = '720p',
  });
}

/// Details including direct playable CDN stream URL and poster.
class FilmywapDetails {
  final String? streamUrl;
  final String? poster;
  final String? title;

  FilmywapDetails({
    this.streamUrl,
    this.poster,
    this.title,
  });
}

class FilmywapScraper {
  static const String defaultBase = 'https://www.filmywap.wtf';

  static final Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
  };

  /// Clean HTML tags and entities from raw string
  static String _cleanHtml(String str) {
    return str
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#038;', '&')
        .replaceAll('&#8211;', '-')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Search Filmywap catalog across updates and key category listings
  static Future<List<FilmywapItem>> search(String query, {String customBase = ''}) async {
    final q = query.trim().toLowerCase();
    final base = (customBase.isNotEmpty && customBase.startsWith('http'))
        ? (customBase.endsWith('/') ? customBase.substring(0, customBase.length - 1) : customBase)
        : defaultBase;

    final results = <FilmywapItem>[];
    final seen = <String>{};

    final pagesToScrape = [
      '$base/updates/1.html',
      '$base/updates/2.html',
      '$base/updates/3.html',
      '$base/category/indian-hot-short-film.html',
      '$base/category/2026-latest-web-series.html',
      '$base/category/2025-latest-web-series.html',
      '$base/category/2026-latest-bollywood-movies.html',
      '$base/category/2025-latest-bollywood-movies.html',
      '$base/category/south-indian-hindi-dubbed-movies.html',
    ];

    final queryWords = q.split(RegExp(r'\s+')).where((w) => w.length > 1).toList();

    for (final pageUrl in pagesToScrape) {
      try {
        final res = await http.get(Uri.parse(pageUrl), headers: {
          ..._headers,
          'Referer': '$base/',
        }).timeout(const Duration(seconds: 7));

        if (res.statusCode != 200) continue;
        final html = res.body;

        // Parse items from <div class="update">...</div>
        final updateReg = RegExp(r'<div class="update"[^>]*>([\s\S]*?)</div>', caseSensitive: false);
        for (final m in updateReg.allMatches(html)) {
          final block = m.group(1) ?? '';

          final linkM = RegExp(r'<a[^>]+href=["\x27]([^"\x27]+)["\x27]', caseSensitive: false).firstMatch(block);
          if (linkM == null) continue;
          var itemUrl = linkM.group(1)!.trim();
          if (!itemUrl.startsWith('http')) {
            itemUrl = '$base/${itemUrl.replaceAll(RegExp(r'^/+'), '')}';
          }

          if (seen.contains(itemUrl) || itemUrl.contains('/category/') || itemUrl.contains('/services/')) {
            continue;
          }

          var poster = '';
          final imgM = RegExp(r'<img[^>]+src=["\x27]([^"\x27]+)["\x27]', caseSensitive: false).firstMatch(block);
          if (imgM != null) {
            poster = imgM.group(1)!.trim();
            if (!poster.startsWith('http')) {
              poster = '$base/${poster.replaceAll(RegExp(r'^/+'), '')}';
            }
          }

          var title = '';
          final altM = RegExp(r'alt=["\x27]([^"\x27]+)["\x27]', caseSensitive: false).firstMatch(block);
          if (altM != null && altM.group(1)!.trim().isNotEmpty) {
            title = _cleanHtml(altM.group(1)!);
          } else {
            title = _cleanHtml(block);
          }

          if (title.isEmpty) continue;

          // Filter by search query
          if (q.isNotEmpty) {
            final titleLower = title.toLowerCase();
            final urlLower = itemUrl.toLowerCase();
            bool matches = false;
            if (titleLower.contains(q) || urlLower.contains(q)) {
              matches = true;
            } else if (queryWords.isNotEmpty && queryWords.every((w) => titleLower.contains(w) || urlLower.contains(w))) {
              matches = true;
            }
            if (!matches) continue;
          }

          seen.add(itemUrl);
          results.add(FilmywapItem(
            title: title,
            pageUrl: itemUrl,
            poster: poster,
          ));
        }

        // Also check any direct movie links on page
        final aReg = RegExp(r'<a[^>]+href=["\x27]([^"\x27]+\.html)["\x27][^>]*>([\s\S]*?)</a>', caseSensitive: false);
        for (final m in aReg.allMatches(html)) {
          var href = m.group(1)!.trim();
          if (href.contains('/category/') || href.contains('/services/') || href.contains('/updates/')) continue;
          if (!href.startsWith('http')) {
            href = '$base/${href.replaceAll(RegExp(r'^/+'), '')}';
          }
          if (seen.contains(href)) continue;

          final rawText = _cleanHtml(m.group(2) ?? '');
          if (rawText.isEmpty || rawText.toLowerCase().contains('disclaimer') || rawText.toLowerCase().contains('back to home')) continue;

          if (q.isNotEmpty) {
            final lower = rawText.toLowerCase();
            if (!lower.contains(q) && !(queryWords.isNotEmpty && queryWords.every((w) => lower.contains(w)))) {
              continue;
            }
          }

          seen.add(href);
          results.add(FilmywapItem(
            title: rawText,
            pageUrl: href,
            poster: '',
          ));
        }
      } catch (e) {
        debugPrint("Filmywap search error on $pageUrl: $e");
      }
    }

    return results;
  }

  /// Parse episode number from string or URL
  static int _parseEpNumber(String text, String url, int fallback) {
    final lower = '$text $url'.toLowerCase();

    // S01EP02 / EP02 / E02
    final epMatch = RegExp(r'(?:ep|episode|e)[_\-\s]*(\d+)', caseSensitive: false).firstMatch(lower);
    if (epMatch != null) {
      final n = int.tryParse(epMatch.group(1)!);
      if (n != null && n > 0 && n < 500) return n;
    }

    // Part 2 / Pt 2
    final ptMatch = RegExp(r'(?:part|pt)[_\-\s]*(\d+)', caseSensitive: false).firstMatch(lower);
    if (ptMatch != null) {
      final n = int.tryParse(ptMatch.group(1)!);
      if (n != null && n > 0 && n < 500) return n;
    }

    return fallback;
  }

  /// Fetch all episode files / quality files from a series or movie page on Filmywap
  static Future<List<FilmywapEpisodeItem>> fetchSeriesEpisodes(String pageUrl, {String customBase = ''}) async {
    final base = (customBase.isNotEmpty && customBase.startsWith('http'))
        ? (customBase.endsWith('/') ? customBase.substring(0, customBase.length - 1) : customBase)
        : defaultBase;

    final episodes = <FilmywapEpisodeItem>[];
    final seen = <String>{};

    try {
      final res = await http.get(Uri.parse(pageUrl), headers: {
        ..._headers,
        'Referer': '$base/',
      }).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return [];
      final html = res.body;

      // Extract main poster if present
      String mainPoster = '';
      final posterM = RegExp(r'<img[^>]+src=["\x27]([^"\x27]*?/files/images/[^"\x27]*?)["\x27]', caseSensitive: false).firstMatch(html);
      if (posterM != null) {
        mainPoster = posterM.group(1)!.trim();
        if (!mainPoster.startsWith('http')) {
          mainPoster = '$base/${mainPoster.replaceAll(RegExp(r'^/+'), '')}';
        }
      }

      // Step 1: Match file links: /file/...-mp4.html
      final fileLinkReg = RegExp(
        r'<a[^>]+href=["\x27]([^"\x27]*?/file/[^"\x27]*?)["\x27][^>]*>([\s\S]*?)</a>',
        caseSensitive: false,
      );

      int epCounter = 1;
      for (final m in fileLinkReg.allMatches(html)) {
        var fileUrl = m.group(1)!.trim();
        if (!fileUrl.startsWith('http')) {
          fileUrl = '$base/${fileUrl.replaceAll(RegExp(r'^/+'), '')}';
        }

        if (seen.contains(fileUrl)) continue;
        seen.add(fileUrl);

        final rawTitle = _cleanHtml(m.group(2) ?? '');
        final title = rawTitle.isNotEmpty ? rawTitle : 'Episode $epCounter';

        String quality = '720p';
        if (title.contains('1080p') || fileUrl.contains('1080p')) {
          quality = '1080p';
        } else if (title.contains('480p') || fileUrl.contains('480p')) {
          quality = '480p';
        } else if (title.contains('720p') || fileUrl.contains('720p')) {
          quality = '720p';
        }

        final parsedNum = _parseEpNumber(title, fileUrl, epCounter);

        episodes.add(FilmywapEpisodeItem(
          title: title,
          pageUrl: fileUrl,
          poster: mainPoster,
          epNum: parsedNum,
          quality: quality,
        ));
        epCounter++;
      }

      // Step 2: If no /file/ links, check for direct /view/ links
      if (episodes.isEmpty) {
        final viewLinkReg = RegExp(
          r'<a[^>]+href=["\x27]([^"\x27]*?/view/[^"\x27]*?)["\x27][^>]*>([\s\S]*?)</a>',
          caseSensitive: false,
        );

        epCounter = 1;
        for (final m in viewLinkReg.allMatches(html)) {
          var viewUrl = m.group(1)!.trim();
          if (!viewUrl.startsWith('http')) {
            viewUrl = '$base/${viewUrl.replaceAll(RegExp(r'^/+'), '')}';
          }

          if (seen.contains(viewUrl)) continue;
          seen.add(viewUrl);

          final title = _cleanHtml(m.group(2) ?? '');
          final parsedNum = _parseEpNumber(title, viewUrl, epCounter);

          episodes.add(FilmywapEpisodeItem(
            title: title.isNotEmpty ? title : 'Episode $epCounter',
            pageUrl: viewUrl,
            poster: mainPoster,
            epNum: parsedNum,
            quality: '720p',
          ));
          epCounter++;
        }
      }
    } catch (e) {
      debugPrint("Filmywap fetchSeriesEpisodes error: $e");
    }

    return episodes;
  }

  /// Full 3-step pipeline to extract direct playable CDN stream link:
  /// 1. If pageUrl is movie/series page -> finds file/view link.
  /// 2. If pageUrl is /file/ -> finds /view/{id}.html link.
  /// 3. On /view/{id}.html -> extracts /download/{id}/{srv} -> follows HTTP 302 -> returns high-speed CDN MP4 stream!
  static Future<FilmywapDetails?> fetchEpisodeDetails(String pageUrl, {String customBase = ''}) async {
    final cleanUrl = pageUrl.trim();
    if (cleanUrl.isEmpty) return null;

    final base = (customBase.isNotEmpty && customBase.startsWith('http'))
        ? (customBase.endsWith('/') ? customBase.substring(0, customBase.length - 1) : customBase)
        : defaultBase;

    try {
      String viewUrl = cleanUrl;
      String? mainPoster;
      String? parsedTitle;

      // ── Step 1: Resolve view URL ──
      if (cleanUrl.contains('/view/')) {
        viewUrl = cleanUrl;
      } else if (cleanUrl.contains('/file/')) {
        final fRes = await http.get(Uri.parse(cleanUrl), headers: {
          ..._headers,
          'Referer': '$base/',
        }).timeout(const Duration(seconds: 10));

        if (fRes.statusCode == 200) {
          final fHtml = fRes.body;
          final vMatch = RegExp(r'href=["\x27]([^"\x27]*?/view/[^"\x27]*?)["\x27]', caseSensitive: false).firstMatch(fHtml);
          if (vMatch != null) {
            var v = vMatch.group(1)!.trim();
            if (!v.startsWith('http')) v = '$base/${v.replaceAll(RegExp(r'^/+'), '')}';
            viewUrl = v;
          }

          final pMatch = RegExp(r'<img[^>]+src=["\x27]([^"\x27]*?/files/images/[^"\x27]*?)["\x27]', caseSensitive: false).firstMatch(fHtml);
          if (pMatch != null) {
            var p = pMatch.group(1)!.trim();
            if (!p.startsWith('http')) p = '$base/${p.replaceAll(RegExp(r'^/+'), '')}';
            mainPoster = p;
          }
        }
      } else {
        // Assume Movie / Series page
        final mRes = await http.get(Uri.parse(cleanUrl), headers: {
          ..._headers,
          'Referer': '$base/',
        }).timeout(const Duration(seconds: 10));

        if (mRes.statusCode == 200) {
          final mHtml = mRes.body;

          // Poster
          final pMatch = RegExp(r'<img[^>]+src=["\x27]([^"\x27]*?/files/images/[^"\x27]*?)["\x27]', caseSensitive: false).firstMatch(mHtml);
          if (pMatch != null) {
            var p = pMatch.group(1)!.trim();
            if (!p.startsWith('http')) p = '$base/${p.replaceAll(RegExp(r'^/+'), '')}';
            mainPoster = p;
          }

          // First check for /file/ links
          final flMatch = RegExp(r'href=["\x27]([^"\x27]*?/file/[^"\x27]*?)["\x27]', caseSensitive: false).firstMatch(mHtml);
          if (flMatch != null) {
            var fl = flMatch.group(1)!.trim();
            if (!fl.startsWith('http')) fl = '$base/${fl.replaceAll(RegExp(r'^/+'), '')}';

            // Fetch file page to get view link
            final fRes = await http.get(Uri.parse(fl), headers: {
              ..._headers,
              'Referer': cleanUrl,
            }).timeout(const Duration(seconds: 10));

            if (fRes.statusCode == 200) {
              final vMatch = RegExp(r'href=["\x27]([^"\x27]*?/view/[^"\x27]*?)["\x27]', caseSensitive: false).firstMatch(fRes.body);
              if (vMatch != null) {
                var v = vMatch.group(1)!.trim();
                if (!v.startsWith('http')) v = '$base/${v.replaceAll(RegExp(r'^/+'), '')}';
                viewUrl = v;
              }
            }
          } else {
            // Direct /view/ link check
            final vMatch = RegExp(r'href=["\x27]([^"\x27]*?/view/[^"\x27]*?)["\x27]', caseSensitive: false).firstMatch(mHtml);
            if (vMatch != null) {
              var v = vMatch.group(1)!.trim();
              if (!v.startsWith('http')) v = '$base/${v.replaceAll(RegExp(r'^/+'), '')}';
              viewUrl = v;
            }
          }
        }
      }

      // ── Step 2: Fetch view page & extract download URL ──
      final vRes = await http.get(Uri.parse(viewUrl), headers: {
        ..._headers,
        'Referer': cleanUrl,
      }).timeout(const Duration(seconds: 10));

      if (vRes.statusCode != 200) return null;
      final vHtml = vRes.body;

      // Title
      final titleMatch = RegExp(r'<title>([\s\S]*?)</title>', caseSensitive: false).firstMatch(vHtml);
      if (titleMatch != null) {
        parsedTitle = _cleanHtml(titleMatch.group(1)!);
      }

      // Poster fallback
      if (mainPoster == null || mainPoster.isEmpty) {
        final pMatch = RegExp(r'<img[^>]+src=["\x27]([^"\x27]*?/files/images/[^"\x27]*?)["\x27]', caseSensitive: false).firstMatch(vHtml);
        if (pMatch != null) {
          var p = pMatch.group(1)!.trim();
          if (!p.startsWith('http')) p = '$base/${p.replaceAll(RegExp(r'^/+'), '')}';
          mainPoster = p;
        }
      }

      // Find download URL: /download/{id} or /download/{id}/{srv}
      final dlMatch = RegExp(r'href=["\x27]([^"\x27]*?/download/[^"\x27]*?)["\x27]', caseSensitive: false).firstMatch(vHtml);
      if (dlMatch == null) {
        return FilmywapDetails(
          streamUrl: null,
          poster: mainPoster,
          title: parsedTitle,
        );
      }

      var dlUrl = dlMatch.group(1)!.trim();
      if (!dlUrl.startsWith('http')) {
        dlUrl = '$base/${dlUrl.replaceAll(RegExp(r'^/+'), '')}';
      }

      // ── Step 3: Follow redirect to obtain direct high-speed CDN stream URL ──
      final client = HttpClient()..badCertificateCallback = (cert, host, port) => true;
      final req = await client.getUrl(Uri.parse(dlUrl)).timeout(const Duration(seconds: 10));
      req.followRedirects = false;
      req.headers.set('User-Agent', _headers['User-Agent']!);
      req.headers.set('Referer', viewUrl);
      req.headers.set('Accept', '*/*');

      final resp = await req.close();
      String? streamUrl;

      if (resp.statusCode == 301 || resp.statusCode == 302 || resp.statusCode == 307 || resp.statusCode == 308) {
        streamUrl = resp.headers.value(HttpHeaders.locationHeader);
      }

      client.close();

      if (streamUrl != null && streamUrl.isNotEmpty) {
        if (streamUrl.contains(' ')) {
          streamUrl = streamUrl.replaceAll(' ', '%20');
        }
        return FilmywapDetails(
          streamUrl: streamUrl,
          poster: mainPoster,
          title: parsedTitle,
        );
      }

      return FilmywapDetails(
        streamUrl: null,
        poster: mainPoster,
        title: parsedTitle,
      );
    } catch (e) {
      debugPrint("Filmywap fetchEpisodeDetails error: $e");
      return null;
    }
  }
}
