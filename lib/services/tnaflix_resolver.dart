import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// On-device resolver for TNAFlix streams.
///
/// TNAFlix embeds its video qualities as <source size="NNN"> tags inside the
/// video page. The URLs carry a time-based signature (secure=...&timestamp),
/// so they are resolved HERE on the device from the live page. All HTTP goes
/// through the app's DoH proxy (tnaflix hosts are in the blocklist), so this
/// works even where the ISP DNS blocks *.tnaflix.com.
class TnaflixStreamResult {
  final Map<String, String> qualities; // e.g. {'1080p': url, '480p': url}
  final String defaultQuality;
  final String defaultUrl;

  TnaflixStreamResult({
    required this.qualities,
    required this.defaultQuality,
    required this.defaultUrl,
  });
}

class TnaflixResolver {
  static const String _base = 'https://www.tnaflix.com';
  static const String _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';

  static final Map<String, Map<String, String>> _qualitiesCache = {};

  static bool isTnaflixUrl(String rawUrl) {
    if (rawUrl.isEmpty) return false;
    return rawUrl.toLowerCase().contains('tnaflix');
  }

  static bool isTnaflixMediaUrl(String rawUrl) {
    final lower = rawUrl.toLowerCase();
    if (lower.contains('tnaflix') &&
        (lower.contains('.mp4') || lower.contains('.m3u8'))) {
      return true;
    }
    final uri = Uri.tryParse(rawUrl);
    if (uri != null &&
        (uri.path.toLowerCase().endsWith('.mp4') ||
            uri.query.toLowerCase().contains('.mp4'))) {
      return true;
    }
    return false;
  }

  static HttpClient _client() {
    final c = HttpClient();
    c.connectionTimeout = const Duration(seconds: 12);
    c.badCertificateCallback = (cert, host, port) => true;
    return c;
  }

  static Future<String?> _fetchPage(String pageUrl) async {
    HttpClient? client;
    try {
      client = _client();
      final req = await client.getUrl(Uri.parse(pageUrl));
      req.followRedirects = true;
      req.headers.set('User-Agent', _ua);
      req.headers.set('Referer', '$_base/');
      req.headers.set('Accept', '*/*');
      final resp = await req.close().timeout(const Duration(seconds: 15));
      final html = await resp
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 15));
      return html;
    } catch (e) {
      debugPrint('TnaflixResolver fetch error: $e');
    } finally {
      client?.close(force: true);
    }
    return null;
  }

  /// Extracts the <source type="video/mp4" size="NNN"> qualities from the page.
  static Map<String, String>? _extractQualities(String html) {
    if (html.isEmpty) return null;
    final Map<String, String> qMap = {};

    final srcRe =
        RegExp(r'<source[^>]+src="([^"]+)"[^>]+type="video/mp4"[^>]+size="(\d+)"',
            caseSensitive: false);
    for (final m in srcRe.allMatches(html)) {
      var url = m.group(1)!.trim();
      if (url.isEmpty) continue;
      if (!url.startsWith('http')) {
        url = url.startsWith('//') ? 'https:$url' : url;
      }
      final res = int.tryParse(m.group(2)!) ?? 0;
      final label = res >= 4096 ? '4K' : '${res}p';
      qMap.putIfAbsent(label, () => url);
    }

    // Fallback: any video/mp4 source (some pages lack the size attribute).
    if (qMap.isEmpty) {
      final anyRe =
          RegExp(r'<source[^>]+src="([^"]+)"[^>]+type="video/mp4"',
              caseSensitive: false);
      var i = 0;
      for (final m in anyRe.allMatches(html)) {
        var url = m.group(1)!.trim();
        if (url.isEmpty) continue;
        if (!url.startsWith('http')) {
          url = url.startsWith('//') ? 'https:$url' : url;
        }
        final label = i == 0 ? 'Direct MP4' : 'Direct MP4 ${i + 1}';
        qMap[label] = url;
        i++;
      }
    }

    return qMap.isEmpty ? null : qMap;
  }

  static TnaflixStreamResult? _buildResult(String pageUrl) {
    final map = _qualitiesCache[pageUrl];
    if (map == null || map.isEmpty) return null;
    final sortedKeys = map.keys.toList()
      ..sort((a, b) {
        final na = int.tryParse(
                RegExp(r'\d+').firstMatch(a)?.group(0) ?? '') ??
            0;
        final nb = int.tryParse(
                RegExp(r'\d+').firstMatch(b)?.group(0) ?? '') ??
            0;
        return nb.compareTo(na);
      });
    final defKey = sortedKeys.first;
    return TnaflixStreamResult(
      qualities: map,
      defaultQuality: defKey,
      defaultUrl: map[defKey]!,
    );
  }

  static Future<TnaflixStreamResult?> resolveQualities(String pageUrl,
      {bool forceRefresh = false}) async {
    if (pageUrl.isEmpty) return null;

    if (!forceRefresh && _qualitiesCache.containsKey(pageUrl)) {
      return _buildResult(pageUrl);
    }

    for (var attempt = 0; attempt < 3; attempt++) {
      final html = await _fetchPage(pageUrl);
      final qMap = html == null ? null : _extractQualities(html);
      if (qMap != null && qMap.isNotEmpty) {
        _qualitiesCache[pageUrl] = qMap;
        return _buildResult(pageUrl);
      }
      if (attempt < 2) {
        await Future.delayed(Duration(milliseconds: 600 + attempt * 400));
      }
    }
    return null;
  }

  static Future<String?> resolveOnDevice(String pageUrl,
      {bool forceRefresh = false}) async {
    final res = await resolveQualities(pageUrl, forceRefresh: forceRefresh);
    return res?.defaultUrl;
  }
}