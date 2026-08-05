import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class StreamtapeService {
  static const List<Map<String, String>> _credentialSets = [
    {'login': 'a43e89ab9e67b46b371f', 'key': '8wykGo0eJkto7yZ'},
    {'login': 'e4a49ef565d194df9617', 'key': 'aGYRRB932LSJRp'},
  ];

  static final Map<String, String> _urlCache = {};

  static const List<String> _apiDomains = [
    'api.strcloud.club',
    'api.streamtape.com',
    'api.streamtape.to',
    'api.streamtape.net',
  ];

  static const List<String> _familyHints = [
    'streamtape',
    'strcloud',
    'tpead',
    'tapepops',
    'advtpe',
    'streamtp',
    's-tpe',
    'tape.gg',
    'stp.gg',
    'tapehost',
    'tapemax',
    'tapecontent.net',
    'watchadsontape',
    'ontape',
  ];

  /// True when a URL belongs to the Streamtape family (needs resolution).
  static bool isStreamtapeFamily(String url) {
    final lower = url.toLowerCase();
    for (final h in _familyHints) {
      if (lower.contains(h)) return true;
    }
    return RegExp(r'/(?:v|e|f)/[A-Za-z0-9_-]{6,}').hasMatch(lower);
  }

  /// True when the URL is already a direct media file (no resolution needed).
  static bool isDirectMediaUrl(String url) => _isDirectMedia(url);

  static String? extractFileId(String url) {
    var match = RegExp(
            r'(?:streamtape\.[a-z]+|strcloud\.[a-z]+|tpead\.[a-z]+|tapepops\.[a-z]+|advtpe\.[a-z]+|watchadsontape\.[a-z]+)/[vef]/([a-zA-Z0-9_-]+)',
            caseSensitive: false)
        .firstMatch(url);
    if (match != null) return match.group(1);
    match = RegExp(r'/[vef]/([a-zA-Z0-9_-]+)', caseSensitive: false).firstMatch(url);
    return match?.group(1);
  }

  static bool _isDirectMedia(String url) {
    final lower = url.toLowerCase();
    if (isStreamtapeFamily(url)) return false;

    return lower.endsWith('.mp4') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.m4v') ||
        lower.endsWith('.mov') ||
        lower.contains('.m3u8') ||
        lower.contains('/hls/') ||
        lower.contains('tapecontent.net') ||
        lower.contains('vercel.app') ||
        lower.contains('archive.org') ||
        lower.contains('koyeb.app');
  }

  static Future<String?> getDirectStreamUrl(String streamtapeUrl, {bool forceRefresh = false}) async {
    if (streamtapeUrl.isEmpty) return null;

    if (_isDirectMedia(streamtapeUrl)) {
      _urlCache[streamtapeUrl] = streamtapeUrl;
      return streamtapeUrl;
    }

    if (!forceRefresh && _urlCache.containsKey(streamtapeUrl)) {
      debugPrint(
          "Streamtape direct URL served from cache: ${_urlCache[streamtapeUrl]}");
      return _urlCache[streamtapeUrl];
    }

    // 1. Direct Official API on client (Phone IP authenticated via DNS Proxy)
    final fileId = extractFileId(streamtapeUrl);
    if (fileId != null) {
      for (final cred in _credentialSets) {
        final login = cred['login']!;
        final key = cred['key']!;
        for (final domain in _apiDomains) {
          try {
            final ticketUrl =
                'https://$domain/file/dlticket?file=$fileId&login=$login&key=$key';
            final ticketRes = await _getWithRetry(ticketUrl);
            if (ticketRes.statusCode != 200) continue;
            final ticketData = json.decode(ticketRes.body);
            if (ticketData['status'] != 200 || ticketData['result'] == null) {
              continue;
            }
            final ticket = ticketData['result']['ticket'];
            final waitTime = (ticketData['result']['wait_time'] as int? ?? 5);
            await Future.delayed(Duration(seconds: waitTime > 5 ? 5 : waitTime));
            final dlUrl = 'https://$domain/file/dl?file=$fileId&ticket=$ticket';
            final dlRes = await _getWithRetry(dlUrl);
            if (dlRes.statusCode != 200) continue;
            final dlData = json.decode(dlRes.body);
            if (dlData['status'] == 200 && dlData['result']?['url'] != null) {
              String directUrl = dlData['result']['url'];
              debugPrint("Resolved Streamtape Stream URL via Direct API: $directUrl");
              _urlCache[streamtapeUrl] = directUrl;
              return directUrl;
            }
          } catch (e) {
            debugPrint('Error resolving via $domain with login $login: $e');
          }
        }
      }
    }

    // 2. Backend PHP resolver fallback
    try {
      final response = await http.get(Uri.parse(
          "${ApiConfig.streamtapeUrl}?url=${Uri.encodeComponent(streamtapeUrl)}")).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' &&
            data['data']?['stream_url'] != null) {
          String url = data['data']['stream_url'].toString().trim();
          if (url.startsWith('http')) {
            debugPrint("Resolved stream URL from backend fallback: $url");
            _urlCache[streamtapeUrl] = url;
            return url;
          }
        }
      }
    } catch (e) {
      debugPrint("Backend resolver error: $e");
    }

    return null;
  }

  static Future<http.Response> _getWithRetry(String fetchUrl,
      {int maxAttempts = 2}) async {
    Object? lastError;
    for (int i = 0; i < maxAttempts; i++) {
      try {
        final res = await http.get(
          Uri.parse(fetchUrl),
          headers: {
            'Connection': 'close',
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          },
        ).timeout(const Duration(seconds: 8));
        return res;
      } catch (e) {
        lastError = e;
        if (i < maxAttempts - 1) {
          await Future.delayed(const Duration(milliseconds: 400));
        }
      }
    }
    throw lastError ?? Exception('Request failed after $maxAttempts attempts');
  }
}
