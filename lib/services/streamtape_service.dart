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
    'strcloud.link',
    'streamta.pe',
    'stape.fun',
    'adblocktape.fun',
    'advtpe.com',
    'tpead.net',
    'advtape.com',
    'shavetape.cash',
    'tapepops.com',
    'streamtape.to',
    'streamtape.com',
    'streamtape.xyz',
    'tapecontent.net',
  ];

  static const List<String> defaultApiDomains = [
    'api.streamtape.to',
    'api.streamtape.com',
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
  }

  static Future<void> saveFamilyDomains(List<String> domains) async {
    final prefs = await SharedPreferences.getInstance();
    final str = domains.join(',');
    await prefs.setString('admin_streamtape_family_domains', str);
    _watchDomains = List<String>.from(domains);
  }

  static Future<void> resetDomainsToDefault() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('admin_streamtape_api_domains');
    await prefs.remove('admin_streamtape_family_domains');
    _watchDomains = List<String>.from(defaultWatchCdnDomains);
    _apiDomains = List<String>.from(defaultApiDomains);
  }

  static bool isStreamtapeFamily(String url) {
    if (url.isEmpty) return false;
    final lower = url.toLowerCase();
    
    if (lower.contains('streamtape') ||
        lower.contains('streamta.pe') ||
        lower.contains('strcloud') ||
        lower.contains('strcolud') ||
        lower.contains('tapecontent') ||
        lower.contains('stape.fun') ||
        lower.contains('shavetape') ||
        lower.contains('advtpe') ||
        lower.contains('advtape') ||
        lower.contains('adblocktape') ||
        lower.contains('tpead') ||
        lower.contains('tapepops')) {
      return true;
    }

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
    if (lower.contains('luluvdo') || lower.contains('lulustream') || lower.contains('uplinks')) {
      return false;
    }
    // Streamtape web pages (/v/, /e/, /f/) are NEVER direct media, even if they end in .mp4 or .mkv
    if (isStreamtapeFamily(url)) {
      if (lower.contains('get_video') || lower.contains('/radosgw/') || lower.contains('/ep?u=')) {
        return true;
      }
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
        lower.contains('fpo_stream.php') ||
        lower.contains('fpo') ||
        lower.contains('vercel.app') ||
        lower.contains('archive.org') ||
        lower.contains('koyeb.app');
  }

  static Future<String?> getDirectStreamUrl(String streamtapeUrl, {bool forceRefresh = false}) async {
    if (streamtapeUrl.isEmpty) return null;

    final lower = streamtapeUrl.toLowerCase();
    if (lower.contains('luluvdo') || lower.contains('lulustream') || lower.contains('lulucdn')) {
      return null;
    }

    if (_isDirectMedia(streamtapeUrl)) {
      _urlCache[streamtapeUrl] = streamtapeUrl;
      return streamtapeUrl;
    }

    if (!forceRefresh && _urlCache.containsKey(streamtapeUrl)) {
      debugPrint("Streamtape direct URL served from cache: ${_urlCache[streamtapeUrl]}");
      return _urlCache[streamtapeUrl];
    }

    await init();

    final fileId = extractFileId(streamtapeUrl);
    if (fileId == null) return null;

    // Fast unblocked mirror domains prioritized for Indian ISPs & global access
    final searchDomains = [
      'strcloud.link',
      'streamta.pe',
      'stape.fun',
      'adblocktape.fun',
      'advtpe.com',
      'tpead.net',
      'streamtape.to',
      ...(_watchDomains.isNotEmpty ? _watchDomains : defaultWatchCdnDomains)
    ];

    for (final domain in searchDomains) {
      try {
        final pageUrl = 'https://$domain/v/$fileId';
        final res = await http.get(Uri.parse(pageUrl), headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        }).timeout(const Duration(seconds: 6));

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

            // Replace streamtape.com with unblocked mirror domain
            fullPath = fullPath.replaceAll('streamtape.com', domain);

            if (!fullPath.contains('stream=1')) {
              fullPath += fullPath.contains('?') ? '&stream=1' : '?stream=1';
            }

            debugPrint("Resolved Direct Stream URL ($domain): $fullPath");
            _urlCache[streamtapeUrl] = fullPath;
            return fullPath;
          }
        }
      } catch (e) {
        debugPrint("Error scraping Streamtape via $domain: $e");
      }
    }

    return null;
  }
}
