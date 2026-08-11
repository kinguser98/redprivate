import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'hls_quality_parser.dart';

class XHamsterStreamResult {
  final Map<String, String> qualities; // e.g. {'1080p': url, '720p': url}
  final String defaultQuality;
  final String defaultUrl;

  XHamsterStreamResult({
    required this.qualities,
    required this.defaultQuality,
    required this.defaultUrl,
  });
}

class XHamsterResolver {
  static final Map<String, String> _cache = {};
  static final Map<String, Map<String, String>> _qualitiesCache = {};
  static List<String> _domains = [
    'xhamster.desi',
    'xhamster.com',
    'xhamster.one',
    'xhamster2.com',
    'xhamster20.com',
    'xhamster46.desi',
    'xhvid.com',
    'xh.video'
  ];

  static const String _prefsKey = 'xhamster_domains';

  static Future<void> loadSavedDomains() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_prefsKey);
      if (saved != null && saved.isNotEmpty) {
        _domains = saved;
      }
    } catch (_) {}
  }

  static Future<void> saveDomains(List<String> domains) async {
    _domains = domains.where((d) => d.trim().isNotEmpty).toList();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey, _domains);
    } catch (_) {}
  }

  static List<String> get domains => List.unmodifiable(_domains);

  static bool isXHamsterUrl(String rawUrl) {
    if (rawUrl.isEmpty) return false;
    final lower = rawUrl.toLowerCase();
    for (final d in _domains) {
      if (lower.contains(d.toLowerCase())) return true;
    }
    return lower.contains('xhamster') || lower.contains('xhvid') || lower.contains('xh.video');
  }

  /// Resolve stream qualities map and default URL (NO dummy qualities - ONLY real extracted streams)
  static Future<XHamsterStreamResult?> resolveQualities(String rawUrl, {bool forceRefresh = false}) async {
    if (rawUrl.isEmpty) return null;

    if (!forceRefresh && _qualitiesCache.containsKey(rawUrl)) {
      final map = _qualitiesCache[rawUrl]!;
      final defQ = map.containsKey('720p HD')
          ? '720p HD'
          : (map.containsKey('1080p Full HD') ? '1080p Full HD' : map.keys.first);
      return XHamsterStreamResult(
        qualities: map,
        defaultQuality: defQ,
        defaultUrl: map[defQ]!,
      );
    }

    final headers = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Referer': 'https://xhamster.com/',
    };

    try {
      // Increased timeout to 12s for mobile networks
      final res = await http.get(Uri.parse(rawUrl), headers: headers).timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final html = res.body;
        final Map<String, String> qMap = {};

        // IMPORTANT: Always parse the ORIGINAL page HTML.
        // Do NOT follow iframes blindly – the first iframe is often a Google Tag Manager
        // analytics tag (266 bytes) which replaces our targetHtml and breaks all parsing.
        // We only follow iframes that look like real video player embeds.
        String targetHtml = html;
        final iframeMatches = RegExp(r'<iframe[^\>]*src=["\x27]([^"\x27]+)["\x27]', caseSensitive: false).allMatches(html);
        for (final im in iframeMatches) {
          var embedUrl = im.group(1)!.trim();
          if (embedUrl.startsWith('//')) embedUrl = 'https:$embedUrl';
          // Skip analytics/tracking iframes (GTM, Google, Facebook, etc.)
          if (embedUrl.contains('googletagmanager') ||
              embedUrl.contains('google.com') ||
              embedUrl.contains('facebook.com') ||
              embedUrl.contains('analytics') ||
              embedUrl.contains('doubleclick') ||
              embedUrl.contains('ns.html')) continue;
          // Only follow iframes that look like actual video embeds
          if (embedUrl.contains('xhamster') || embedUrl.contains('xhvid') ||
              embedUrl.contains('embed') || embedUrl.contains('player') ||
              embedUrl.contains('xhpingcdn')) {
            try {
              final embedRes = await http.get(Uri.parse(embedUrl), headers: headers).timeout(const Duration(seconds: 8));
              if (embedRes.statusCode == 200 && embedRes.body.length > 1000) {
                targetHtml = embedRes.body;
                break;
              }
            } catch (_) {}
          }
        }

        // 1. Regex: extract quality-labeled mp4/m3u8 URLs from page scripts
        final RegExp qualityRegExp = RegExp(
          r'["\x27](720p|1080p|480p|360p|240p|1080|720|480|360|240)["\x27]\s*:\s*["\x27](https?:\\?/\\?/[^"\x27]+\.(?:mp4|m3u8)[^"\x27]*)["\x27]',
          caseSensitive: false,
        );
        for (final m in qualityRegExp.allMatches(targetHtml)) {
          var qLabel = m.group(1)!.toLowerCase();
          if (!qLabel.endsWith('p')) qLabel = '${qLabel}p';
          final qUrl = m.group(2)!.replaceAll(r'\/', '/');
          qMap[qLabel] = qUrl;
        }

        // 2. Fallback: find any m3u8 URL in the page and parse its HLS variants
        if (qMap.isEmpty) {
          // Search in original html too (in case iframe content had no m3u8)
          final searchHtml = targetHtml.contains('xhpingcdn') ? targetHtml : html;
          final m3u8Match = RegExp(
            r'https?://[^\s\x27\x22<>\\]+\.m3u8(?:\?[^\s\x27\x22<>\\]*)?',
            caseSensitive: false,
          ).firstMatch(searchHtml);
          if (m3u8Match != null) {
            final m3u8Url = m3u8Match.group(0)!;
            final hlsQualities = await HlsQualityParser.parseQualities(m3u8Url);
            if (hlsQualities.isNotEmpty) {
              qMap.addAll(hlsQualities);
            } else {
              qMap['720p HD'] = m3u8Url;
            }
          } else {
            // Also try original html if targetHtml had no results
            if (targetHtml != html) {
              final m3u8MatchOrig = RegExp(
                r'https?://[^\s\x27\x22<>\\]+\.m3u8(?:\?[^\s\x27\x22<>\\]*)?',
                caseSensitive: false,
              ).firstMatch(html);
              if (m3u8MatchOrig != null) {
                final m3u8Url = m3u8MatchOrig.group(0)!;
                final hlsQualities = await HlsQualityParser.parseQualities(m3u8Url);
                qMap.addAll(hlsQualities.isNotEmpty ? hlsQualities : {'720p HD': m3u8Url});
              }
            }
            if (qMap.isEmpty) {
              final mp4Match = RegExp(
                r'https?://[^\s\x27\x22<>\\]+\.mp4(?:\?[^\s\x27\x22<>\\]*)?',
                caseSensitive: false,
              ).firstMatch(searchHtml);
              if (mp4Match != null) {
                qMap['Direct MP4'] = mp4Match.group(0)!;
              }
            }
          }
        }

        if (qMap.isNotEmpty) {
          _qualitiesCache[rawUrl] = qMap;
          final defKey = qMap.containsKey('720p HD')
              ? '720p HD'
              : (qMap.containsKey('720p')
                  ? '720p'
                  : (qMap.containsKey('1080p Full HD')
                      ? '1080p Full HD'
                      : qMap.keys.first));
          
          final defUrl = qMap[defKey]!;
          _cache[rawUrl] = defUrl;

          return XHamsterStreamResult(
            qualities: qMap,
            defaultQuality: defKey,
            defaultUrl: defUrl,
          );
        }
      }
    } catch (e) {
      debugPrint("XHamsterResolver error: $e");
    }

    return null;
  }

  /// Simple on-device single stream resolution (picks default quality)
  static Future<String?> resolveOnDevice(String rawUrl, {bool forceRefresh = false}) async {
    final res = await resolveQualities(rawUrl, forceRefresh: forceRefresh);
    return res?.defaultUrl;
  }
}
