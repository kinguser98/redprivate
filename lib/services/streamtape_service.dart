import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class StreamtapeService {
  static final Map<String, String> _urlCache = {};

  static List<String> _watchDomains = [];
  static List<String> _apiDomains = [];

  static const List<String> defaultWatchCdnDomains = [
    'advtpe.com',
    'advtape.com',
    'streamta.pe',
    'strcloud.link',
    'strcolud.club',
    'stape.fun',
    'streamtape.com',
    'streamtape.to',
    'streamtape.xyz',
    'tapecontent.net',
    'shavetape.cash',
    'adblocktape.fun',
    'tpead.net',
    'tapepops.com',
  ];

  static const List<String> defaultApiDomains = [
    'api.streamtape.com',
    'api.streamtape.to',
  ];

  // Initialize domains from SharedPreferences
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    
    final watchStr = prefs.getString('admin_streamtape_family_domains');
    if (watchStr != null && watchStr.isNotEmpty) {
      _watchDomains = watchStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    } else {
      _watchDomains = List<String>.from(defaultWatchCdnDomains);
    }

    final apiStr = prefs.getString('admin_streamtape_api_domains');
    if (apiStr != null && apiStr.isNotEmpty) {
      _apiDomains = apiStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    } else {
      _apiDomains = List<String>.from(defaultApiDomains);
    }
  }

  static Future<List<String>> getApiDomains() async {
    await init();
    return _apiDomains;
  }

  static Future<List<String>> getFamilyDomains() async {
    await init();
    return _watchDomains;
  }

  static Future<void> saveApiDomains(List<String> domains) async {
    final prefs = await SharedPreferences.getInstance();
    final str = domains.join(',');
    await prefs.setString('admin_streamtape_api_domains', str);
    _apiDomains = List<String>.from(domains);
    await _syncDomainsToServer(apiDomainsStr: str);
  }

  static Future<void> saveFamilyDomains(List<String> domains) async {
    final prefs = await SharedPreferences.getInstance();
    final str = domains.join(',');
    await prefs.setString('admin_streamtape_family_domains', str);
    _watchDomains = List<String>.from(domains);
    await _syncDomainsToServer(familyDomainsStr: str);
  }

  static Future<void> resetDomainsToDefault() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('admin_streamtape_api_domains');
    await prefs.remove('admin_streamtape_family_domains');
    _watchDomains = List<String>.from(defaultWatchCdnDomains);
    _apiDomains = List<String>.from(defaultApiDomains);
    await _syncDomainsToServer(
      apiDomainsStr: defaultApiDomains.join(','),
      familyDomainsStr: defaultWatchCdnDomains.join(','),
    );
  }

  static Future<void> _syncDomainsToServer({String? apiDomainsStr, String? familyDomainsStr}) async {
    try {
      final apiStr = apiDomainsStr ?? _apiDomains.join(',');
      final familyStr = familyDomainsStr ?? _watchDomains.join(',');

      final body = {
        'action': 'save_app_settings',
        'settings': {
          'streamtape_api_domains': apiStr,
          'streamtape_family_domains': familyStr,
        }
      };

      await http.post(
        Uri.parse(ApiConfig.adminUrl),
        body: json.encode(body),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 8));
    } catch (_) {}
  }

  static bool isStreamtapeFamily(String url) {
    if (url.isEmpty) return false;
    final lower = url.toLowerCase();
    
    // Check main patterns
    if (lower.contains('streamtape') ||
        lower.contains('tapecontent') ||
        lower.contains('strcloud') ||
        lower.contains('strcolud') ||
        lower.contains('stape') ||
        lower.contains('streamta.pe') ||
        lower.contains('advtpe') ||
        lower.contains('advtape') ||
        lower.contains('adtape') ||
        lower.contains('shavetape') ||
        lower.contains('adblocktape') ||
        lower.contains('tpead') ||
        lower.contains('tapepops')) {
      return true;
    }

    // Check custom domains dynamically loaded in memory
    for (final domain in _watchDomains) {
      if (lower.contains(domain.toLowerCase())) return true;
    }
    for (final domain in _apiDomains) {
      if (lower.contains(domain.toLowerCase())) return true;
    }
    return false;
  }

  static String? extractFileId(String url) {
    if (url.isEmpty) return null;
    var match = RegExp(r'/v/([a-zA-Z0-9_-]+)', caseSensitive: false).firstMatch(url);
    if (match != null) return match.group(1);
    match = RegExp(r'/e/([a-zA-Z0-9_-]+)', caseSensitive: false).firstMatch(url);
    if (match != null) return match.group(1);
    match = RegExp(r'/[vef]/([a-zA-Z0-9_-]+)', caseSensitive: false).firstMatch(url);
    return match?.group(1);
  }

  static bool isDirectMediaUrl(String url) => _isDirectMedia(url);

  static bool _isDirectMedia(String url) {
    final lower = url.toLowerCase();
    if (isStreamtapeFamily(url) && !lower.contains('/radosgw/') && !lower.endsWith('.mp4')) {
      return false;
    }

    return lower.endsWith('.mp4') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.m4v') ||
        lower.endsWith('.mov') ||
        lower.contains('.m3u8') ||
        lower.contains('/hls/') ||
        lower.contains('/radosgw/') ||
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
      debugPrint("Streamtape direct URL served from cache: ${_urlCache[streamtapeUrl]}");
      return _urlCache[streamtapeUrl];
    }

    await init(); // Ensure custom dynamic domains are loaded

    final fileId = extractFileId(streamtapeUrl);
    if (fileId == null) return null;

    // LAYER 1: Javascript Substring Evaluator on Streamtape Mirror Pages
    final searchDomains = _watchDomains.isNotEmpty ? _watchDomains : defaultWatchCdnDomains;
    for (final domain in searchDomains) {
      try {
        final pageUrl = 'https://$domain/v/$fileId';
        final res = await _getFast(pageUrl);
        if (res.statusCode == 200) {
          final html = res.body;
          final match = RegExp(
            r"norobotlink'\)\.innerHTML\s*=\s*[\x22\x27]([^\x22\x27]+)[\x22\x27]\s*\+\s*\(\s*[\x22\x27]([^\x22\x27]+)[\x22\x27]\s*\)([^;]+)",
            caseSensitive: false,
          ).firstMatch(html);

          if (match != null) {
            String prefix = match.group(1)!;
            String tokenPart = match.group(2)!;
            String chain = match.group(3)!;

            final subs = RegExp(r'substring\s*\(\s*(\d+)\s*\)').allMatches(chain);
            for (final m in subs) {
              int sub = int.tryParse(m.group(1)!) ?? 0;
              if (sub > 0 && sub < tokenPart.length) {
                tokenPart = tokenPart.substring(sub);
              }
            }

            String fullPath = prefix + tokenPart;
            if (fullPath.startsWith('//')) {
              fullPath = 'https:$fullPath';
            } else if (!fullPath.startsWith('http')) {
              fullPath = 'https://$domain$fullPath';
            }

            if (!fullPath.contains('stream=1')) {
              fullPath += fullPath.contains('?') ? '&stream=1' : '?stream=1';
            }

            // Follow redirect to resolve direct CDN video URL (tapecontent.net/radosgw/...)
            final redirectUrl = await _resolveRedirectUrl(fullPath, 'https://$domain/v/$fileId');
            final finalMediaUrl = redirectUrl ?? fullPath;
            debugPrint("Resolved Direct Streamtape Video URL ($domain): $finalMediaUrl");
            _urlCache[streamtapeUrl] = finalMediaUrl;
            return finalMediaUrl;
          }
        }
      } catch (e) {
        debugPrint("Error scraping Streamtape via $domain: $e");
      }
    }

    // LAYER 2: Backend PHP resolver fallback
    try {
      final response = await _getFast("${ApiConfig.baseUrl}/streamtape_resolver.php?url=${Uri.encodeComponent(streamtapeUrl)}");
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && data['data']?['stream_url'] != null) {
          String url = data['data']['stream_url'].toString().trim();
          if (url.startsWith('http')) {
            if (!url.contains('stream=1')) {
              url += url.contains('?') ? '&stream=1' : '?stream=1';
            }
            if (url.contains('#')) {
              url = url.split('#')[0];
            }
            debugPrint("Resolved stream URL from backend fallback: $url");
            _urlCache[streamtapeUrl] = url;
            return url;
          }
        }
      }
    } catch (_) {}

    return null;
  }

  static Future<String?> _resolveRedirectUrl(String targetUrl, String referer) async {
    final ioClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 6)
      ..badCertificateCallback = (cert, host, port) => true;
    try {
      final req = await ioClient.getUrl(Uri.parse(targetUrl));
      req.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
      req.headers.set('Referer', referer);
      req.followRedirects = false; // Capture HTTP 302 location header directly!
      final resp = await req.close().timeout(const Duration(seconds: 6));
      final redirectUrl = resp.headers.value('location') ?? resp.headers.value('content-location');
      if (redirectUrl != null && redirectUrl.startsWith('http')) {
        return redirectUrl;
      }
      if (resp.statusCode == 200) {
        return targetUrl;
      }
    } catch (_) {} finally {
      ioClient.close();
    }
    return null;
  }

  static Future<http.Response> _getFast(String fetchUrl) async {
    final ioClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 6)
      ..badCertificateCallback = (cert, host, port) => true;
    final client = IOClient(ioClient);
    try {
      return await client.get(
        Uri.parse(fetchUrl),
        headers: {
          'Connection': 'close',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
      ).timeout(const Duration(seconds: 6));
    } finally {
      client.close();
    }
  }
}
