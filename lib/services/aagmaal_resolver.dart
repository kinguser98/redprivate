import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Dynamic resolver for Aagmaal & Uncutmaal streams.
/// Renews temporary Nginx `?md5=...&expires=...` tokens on the fly so movies never expire.
class AagmaalResolver {
  static final Map<String, _CachedStream> _cache = {};

  static bool isAagmaalUrl(String url) {
    if (url.isEmpty) return false;
    final lower = url.toLowerCase();
    return lower.contains('aagmaal.mba') ||
        lower.contains('uncutmaal.org') ||
        lower.contains('aagmaals.org') ||
        lower.contains('9redmovies') ||
        lower.contains('hotbazi') ||
        (lower.contains('.mp4') && lower.contains('expires=') && lower.contains('md5='));
  }

  /// Resolves an Aagmaal or Uncutmaal URL into a valid, playable media stream URL.
  static Future<String?> resolveStream(String rawUrl, {bool forceRefresh = false}) async {
    if (rawUrl.isEmpty) return null;
    final cleanUrl = rawUrl.trim();

    // 1. Check in-memory cache if still valid
    if (!forceRefresh && _cache.containsKey(cleanUrl)) {
      final cached = _cache[cleanUrl]!;
      if (DateTime.now().isBefore(cached.expiresAt)) {
        debugPrint("[AagmaalResolver] Returning valid cached stream URL");
        return cached.streamUrl;
      }
    }

    // 2. If it is already a direct uncutmaal MP4 URL with a future expiry token, verify it
    if (cleanUrl.contains('.mp4') && cleanUrl.contains('expires=')) {
      final expiryMatch = RegExp(r'expires=(\d+)', caseSensitive: false).firstMatch(cleanUrl);
      if (expiryMatch != null) {
        final expSec = int.tryParse(expiryMatch.group(1)!) ?? 0;
        final expDate = DateTime.fromMillisecondsSinceEpoch(expSec * 1000, isUtc: true);
        final nowUtc = DateTime.now().toUtc();

        // If the token is still valid for at least 10 more minutes
        if (expDate.isAfter(nowUtc.add(const Duration(minutes: 10)))) {
          _cache[cleanUrl] = _CachedStream(cleanUrl, expDate.subtract(const Duration(minutes: 5)));
          return cleanUrl;
        }
      }
    }

    // 3. If the URL is an Aagmaal web page, scrape the fresh stream directly from the page
    if (cleanUrl.contains('aagmaal.mba') && !cleanUrl.contains('.mp4')) {
      final fresh = await _scrapeFreshStreamFromPage(cleanUrl);
      if (fresh != null && fresh.isNotEmpty) {
        _cacheStream(cleanUrl, fresh);
        return fresh;
      }
    }

    // 4. If the direct uncutmaal link expired, try to resolve from original filename or download proxy
    final fileMatch = RegExp(r'/(?:files|download-hot-web-series/\?file=)([^?&/]+\.mp4)', caseSensitive: false).firstMatch(cleanUrl);
    if (fileMatch != null) {
      final fileName = fileMatch.group(1)!;
      // Search Aagmaal for this specific video file / post
      final searchTitle = fileName
          .replaceAll(RegExp(r'[-_]', caseSensitive: false), ' ')
          .replaceAll(RegExp(r'\.mp4|AAGmaals\.Org|Hindi|Hot|Short|Film|480p|720p|1080p', caseSensitive: false), '')
          .trim();
      if (searchTitle.isNotEmpty) {
        final fresh = await _searchAndResolveFreshStream(searchTitle, fileName);
        if (fresh != null && fresh.isNotEmpty) {
          _cacheStream(cleanUrl, fresh);
          return fresh;
        }
      }
    }

    // 5. Fallback: Return the rawUrl as-is if no dynamic renewal succeeded
    return cleanUrl;
  }

  static void _cacheStream(String originalUrl, String resolvedStreamUrl) {
    final expiryMatch = RegExp(r'expires=(\d+)', caseSensitive: false).firstMatch(resolvedStreamUrl);
    DateTime expDate = DateTime.now().add(const Duration(hours: 12));
    if (expiryMatch != null) {
      final expSec = int.tryParse(expiryMatch.group(1)!) ?? 0;
      if (expSec > 0) {
        expDate = DateTime.fromMillisecondsSinceEpoch(expSec * 1000, isUtc: true).toLocal();
      }
    }
    _cache[originalUrl] = _CachedStream(resolvedStreamUrl, expDate.subtract(const Duration(minutes: 5)));
  }

  static Future<String?> _scrapeFreshStreamFromPage(String pageUrl) async {
    try {
      final res = await http.get(Uri.parse(pageUrl), headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Referer': 'https://aagmaal.mba/',
      }).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      final html = res.body;

      // Check <source src="...">
      final srcMatch = RegExp(r'<source[^>]+src="([^"]+)"', caseSensitive: false).firstMatch(html);
      if (srcMatch != null) {
        final u = srcMatch.group(1)!.trim();
        if (u.isNotEmpty) return u;
      }

      // Check direct mp4 token
      final mp4Match = RegExp(r'''https?://[^\s<>"']+\.mp4(?:\?[^\s<>"']*)?''', caseSensitive: false).firstMatch(html);
      if (mp4Match != null) {
        return mp4Match.group(0)!.trim();
      }
    } catch (e) {
      debugPrint("[AagmaalResolver] Error scraping page: $e");
    }
    return null;
  }

  static Future<String?> _searchAndResolveFreshStream(String query, String originalFileName) async {
    try {
      final searchUrl = "https://aagmaal.mba/?s=${Uri.encodeComponent(query)}";
      final res = await http.get(Uri.parse(searchUrl), headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'Referer': 'https://aagmaal.mba/',
      }).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;

      final html = res.body;
      final linkReg = RegExp(r'<h[23][^>]*class="[^"]*post-box-title[^"]*"[^>]*>\s*<a[^>]+href="([^"]+)"', caseSensitive: false);
      final firstMatch = linkReg.firstMatch(html);
      if (firstMatch != null) {
        final postUrl = firstMatch.group(1)!.trim();
        if (postUrl.isNotEmpty) {
          return await _scrapeFreshStreamFromPage(postUrl);
        }
      }
    } catch (e) {
      debugPrint("[AagmaalResolver] Search & resolve error: $e");
    }
    return null;
  }
}

class _CachedStream {
  final String streamUrl;
  final DateTime expiresAt;
  _CachedStream(this.streamUrl, this.expiresAt);
}
