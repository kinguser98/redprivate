import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dns_proxy.dart';

class HlsQualityParser {
  /// Fetches an M3U8 master playlist and extracts ONLY real variant stream qualities
  static Future<Map<String, String>> parseQualities(String masterUrl) async {
    final Map<String, String> qualities = {};
    if (masterUrl.isEmpty || !masterUrl.startsWith('http')) return qualities;

    try {
      String referer = 'https://streamtape.com/';
      if (masterUrl.contains('xhamster') || masterUrl.contains('xhvid') || 
          masterUrl.contains('xh.video') || masterUrl.contains('xhcdn') ||
          masterUrl.contains('xhpingcdn') || masterUrl.contains('xhamster46') ||
          masterUrl.contains('xhcdn') || masterUrl.contains('xhcdn2')) {
        referer = 'https://xhamster.com/';
      } else if (masterUrl.contains('luluvdo') || masterUrl.contains('lulustream') || masterUrl.contains('lulucdn') || masterUrl.contains('tnmr.org')) {
        referer = 'https://luluvdo.com/';
      }

      final fetchTarget = mediaForwardUrlIfNeeded(masterUrl) ?? masterUrl;
      final res = await http.get(
        Uri.parse(fetchTarget),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Referer': referer,
        },
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200 && res.body.contains('#EXTM3U')) {
        final body = res.body;
        final lines = body.split(RegExp(r'\r?\n'));
        final baseUrl = Uri.parse(masterUrl);
        String? currentLabel;

        for (final rawLine in lines) {
          final line = rawLine.trim();
          if (line.startsWith('#EXT-X-STREAM-INF')) {
            final resMatch = RegExp(r'RESOLUTION=(\d+)x(\d+)', caseSensitive: false).firstMatch(line);
            if (resMatch != null) {
              final h = int.tryParse(resMatch.group(2)!) ?? 0;
              if (h >= 1000) {
                currentLabel = '1080p Full HD';
              } else if (h >= 700) {
                currentLabel = '720p HD';
              } else if (h >= 450) {
                currentLabel = '480p SD';
              } else if (h >= 300) {
                currentLabel = '360p Low';
              } else {
                currentLabel = '${h}p';
              }
            } else {
              final bwMatch = RegExp(r'BANDWIDTH=(\d+)', caseSensitive: false).firstMatch(line);
              if (bwMatch != null) {
                final bw = (int.tryParse(bwMatch.group(1)!) ?? 0) ~/ 1000;
                currentLabel = '$bw kbps';
              } else {
                currentLabel = 'Variant Stream';
              }
            }
          } else if (line.isNotEmpty && !line.startsWith('#')) {
            if (currentLabel != null) {
              final absoluteUrl = baseUrl.resolve(line).toString();
              qualities[currentLabel] = absoluteUrl;
              currentLabel = null;
            }
          }
        }
      }
    } catch (e) {
      debugPrint("HlsQualityParser error: $e");
    }

    return qualities;
  }
}
