import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// On-device resolver for Eporner streams.
///
/// Eporner signs every /dload/ URL for the requesting IP (the CDN URL embeds
/// the caller's address and a timestamp), so the server cannot hand out
/// playable links. The page is therefore resolved HERE, on the device:
///   1. fetch the video page,
///   2. extract the /dload/{id}/{q}/...-{q}p.mp4 quality links,
///   3. follow the redirect chain per quality to mint client-IP-bound CDN URLs.
/// All HTTP goes through the app's DoH proxy (eporner hosts are in the
/// blocklist), so this works even where the ISP DNS blocks *.eporner.com.
class EpornerStreamResult {
  final Map<String, String> qualities; // e.g. {'1080p': url, '720p': url}
  final String defaultQuality;
  final String defaultUrl;

  EpornerStreamResult({
    required this.qualities,
    required this.defaultQuality,
    required this.defaultUrl,
  });
}

class EpornerResolver {
  static const String _base = 'https://www.eporner.com';
  static const String _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';

  static final Map<String, Map<String, String>> _qualitiesCache = {};

  static bool isEpornerUrl(String rawUrl) {
    if (rawUrl.isEmpty) return false;
    return rawUrl.toLowerCase().contains('eporner');
  }

  /// True when [rawUrl] is already a playable Eporner media/CDN link (a signed
  /// /v5/ CDN URL, a gvideo/dload link, or a .mp4) rather than a video PAGE url
  /// that still needs on-device resolution.
  static bool isEpornerMediaUrl(String rawUrl) {
    final lower = rawUrl.toLowerCase();
    if (lower.contains('/v5/') ||
        lower.contains('/dload/') ||
        lower.contains('gvideo.') ||
        lower.contains('-cdn.eporner')) {
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

  /// Follows the redirect chain (dload -> signed CDN URL) and returns the
  /// final, client-IP-bound URL. Redirections stay inside Dart's DoH-enabled
  /// HttpClient, so every hop resolves via DoH even when system DNS is poisoned.
  /// Returns '' if the chain lands on a non-media page (challenge/error/HTML)
  /// instead of the actual video, so callers can retry with a fresh dload link.
  static Future<String> _followToFinal(String url) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      final result = await _followOnce(url);
      if (result != null && result.isNotEmpty) return result;
      if (attempt < 2) {
        await Future.delayed(Duration(milliseconds: 500 + attempt * 400));
      }
    }
    return '';
  }

  static Future<String?> _followOnce(String url) async {
    var current = url;
    final client = _client();
    try {
      for (var hop = 0; hop < 6; hop++) {
        final req = await client.getUrl(Uri.parse(current));
        req.followRedirects = false;
        req.headers.set('User-Agent', _ua);
        req.headers.set('Referer', '$_base/');
        req.headers.set('Accept', '*/*');
        final resp = await req.close().timeout(const Duration(seconds: 12));
        final status = resp.statusCode;
        if (status >= 200 && status < 300) {
          final ctype = (resp.headers.value('content-type') ?? '').toLowerCase();
          final looksHtml = ctype.contains('text/html') ||
              ctype.contains('text/plain') ||
              ctype.contains('application/json');
          // Reached the playable CDN URL. Do NOT drain: the body is the video
          // (or an HTML challenge/error page). Only accept URLs that look like
          // actual media — an HTML page means we hit a challenge, not a video.
          if (looksHtml && !current.toLowerCase().contains('.mp4')) {
            return null;
          }
          if (EpornerResolver.isEpornerMediaUrl(current) ||
              (ctype.startsWith('video/') || ctype.contains('octet-stream'))) {
            return current;
          }
          return null;
        }
        if (status >= 300 && status < 400) {
          final loc = resp.headers.value('location');
          await resp.drain();
          if (loc == null || loc.isEmpty) return null;
          current = Uri.parse(current).resolve(loc).toString();
          continue;
        }
        await resp.drain();
        return null;
      }
    } catch (e) {
      debugPrint('EpornerResolver hop error: $e');
    } finally {
      client.close(force: true);
    }
    return null;
  }

  /// Resolve stream qualities map and default URL (ONLY real extracted streams).
  static Future<EpornerStreamResult?> resolveQualities(
      String pageUrl, {bool forceRefresh = false}) async {
    if (pageUrl.isEmpty) return null;

    if (!forceRefresh && _qualitiesCache.containsKey(pageUrl)) {
      return _buildResult(pageUrl);
    }

    HttpClient? client;
    try {
      client = _client();
      final req = await client.getUrl(Uri.parse(pageUrl));
      req.followRedirects = true;
      req.headers.set('User-Agent', _ua);
      req.headers.set('Accept', '*/*');
      final resp = await req.close().timeout(const Duration(seconds: 15));
      final html = await resp
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 15));
      client.close(force: true);
      client = null;

      if (html.isEmpty) return null;

