import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

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

  /// Extracts direct HLS (.m3u8) stream URL for Filemoon / Byse links.
  /// Prioritizes on-device AES-256-GCM decryption so the generated token is bound
  /// to the device's own IP & ASN (preventing 404 - SprintCDN errors).
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

    final fileCode = extractFileCode(trimmed);
    if (fileCode != null && fileCode.isNotEmpty) {
      // 1. Direct on-device AES-256-GCM resolution (generates token bound to THIS device's IP & ASN!)
      for (final domain in ['bysezoxexe.com', 'filemoon.to', 'filemoon.sx']) {
        try {
          final client = HttpClient()..badCertificateCallback = (c, h, p) => true;
          client.connectionTimeout = const Duration(seconds: 8);
          final req = await client.getUrl(Uri.parse('https://$domain/api/videos/$fileCode/'));
          req.headers.set('Referer', 'https://$domain/e/$fileCode');
          req.headers.set('X-Requested-With', 'XMLHttpRequest');
          req.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36');
          final resp = await req.close().timeout(const Duration(seconds: 8));
          if (resp.statusCode == 200) {
            final body = await utf8.decodeStream(resp);
            final json = jsonDecode(body);
            if (json['playback'] != null && json['playback']['payload'] != null) {
              final pb = json['playback'];
              final ivB64 = pb['iv'] as String?;
              final payloadB64 = pb['payload'] as String?;
              final keyParts = pb['key_parts'] as List?;
              final version = int.tryParse(pb['version']?.toString() ?? '0') ?? 0;

              if (ivB64 != null && payloadB64 != null && keyParts != null && version > 0) {
                List<int> b64urlDecode(String str) {
                  var norm = str.replaceAll('-', '+').replaceAll('_', '/');
                  while (norm.length % 4 != 0) {
                    norm += '=';
                  }
                  return base64Decode(norm);
                }

                final iv = b64urlDecode(ivB64);
                final payload = b64urlDecode(payloadB64);
                final k1 = b64urlDecode(keyParts[version - 1].toString());
                final k2 = b64urlDecode(keyParts[31 - version - 1].toString());
                final keyBytes = [...k1, ...k2];

                if (payload.length > 16 && keyBytes.length == 32) {
                  final tag = payload.sublist(payload.length - 16);
                  final ciphertext = payload.sublist(0, payload.length - 16);

                  final algorithm = AesGcm.with256bits();
                  final secretKey = SecretKey(keyBytes);
                  final secretBox = SecretBox(ciphertext, nonce: iv, mac: Mac(tag));
                  final decrypted = await algorithm.decrypt(secretBox, secretKey: secretKey);
                  final decryptedStr = utf8.decode(decrypted);
                  final decJson = jsonDecode(decryptedStr);
                  if (decJson['sources'] is List && (decJson['sources'] as List).isNotEmpty) {
                    final streamUrl = decJson['sources'][0]['url']?.toString();
                    if (streamUrl != null && streamUrl.isNotEmpty) {
                      debugPrint("Filemoon on-device AES-256-GCM decrypted stream: $streamUrl");
                      _cache[trimmed] = streamUrl;
                      _cacheTime[trimmed] = DateTime.now();
                      return streamUrl;
                    }
                  }
                }
              }
            }
          }
          client.close();
        } catch (e) {
          debugPrint("Filemoon on-device resolution error on $domain: $e");
        }
      }
    }

    // 2. Direct on-device HTML embed parsing fallback (for legacy packer pages)
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

    // 3. Fallback: Backend Admin API endpoint
    try {
      final res = await http.post(
        Uri.parse(ApiConfig.adminUrl),
        body: json.encode({
          'action': 'resolve_server_stream',
          'url': trimmed,
        }),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 8));

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

    return null;
  }
}
