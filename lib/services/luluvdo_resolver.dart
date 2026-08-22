import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/io_client.dart';

class LuluvdoResolver {
  static final Map<String, String> _cache = {};
  static final Map<String, DateTime> _cacheTime = {};
  static const _cacheTtl = Duration(hours: 6); // tnmr.org tokens expire in 8h; be safe with 6h


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

  static HttpClient _createDohClient() {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8)
      ..badCertificateCallback = (cert, host, port) => true;
    client.findProxy = (uri) => 'DIRECT';
    client.connectionFactory = (uri, host, port) async {
      final ips = [
        '104.26.6.79',
        '172.67.68.215',
        '104.26.7.79',
        '104.20.19.112',
        '172.66.167.168'
      ];
      for (final ip in ips) {
        try {
          final s = await Socket.connect(ip, uri.port, timeout: const Duration(seconds: 4));
          if (uri.scheme == 'https') {
            final sec = await SecureSocket.secure(s, host: uri.host, onBadCertificate: (c) => true);
            return ConnectionTask.fromSocket(Future.value(sec), () {});
          }
          return ConnectionTask.fromSocket(Future.value(s), () {});
        } catch (_) {}
      }
      throw Exception("Could not connect to ${uri.host}");
    };
    return client;
  }

  /// Extracts the direct phone-authenticated tokenized M3U8 stream URL on-device
  static Future<String?> resolveOnDevice(String rawUrl, {bool forceRefresh = false}) async {
    if (rawUrl.isEmpty) return null;

    if (!forceRefresh && _cache.containsKey(rawUrl)) {
      final cachedAt = _cacheTime[rawUrl];
      if (cachedAt != null && DateTime.now().difference(cachedAt) < _cacheTtl) {
        debugPrint("Luluvdo stream served from cache: ${_cache[rawUrl]}");
        return _cache[rawUrl];
      } else {
        // Cache expired - remove stale entry
        _cache.remove(rawUrl);
        _cacheTime.remove(rawUrl);
      }
    }

    final fileCode = rawUrl.trim().replaceAll(RegExp(r'/+$'), '').split('/').last;
    if (fileCode.isEmpty) return null;

    final urlsToTry = [
      'https://luluvdo.com/e/$fileCode',
      'https://luluvdo.com/$fileCode',
      'https://lulustream.com/e/$fileCode',
      'https://lulustream.com/$fileCode',
      'https://lulucdn.com/e/$fileCode',
      'https://lulucdn.com/$fileCode',
    ];

    final headers = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Referer': 'https://luluvdo.com/',
    };

    final ioClient = _createDohClient();
    final client = IOClient(ioClient);
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
              _cacheTime[rawUrl] = DateTime.now();
              return streamUrl;
            }
          }

          final m3u8Match = RegExp(r'https?://[^\s\x27\x22<>]+\.m3u8(?:\?[^\s\x27\x22<>]*)?', caseSensitive: false).firstMatch(html);
          if (m3u8Match != null) {
            final streamUrl = m3u8Match.group(0)!;
            debugPrint("Luluvdo native stream resolved on device: $streamUrl");
            _cache[rawUrl] = streamUrl;
            _cacheTime[rawUrl] = DateTime.now();
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
