import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../services/scraper_service.dart';

/// On-device resolver for HQPorner (m.hqporner.com).
///
/// The site has no Cloudflare/age-gate and grids are cheaply server-scraped, so
/// only stream RESOLUTION runs here. The bigcdn CDN IP-binds stream URLs to the
/// client that fetched the mydaddy.cc embed player, so a server-resolved URL is
/// a 404 from the phone. Plain `dart:io` HTTP requests originate from the
/// phone's own IP, so fetching the video page + embed right here on the device
/// yields playable per-quality direct MP4s (no headless WebView needed).
class HqpornerResolver {
  static void _log(String msg) => debugPrint('[HqpornerResolver] $msg');

  static String get _mobileUa =>
      'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36';

  static bool isHqpornerUrl(String rawUrl) {
    if (rawUrl.isEmpty) return false;
    return rawUrl.toLowerCase().contains('hqporner');
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

  /// Resolves the hqporner video page into per-quality direct MP4 links.
  static Future<ScraperResolveResult?> resolveItem(String pageUrl) async {
    if (!isHqpornerUrl(pageUrl)) return null;
    _log('resolveItem $pageUrl');

    final pageHtml = await _get(pageUrl, referer: 'https://m.hqporner.com/');
    if (pageHtml == null) return null;

    // Step 1: mydaddy.cc embed iframe (protocol-relative or absolute).
    final iframeM = RegExp(
            'src\\s*=\\s*"(?:https?:)?//mydaddy\\.cc/video/([^"]+)"',
            caseSensitive: false)
        .firstMatch(pageHtml);
    if (iframeM == null) {
      _log('resolveItem: no mydaddy iframe on $pageUrl');
      return null;
    }
    final embedUrl = 'https://mydaddy.cc/video/${iframeM.group(1)!}';
    _log('resolveItem embed=$embedUrl');

    // Step 2: the embed exposes per-quality mp4s (//sNN.bigcdn.cc/.../{res}.mp4).
    final embedHtml = await _get(embedUrl, referer: 'https://m.hqporner.com/');
    if (embedHtml == null) return null;

    final Map<String, String> qualities = {};
    final urlRe = RegExp(
        '(?:https?:)?//[a-z0-9]+\\.bigcdn\\.cc/[^\\s"<>]+\\.mp4',
        caseSensitive: false);
    for (final m in urlRe.allMatches(embedHtml)) {
      var u = m[0]!;
      if (u.startsWith('//')) u = 'https:$u';
      final resM = RegExp(r'/(\d{3,4})\.mp4').firstMatch(u);
      if (resM == null) continue;
      final res = int.parse(resM.group(1)!);
      final label = res >= 4096 ? '4K' : '${res}p';
      // Keep the first (highest-quality) URL per label; multiple CDN nodes
      // can appear, but one link per resolution is enough.
      if (!qualities.containsKey(label)) {
        qualities[label] = u;
      }
    }

    if (qualities.isEmpty) {
      _log('resolveItem: no bigcdn mp4s in embed');
      return null;
    }

    final ordered = <String, String>{};
    final keys = qualities.keys.toList()
      ..sort((a, b) {
        final na = int.tryParse(RegExp(r'\d+').firstMatch(a)?.group(0) ?? '') ?? 0;
        final nb = int.tryParse(RegExp(r'\d+').firstMatch(b)?.group(0) ?? '') ?? 0;
        return nb.compareTo(na);
      });
    for (final k in keys) {
      ordered[k] = qualities[k]!;
    }
    _log('resolveItem qualities=${ordered.keys.toList()}');
    return ScraperResolveResult(
      qualities: ordered,
      headers: {
        'Referer': 'https://mydaddy.cc/',
        'Origin': 'https://mydaddy.cc',
      },
    );
  }
}