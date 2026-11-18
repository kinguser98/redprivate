import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../services/api_service.dart';

class FilemoonResolver {
  static final Map<String, String> _cache = {};
  static final Map<String, DateTime> _cacheTime = {};
  static const _cacheTtl = Duration(hours: 4);

  static bool isFilemoonUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('filemoon') || lower.contains('bysezoxexe');
  }

  static String? extractFileCode(String rawUrl) {
    final clean = rawUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final match = RegExp(r'(?:filemoon\.[a-z]+|bysezoxexe\.com)\/(?:[dev]\/)?([a-zA-Z0-9]+)', caseSensitive: false).firstMatch(clean);
    if (match != null) {
      return match.group(1);
    }
    final segs = clean.split('/').where((s) => s.isNotEmpty).toList();
    return segs.isNotEmpty ? segs.last : null;
  }

  /// Extracts direct HLS (.m3u8) stream URL for Filemoon / Byse links
  static Future<String?> resolveStream(String rawUrl, {bool forceRefresh = false}) async {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return null;

    if (!forceRefresh && _cache.containsKey(trimmed)) {
      final cachedAt = _cacheTime[trimmed];
      if (cachedAt != null && DateTime.now().difference(cachedAt) < _cacheTtl) {
        debugPrint("Filemoon stream served from cache: ${_cache[trimmed]}");
        return _cache[trimmed];
      } else {
        _cache.remove(trimmed);
        _cacheTime.remove(trimmed);
      }
    }

    // 1. Resolve via Backend Admin API endpoint (high reliability, native OpenSSL AES-GCM decryption)
    try {
      final res = await http.post(
        Uri.parse(ApiConfig.adminUrl),
        body: json.encode({
          'action': 'resolve_server_stream',
          'url': trimmed,
        }),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        if (body['status'] == 'success' && body['data']?['stream_url'] != null) {
          final streamUrl = body['data']['stream_url'].toString().trim();
          if (streamUrl.isNotEmpty && (streamUrl.contains('.m3u8') || streamUrl.contains('.mp4'))) {
            debugPrint("Filemoon stream resolved via backend API: $streamUrl");
            _cache[trimmed] = streamUrl;
            _cacheTime[trimmed] = DateTime.now();
            return streamUrl;
          }
        }
      }
    } catch (e) {
      debugPrint("Filemoon backend resolution error: $e");
    }

    // 2. Direct on-device HTML embed parsing fallback (for legacy packer pages)
    final fileCode = extractFileCode(trimmed);
    if (fileCode != null && fileCode.isNotEmpty) {
      final candidateDomains = ['bysezoxexe.com', 'filemoon.to', 'filemoon.sx'];
      for (final domain in candidateDomains) {
        try {
          final embedUrl = 'https://$domain/e/$fileCode';
          final client = HttpClient()..badCertificateCallback = (c, h, p) => true;
          client.connectionTimeout = const Duration(seconds: 6);
          final req = await client.getUrl(Uri.parse(embedUrl));
          req.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36');
          req.headers.set('Referer', 'https://$domain/');
          final resp = await req.close().timeout(const Duration(seconds: 6));
          final html = await utf8.decodeStream(resp);
          client.close();

          final m3u8Match = RegExp(r'''https?://[^\s"'<>]+\.m3u8(?:\?[^\s"'<>]*)?''', caseSensitive: false).firstMatch(html);
          if (m3u8Match != null) {
            final streamUrl = m3u8Match.group(0)!;
            debugPrint("Filemoon legacy stream resolved on device: $streamUrl");
            _cache[trimmed] = streamUrl;
            _cacheTime[trimmed] = DateTime.now();
            return streamUrl;
          }
        } catch (_) {}
      }
    }

    return null;
  }
}
