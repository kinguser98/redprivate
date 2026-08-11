import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class LuluvdoResolver {
  static final Map<String, String> _cache = {};

  static String _baseNConvert(int num, int b) {
    const chars = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
    if (num < b) return chars[num];
    return _baseNConvert(num ~/ b, b) + chars[num % b];
  }

  static String _unpackDeanEdwards(String p, int a, int c, List<String> k) {
    for (int i = c - 1; i >= 0; i--) {
      if (i < k.length && k[i].isNotEmpty) {
        final key = _baseNConvert(i, a);
        p = p.replaceAll(RegExp(r'\b' + RegExp.escape(key) + r'\b'), k[i]);
      }
    }
    return p;
  }

  /// Extracts the direct phone-authenticated tokenized M3U8 stream URL on-device
  static Future<String?> resolveOnDevice(String rawUrl, {bool forceRefresh = false}) async {
    if (rawUrl.isEmpty) return null;

    if (!forceRefresh && _cache.containsKey(rawUrl)) {
      debugPrint("Luluvdo stream served from cache: ${_cache[rawUrl]}");
      return _cache[rawUrl];
    }

    final fileCode = rawUrl.trim().replaceAll(RegExp(r'/+$'), '').split('/').last;
    if (fileCode.isEmpty) return null;

    final urlsToTry = [
      'https://lulucdn.com/e/$fileCode',
      'https://lulucdn.com/$fileCode',
      'https://luluvdo.com/e/$fileCode',
      'https://lulustream.com/e/$fileCode',
    ];

    final headers = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Referer': 'https://lulucdn.com/',
    };

    final client = http.Client();
    try {
      for (final targetUrl in urlsToTry) {
        try {
          final res = await client.get(Uri.parse(targetUrl), headers: headers).timeout(const Duration(seconds: 8));
          if (res.statusCode != 200) continue;
          final html = res.body;

          final evalMatch = RegExp(
            r'eval\(function\(p,a,c,k,e,d\)\{.*?\n?\}\s*\(\s*[\x27\x22](.*?)[\x27\x22]\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*[\x27\x22](.*?)[\x27\x22]\.split\([\x27\x22]\|[\x27\x22]\)',
            dotAll: true,
          ).firstMatch(html);

          if (evalMatch != null) {
            final p = evalMatch.group(1)!;
            final a = int.parse(evalMatch.group(2)!);
            final c = int.parse(evalMatch.group(3)!);
            final k = evalMatch.group(4)!.split('|');

            final unpacked = _unpackDeanEdwards(p, a, c, k);
            final m3u8Match = RegExp(r'https?://[^\s\x27\x22<>]+\.m3u8(?:\?[^\s\x27\x22<>]*)?', caseSensitive: false).firstMatch(unpacked);
            if (m3u8Match != null) {
              final streamUrl = m3u8Match.group(0)!;
              debugPrint("Luluvdo native stream resolved on device: $streamUrl");
              _cache[rawUrl] = streamUrl;
              return streamUrl;
            }
          }

          final m3u8Match = RegExp(r'https?://[^\s\x27\x22<>]+\.m3u8(?:\?[^\s\x27\x22<>]*)?', caseSensitive: false).firstMatch(html);
          if (m3u8Match != null) {
            final streamUrl = m3u8Match.group(0)!;
            debugPrint("Luluvdo native stream resolved on device: $streamUrl");
            _cache[rawUrl] = streamUrl;
            return streamUrl;
          }
        } catch (e) {
          debugPrint("Error fetching $targetUrl: $e");
        }
      }
    } finally {
      client.close();
    }

    return null;
  }
}
