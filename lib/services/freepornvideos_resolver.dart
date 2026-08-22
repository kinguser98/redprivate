import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../services/scraper_service.dart';

/// On-device resolver for freepornvideos.xxx.
///
/// The site has no age-gate and grids are cheaply server-scraped, so only
/// stream RESOLUTION runs here. The video page's get_file links 302-redirect
/// to an IP-bound, time-limited fpvcdn.com CDN URL (key=...&ip=<client>...),
/// so a server-resolved URL is a 403 from the phone. Fetching the video page
/// and following the get_file redirect with dart:io right here on the device
/// yields per-quality direct MP4s bound to the phone's own IP.
class FreepornvideosResolver {
  static void _log(String msg) => debugPrint('[FreepornvideosResolver] $msg');

  static String get _mobileUa =>
      'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36';

  static String get _siteOrigin => 'https://www.freepornvideos.xxx';

  static bool isFreepornvideosUrl(String rawUrl) {
    if (rawUrl.isEmpty) return false;
    return rawUrl.toLowerCase().contains('freepornvideos');
  }

  static Future<String?> _get(String url, {String? referer}) async {
    try {
      final res = await http
          .get(
            Uri.parse(url),
            headers: {
              'User-Agent': _mobileUa,
              'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
              'Accept-Language': 'en-US,en;q=0.9',
              if (referer != null && referer.isNotEmpty) 'Referer': referer,
            },
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 200 && res.body.isNotEmpty) {
        return res.body;
      }
      _log('_get ${res.statusCode} for $url');
    } catch (e) {
      _log('_get error for $url: $e');
    }
    return null;
  }

  /// Follows the get_file redirect chain on-device and returns the final
  /// (IP-bound) CDN URL. Returns null on failure.
  static Future<String?> _resolveDirect(String getFileUrl) async {
    final client = HttpClient();
    try {
      final req = await client
          .getUrl(Uri.parse(getFileUrl))
          .timeout(const Duration(seconds: 20));
      req.headers.set('User-Agent', _mobileUa);
      req.headers.set('Referer', _siteOrigin);
      req.headers.set('Accept', 'video/mp4,*/*');
      // Ask for 1 byte so the redirect-followed response body is negligible;
      // HttpClient exposes the redirect chain on the final response regardless.
      req.headers.set('Range', 'bytes=0-0');
      final res = await req.close().timeout(const Duration(seconds: 20));
      final hop = res.redirects.isNotEmpty ? res.redirects.last : null;
      await res.drain<void>().catchError((_) {});
      if (hop != null) {
        return hop.location.toString();
      }
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return getFileUrl;
      }
      _log('_resolveDirect status ${res.statusCode} for $getFileUrl');
    } catch (e) {
      _log('_resolveDirect error for $getFileUrl: $e');
    } finally {
      client.close();
    }
    return null;
  }

  /// Resolves a freepornvideos.xxx video page into per-quality direct MP4s.
  static Future<ScraperResolveResult?> resolveItem(String pageUrl) async {
    if (!isFreepornvideosUrl(pageUrl)) return null;
    _log('resolveItem $pageUrl');

    final pageHtml = await _get(pageUrl, referer: _siteOrigin);
    if (pageHtml == null) return null;

    // <source src='https://www.freepornvideos.xxx/get_file/{n}/{tok}/{dir}/{id}_{res}m.mp4/' ... label="2160p">
    final urlRe = RegExp(
        r"src\s*=\s*'(https://www\.freepornvideos\.xxx/get_file/[^']+?_(\d{3,4})m\.mp4/)'",
        caseSensitive: false);
    final byRes = <int, String>{};
    for (final m in urlRe.allMatches(pageHtml)) {
      final res = int.tryParse(m.group(2)!) ?? 0;
      if (res <= 0) continue;
      byRes[res] = m.group(1)!;
    }
    if (byRes.isEmpty) {
      _log('resolveItem: no get_file sources on $pageUrl');
      return null;
    }

    final ordered = <String, String>{};
    final keys = byRes.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final res in keys) {
      final finalUrl = await _resolveDirect(byRes[res]!);
      if (finalUrl == null) continue;
      final label = res >= 2000 ? '4K' : '${res}p';
      ordered[label] = finalUrl;
    }

    if (ordered.isEmpty) {
      _log('resolveItem: no resolvable direct CDN url');
      return null;
    }

    _log('resolveItem qualities=${ordered.keys.toList()}');
    return ScraperResolveResult(
      qualities: ordered,
      headers: {
        'Referer': _siteOrigin,
        'Origin': _siteOrigin,
      },
    );
  }
}