      // Eporner intermittently serves a Cloudflare challenge page instead of the
      // video page. Detect that and retry the fetch a few times rather than
      // giving up (matches the "try again and it plays" user behaviour). A page
      // with a contentUrl (JSON-LD gvideo stream) or an EPvideo element is a
      // real video page even if it lacks a /dload/ section.
      final hasContentUrl = RegExp('"contentUrl"\\s*:\\s*"[^"]+\\.mp4"',
              caseSensitive: false)
          .hasMatch(html);
      final isChallenge = html.contains('Just a moment') ||
          html.contains('Attention Required') ||
          html.contains('cf-chl') ||
          (!hasContentUrl &&
              !html.contains('EPvideo') &&
              html.contains('<title') &&
              !html.contains('dload'));
      if (isChallenge) {
        debugPrint('EpornerResolver got challenge page, retrying...');
        for (var attempt = 0; attempt < 3; attempt++) {
          await Future.delayed(Duration(milliseconds: 700 + attempt * 500));
          final retryHtml = await _fetchPage(pageUrl);
          if (retryHtml != null && retryHtml.isNotEmpty) {
            final map = _extractQualities(retryHtml);
            if (map != null && map.isNotEmpty) {
              return await _resolveFollowAll(pageUrl, map);
            }
          }
        }
        return null;
      }

      final qMap = _extractQualities(html);
      if (qMap != null && qMap.isNotEmpty) {
        return await _resolveFollowAll(pageUrl, qMap);
      }
    } catch (e) {
      debugPrint('EpornerResolver error: $e');
    } finally {
      client?.close(force: true);
    }
    return null;
  }

  /// Takes the raw quality links, resolves each one into a playable CDN URL,
  /// caches them, and builds the stream result.
  ///
  /// Eporner changed their download flow (2026): /dload/ now redirects to a
  /// /login/ wall for anonymous clients, so those follows usually fail. The
  /// reliable anonymous stream is the JSON-LD contentUrl (gvideo.eporner.com),
  /// which is ALREADY the final client-playable URL — it must be kept as-is
  /// instead of being run through the redirect chain (gvideo would 403 on a
  /// follow). Only www.eporner.com links (dload) get redirected.
  static Future<EpornerStreamResult?> _resolveFollowAll(
      String pageUrl, Map<String, String> qMap) async {
    final Map<String, String> finalMap = {};
    for (final e in qMap.entries) {
      final uri = Uri.tryParse(e.value);
      final keepDirect = uri != null && uri.host.toLowerCase() != 'www.eporner.com';
      final finalUrl = keepDirect ? e.value : await _followToFinal(e.value);
      if (finalUrl.isNotEmpty) {
        finalMap[e.key] = finalUrl;
      }
    }
    if (finalMap.isEmpty) return null;
    _qualitiesCache[pageUrl] = finalMap;
    return _buildResult(pageUrl);
  }

  static Future<String?> _fetchPage(String pageUrl) async {
    HttpClient? client;
    try {
      client = _client();
      final req = await client.getUrl(Uri.parse(pageUrl));
      req.followRedirects = true;
      req.headers.set('User-Agent', _ua);
      req.headers.set('Accept', '*/*');
      final resp = await req.close().timeout(const Duration(seconds: 15));
      final html = await resp
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 15));
      return html;
    } catch (e) {
      debugPrint('EpornerResolver fetch error: $e');
    } finally {
      client?.close(force: true);
    }
    return null;
  }

  static Map<String, String>? _extractQualities(String html) {
    if (html.isEmpty) return null;
    final Map<String, String> qMap = {};

    // JSON-LD contentUrl: "contentUrl": "https://gvideo.eporner.com/{id}/{id}.mp4".
    // This is the stream the eporner.com player itself uses — it is anonymous,
    // already final (no redirect needed), and survived the 2026 /dload/ login
    // wall. Label it with the JSON-LD height when available.
    final contentUrl = RegExp(
            '"contentUrl"\\s*:\\s*"([^"]+\\.mp4)"',
            caseSensitive: false)
        .firstMatch(html);
    if (contentUrl != null) {
      var cu = contentUrl.group(1)!.trim();
      if (cu.startsWith('//')) {
        cu = 'https:$cu';
      }
      if (cu.startsWith('http')) {
        String label = 'HD';
        final p = html.indexOf(cu);
        final near = html.substring(p, (p + 1200).clamp(0, html.length));
        final hm = RegExp('"height"\\s*:\\s*"?\\s*(\\d+)',
                caseSensitive: false)
            .firstMatch(near);
        if (hm != null) {
          final h = int.tryParse(hm.group(1)!) ?? 0;
          if (h > 0) {
            label = h >= 4096 ? '4K' : '${h}p';
          }
        }
        qMap.putIfAbsent(label, () => cu);
      }
    }

    // dload quality links: "/dload/{id}/{q}/{num}-{q}p.mp4". Since the 2026
    // login wall these redirect to /login/, but when they still work they give
    // per-quality (240p..1080p) streams, so keep them as extra options.
    final dload = RegExp('"([^"]*dload/[^"\']+?-\\d+p\\.mp4)"')
        .allMatches(html);
    for (final m in dload) {
      var path = m.group(1)!.trim();
      if (!path.startsWith('http')) {
        path = path.startsWith('/') ? '$_base$path' : '$_base/$path';
      }
      final qm = RegExp(r'-(\d+)p\.mp4').firstMatch(path);
      if (qm == null) continue;
      final label = '${qm.group(1)}p';
      qMap.putIfAbsent(label, () => path);
    }

    return qMap;
  }

  static EpornerStreamResult? _buildResult(String pageUrl) {
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
    return EpornerStreamResult(
      qualities: map,
      defaultQuality: defKey,
      defaultUrl: map[defKey]!,
    );
  }

  /// Simple on-device single stream resolution (picks highest quality).
  static Future<String?> resolveOnDevice(
      String pageUrl, {bool forceRefresh = false}) async {
    final res = await resolveQualities(pageUrl, forceRefresh: forceRefresh);
    return res?.defaultUrl;
  }
}
