import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class CustomDnsProxy {
  static final CustomDnsProxy _instance = CustomDnsProxy._internal();
  factory CustomDnsProxy() => _instance;
  CustomDnsProxy._internal();

  HttpServer? _server;
  int? port;
  HttpClient? _httpClient;

  HttpClient _getHttpClient() {
    if (_httpClient == null) {
      _httpClient = HttpClient();
      _httpClient!.connectionTimeout = const Duration(seconds: 10);
      _httpClient!.autoUncompress = false;
      _httpClient!.maxConnectionsPerHost = 100;
      _httpClient!.findProxy = (uri) => 'DIRECT';
      _httpClient!.connectionFactory =
          (Uri uri, String? proxyHost, int? proxyPort) async {
        final targetHost = uri.host;
        final targetPort = uri.port;
        final lower = targetHost.toLowerCase();

        if (lower.contains('streamtape') ||
            lower.contains('tapecontent') ||
            lower.contains('strcloud') ||
            lower.contains('stape.fun') ||
            lower.contains('streamta.pe')) {
          final socket = await Socket.connect(targetHost, targetPort)
              .timeout(const Duration(seconds: 5));
          if (uri.scheme == 'https') {
            final secureSocket = await SecureSocket.secure(
              socket,
              host: targetHost,
              context: SecurityContext.defaultContext,
              onBadCertificate: (cert) => true,
            );
            return ConnectionTask.fromSocket(Future.value(secureSocket), () {});
          }
          return ConnectionTask.fromSocket(Future.value(socket), () {});
        }

        final socket = await _connectToHost(targetHost, targetPort);
        if (uri.scheme == 'https') {
          final secureSocket = await SecureSocket.secure(
            socket,
            host: targetHost,
            context: SecurityContext.defaultContext,
            onBadCertificate: (cert) => true,
          );
          return ConnectionTask.fromSocket(Future.value(secureSocket), () {});
        }
        return ConnectionTask.fromSocket(Future.value(socket), () {});
      };
    }
    return _httpClient!;
  }

  Future<void> start() async {
    if (_server != null) return;
    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      port = _server!.port;
      debugPrint('CustomDnsProxy: Started local proxy on port $port');
      _server!.listen((HttpRequest request) async {
        if (request.method == 'CONNECT') {
          await _handleConnect(request);
        } else {
          await _handleHttp(request);
        }
      }, onError: (e) {
        debugPrint('CustomDnsProxy server level error: $e');
      });
    } catch (e) {
      debugPrint('CustomDnsProxy failed to start: $e');
    }
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    port = null;
    _httpClient?.close(force: true);
    _httpClient = null;
    debugPrint('CustomDnsProxy: Stopped');
  }

  static final Map<String, List<String>> _dnsCache = {};

  Future<List<String>> _resolveHostList(String host) async {
    var cleanHost = host.trim().toLowerCase();
    while (cleanHost.startsWith('/')) {
      cleanHost = cleanHost.substring(1);
    }
    if (cleanHost.contains(':')) {
      cleanHost = cleanHost.split(':')[0];
    }
    if (cleanHost == '127.0.0.1' ||
        cleanHost == 'localhost' ||
        cleanHost == '::1') {
      return ['127.0.0.1'];
    }
    if (InternetAddress.tryParse(cleanHost) != null) {
      return [cleanHost];
    }
    if (cleanHost.contains('dropmms')) {
      return [
        '172.67.218.172',
        '104.26.1.182',
        '104.26.2.182',
        '104.21.5.196',
        '104.18.20.12',
        '104.18.21.12',
      ];
    }
    if (cleanHost.contains('streamtape') ||
        cleanHost.contains('tapecontent') ||
        cleanHost.contains('strcloud') ||
        cleanHost.contains('stape')) {
      return ['104.26.1.182', '104.26.2.182'];
    }
    if (cleanHost.contains('luluvdo') ||
        cleanHost.contains('lulustream') ||
        cleanHost.contains('lulucdn')) {
      return ['104.26.6.79', '104.26.7.79', '172.67.68.215', '104.20.19.112', '172.66.167.168'];
    }
    if (_dnsCache.containsKey(cleanHost) && _dnsCache[cleanHost]!.isNotEmpty) {
      return _dnsCache[cleanHost]!;
    }

    final isBlockedDomain = cleanHost.contains('dropmms') ||
        cleanHost.contains('imagetwist') ||
        cleanHost.contains('luluvdo') ||
        cleanHost.contains('lulustream') ||
        cleanHost.contains('tnmr.org') ||
        cleanHost.contains('cdn-tnmr.org') ||
        cleanHost.contains('.tnmr.') ||
        cleanHost.contains('merivo') ||
        cleanHost.contains('vidara') ||
        cleanHost.contains('playmate') ||
        cleanHost.contains('vibevdo') ||
        cleanHost.contains('vidsonic') ||
        cleanHost.contains('eporner') ||
        cleanHost.contains('aagmaal') ||
        cleanHost.contains('hdmaal') ||
        cleanHost.contains('uffmaal');

    final List<String> ips = [];

    // 1. If blocked domain, prioritize direct IP DoH (1.1.1.1 / 8.8.8.8) to bypass ISP DNS sinkholes
    if (isBlockedDomain) {
      await _queryDoH(cleanHost, ips);
    }

    // 2. System DNS lookup (if not already resolved via DoH)
    if (ips.isEmpty) {
      try {
        final list = await InternetAddress.lookup(cleanHost)
            .timeout(const Duration(seconds: 2));
        for (final addr in list) {
          final ip = addr.address;
          if (ip != '0.0.0.0' &&
              ip != '::' &&
              ip != '127.0.0.1' &&
              !ip.startsWith('192.168.') &&
              !ip.startsWith('10.')) {
            ips.add(ip);
          }
        }
      } catch (_) {}
    }

    // 3. Fallback DoH if system DNS was empty
    if (ips.isEmpty) {
      await _queryDoH(cleanHost, ips);
    }

    if (ips.isNotEmpty) {
      _dnsCache[cleanHost] = ips;
      debugPrint('CustomDnsProxy resolved $cleanHost -> $ips');
      return ips;
    }
    throw Exception('Failed to resolve host $host');
  }

  Future<void> _queryDoH(String cleanHost, List<String> ips) async {
    // Cloudflare Direct-IP DoH (1.1.1.1 / 1.0.0.1 - requires no pre-lookup!)
    for (final dohIp in ['1.1.1.1', '1.0.0.1', '8.8.8.8']) {
      try {
        final String url = dohIp == '8.8.8.8'
            ? 'https://8.8.8.8/resolve?name=$cleanHost&type=A'
            : 'https://$dohIp/dns-query?name=$cleanHost&type=A';
        final uri = Uri.parse(url);
        final client = HttpClient()..badCertificateCallback = (cert, h, p) => true;
        final req = await client.getUrl(uri).timeout(const Duration(seconds: 3));
        req.headers.set('Accept', 'application/dns-json');
        final resp = await req.close().timeout(const Duration(seconds: 3));
        if (resp.statusCode == 200) {
          final body = await utf8.decodeStream(resp);
          final data = jsonDecode(body);
          final answers = data['Answer'] as List?;
          if (answers != null) {
            for (final ans in answers) {
              if (ans['data'] != null && !ans['data'].toString().contains(':')) {
                ips.add(ans['data'].toString());
              }
            }
          }
        }
        client.close();
        if (ips.isNotEmpty) return;
      } catch (_) {}
    }
  }

  Future<Socket> _connectToHost(String host, int port) async {
    final ips = await _resolveHostList(host);
    Object? lastError;
    for (final ip in ips) {
      try {
        return await Socket.connect(ip, port)
            .timeout(const Duration(seconds: 5));
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? Exception('Could not connect to $host');
  }

  Future<void> _handleConnect(HttpRequest request) async {
    var rawAuth = request.uri.authority.isNotEmpty
        ? request.uri.authority
        : (request.headers.value('host') ?? request.uri.toString());
    
    while (rawAuth.startsWith('/')) {
      rawAuth = rawAuth.substring(1);
    }

    if (rawAuth.isEmpty) {
      request.response.statusCode = 400;
      await request.response.close();
      return;
    }
    final parts = rawAuth.split(':');
    final host = parts[0].replaceAll('/', '').trim();
    final portVal = parts.length > 1 ? (int.tryParse(parts[1]) ?? 443) : 443;

    Socket? targetSocket;
    Socket? clientSocket;
    try {
      targetSocket = await _connectToHost(host, portVal);
      clientSocket = await request.response.detachSocket();
      clientSocket.write(
          'HTTP/1.1 200 Connection Established\r\nProxy-agent: CustomDnsProxy\r\n\r\n');
      await clientSocket.flush();
      clientSocket.listen(
        (data) {
          try {
            targetSocket?.add(data);
          } catch (_) {
            _cleanup(clientSocket, targetSocket);
          }
        },
        onDone: () {
          try {
            targetSocket?.close();
          } catch (_) {}
        },
        onError: (e) => _cleanup(clientSocket, targetSocket),
      );
      targetSocket.listen(
        (data) {
          try {
            clientSocket?.add(data);
          } catch (_) {
            _cleanup(clientSocket, targetSocket);
          }
        },
        onDone: () {
          try {
            clientSocket?.close();
          } catch (_) {}
        },
        onError: (e) => _cleanup(clientSocket, targetSocket),
      );
    } catch (e) {
      try {
        request.response.statusCode = 502;
        await request.response.close();
      } catch (_) {}
      _cleanup(clientSocket, targetSocket);
    }
  }

  Future<void> _handleHttp(HttpRequest request) async {
    // Universal Media forwarder for DNS-poisoned & Referer-protected media streams.
    if (request.method == 'GET' && request.uri.path == '/ep') {
      await _handleMediaForward(request);
      return;
    }

    final client = _getHttpClient();
    try {
      final host =
          request.headers.value('host')?.split(':')[0] ?? request.uri.host;
      if (host.isEmpty) {
        request.response.statusCode = 400;
        await request.response.close();
        return;
      }

      final req = await client.openUrl(request.method, request.uri);
      req.followRedirects = true;
      request.headers.forEach((name, values) {
        final nameLower = name.toLowerCase();
        if (nameLower != 'host' && nameLower != 'connection') {
          for (final value in values) {
            req.headers.add(name, value);
          }
        }
      });
      req.headers.set('Host', host);
      req.headers.set('Connection', 'close');

      if (request.contentLength > 0) {
        await req.addStream(request);
      }
      final resp = await req.close();

      request.response.statusCode = resp.statusCode;
      if (resp.contentLength != -1) {
        request.response.contentLength = resp.contentLength;
      }
      resp.headers.forEach((name, values) {
        final nameLower = name.toLowerCase();
        if (nameLower != 'connection' &&
            nameLower != 'transfer-encoding' &&
            nameLower != 'content-length') {
          for (final value in values) {
            request.response.headers.add(name, value);
          }
        }
      });
      // Track bytes for ProxyStats data-usage display
      final trackedStream = resp.map((chunk) {
        ProxyStats.addBytes(chunk.length);
        return chunk;
      });
      await request.response.addStream(trackedStream);
      await request.response.close();
    } catch (e) {
      try {
        request.response.statusCode = 502;
        await request.response.close();
      } catch (_) {}
    }
  }

  void _cleanup(Socket? s1, Socket? s2) {
    try {
      s1?.close();
    } catch (_) {}
    try {
      s2?.close();
    } catch (_) {}
  }

  static const String _mediaUa =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  Future<void> _handleMediaForward(HttpRequest request) async {
    final client = _getHttpClient();
    try {
      final target = request.uri.queryParameters['u'] ?? '';
      if (target.isEmpty ||
          !(target.startsWith('https://') || target.startsWith('http://'))) {
        request.response.statusCode = 400;
        await request.response.close();
        return;
      }
      final referer = request.uri.queryParameters['r'] ?? 'https://dropmms.co/';

      final req = await client.getUrl(Uri.parse(target));
      req.followRedirects = true;
      req.headers.set('User-Agent', _mediaUa);
      req.headers.set('Referer', referer);
      req.headers.set('Accept', '*/*');
      req.headers.set('Connection', 'close');
      req.headers.set('Accept-Encoding', 'identity');
      final range = request.headers.value('range');
      if (range != null && range.isNotEmpty) {
        req.headers.set('Range', range);
      }

      final resp = await req.close();

      request.response.statusCode = resp.statusCode;

      resp.headers.forEach((name, values) {
        final nameLower = name.toLowerCase();
        if (nameLower != 'connection' &&
            nameLower != 'transfer-encoding' &&
            nameLower != 'content-length' &&
            nameLower != 'content-encoding' &&
            nameLower != 'content-security-policy' &&
            nameLower != 'set-cookie') {
          for (final value in values) {
            request.response.headers.add(name, value);
          }
        }
      });

      // Handle HLS m3u8 playlist rewriting so all sub-playlists and TS segments route through DoH
      final contentType = resp.headers.contentType?.value ?? '';
      final isM3u8 = target.contains('.m3u8') ||
          contentType.contains('mpegurl') ||
          contentType.contains('application/x-mpegurl');

      if (!isM3u8 && resp.contentLength != -1) {
        request.response.contentLength = resp.contentLength;
      }

      if (isM3u8 && resp.statusCode == 200) {
        // Collect bytes safely - tnmr.org might return gzip despite identity request
        final rawBytes = <int>[];
        await for (final chunk in resp) {
          rawBytes.addAll(chunk);
        }
        late String body;
        try {
          body = utf8.decode(rawBytes);
        } catch (_) {
          try {
            // Try gzip decode as fallback
            final decompressed = GZipCodec().decode(rawBytes);
            body = utf8.decode(decompressed);
          } catch (_) {
            body = String.fromCharCodes(rawBytes);
          }
        }
        final lines = body.split('\n');
        final rewritten = StringBuffer();
        final base = target.substring(0, target.lastIndexOf('/') + 1);

        for (final l in lines) {
          var line = l.trim();
          if (line.isNotEmpty) {
            if (!line.startsWith('#')) {
              String fullSegmentUrl = line.startsWith('http') ? line : base + line;
              final proxiedSegment =
                  'http://127.0.0.1:$port/ep?u=${Uri.encodeComponent(fullSegmentUrl)}&r=${Uri.encodeComponent(referer)}';
              rewritten.writeln(proxiedSegment);
            } else {
              // Rewrite any URI="..." inside tags (like #EXT-X-I-FRAME-STREAM-INF or #EXT-X-KEY)
              if (line.contains('URI="')) {
                line = line.replaceAllMapped(RegExp(r'URI="([^"]+)"'), (m) {
                  final uriVal = m.group(1)!;
                  final fullUri = uriVal.startsWith('http') ? uriVal : base + uriVal;
                  final proxiedUri =
                      'http://127.0.0.1:$port/ep?u=${Uri.encodeComponent(fullUri)}&r=${Uri.encodeComponent(referer)}';
                  return 'URI="$proxiedUri"';
                });
              }
              rewritten.writeln(line);
            }
          } else {
            rewritten.writeln(l);
          }
        }
        final bytes = utf8.encode(rewritten.toString());
        request.response.headers.contentType =
            ContentType('application', 'vnd.apple.mpegurl', charset: 'utf-8');
        request.response.contentLength = bytes.length;
        request.response.add(bytes);
        await request.response.flush();
        await request.response.close();
        return;
      }

      await request.response.addStream(resp);
      await request.response.close();
    } catch (e) {
      debugPrint('CustomDnsProxy media forward error: $e');
      try {
        request.response.statusCode = 502;
        await request.response.close();
      } catch (_) {}
    }
  }
}

/// If [url] points at a DNS-poisoned host or requires custom headers the native player cannot resolve,
/// returns a localhost URL that streams the media through the app's DoH
/// connection with proper headers. Returns null for direct accessible streams.
String? mediaForwardUrlIfNeeded(String url) {
  if (url.contains('/ep?u=')) return null; // already proxied
  final lower = url.toLowerCase();

  final isProtectedHost = lower.contains('eporner') ||
      lower.contains('tnaflix') ||
      lower.contains('fourhoi') ||
      lower.contains('surrit') ||
      lower.contains('tnmr.org') ||
      lower.contains('cdn-tnmr.org') ||
      lower.contains('luluvdo') ||
      lower.contains('lulustream') ||
      lower.contains('lulucdn') ||
      lower.contains('merivo') ||
      lower.contains('vidara') ||
      lower.contains('playmate') ||
      lower.contains('vibevdo') ||
      lower.contains('vidsonic') ||
      lower.contains('streamtape') ||
      lower.contains('tapecontent') ||
      lower.contains('strcloud') ||
      lower.contains('stape') ||
      lower.contains('dropmms') ||
      lower.contains('imagetwist');

  if (!isProtectedHost) return null;

  final p = CustomDnsProxy().port;
  if (p == null) return null;

  String referer = 'https://dropmms.co/';
  if (lower.contains('eporner')) {
    referer = 'https://www.eporner.com/';
  } else if (lower.contains('luluvdo') || lower.contains('lulustream') || lower.contains('tnmr.org') || lower.contains('cdn-tnmr.org') || lower.contains('lulucdn')) {
    referer = 'https://luluvdo.com/';
  } else if (lower.contains('streamtape') || lower.contains('tapecontent') || lower.contains('strcloud') || lower.contains('stape')) {
    referer = 'https://streamtape.com/';
  } else if (lower.contains('merivo') || lower.contains('vidara')) {
    referer = 'https://merivo.fit/';
  } else if (lower.contains('vibevdo')) {
    referer = 'https://vibevdo.xyz/';
  } else if (lower.contains('vidsonic')) {
    referer = 'https://vidsonic.net/';
  }

  return 'http://127.0.0.1:$p/ep?u=${Uri.encodeComponent(url)}&r=${Uri.encodeComponent(referer)}';
}

// ---------------------------------------------------------------------------
// ProxyStats: Real-time network speed & data usage tracking
// ---------------------------------------------------------------------------
class ProxyStats {
  static final speedNotifier = ValueNotifier<double>(0.0);
  static final totalDataNotifier = ValueNotifier<int>(0);

  static int _accumulatedBytes = 0;
  static int _totalBytes = 0;
  static Timer? _timer;

  static void reset() {
    _accumulatedBytes = 0;
    _totalBytes = 0;
    speedNotifier.value = 0.0;
    totalDataNotifier.value = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      speedNotifier.value = _accumulatedBytes.toDouble();
      _accumulatedBytes = 0;
    });
  }

  static void addBytes(int bytes) {
    _accumulatedBytes += bytes;
    _totalBytes += bytes;
    totalDataNotifier.value = _totalBytes;
  }
}

class MyHttpOverrides extends HttpOverrides {
  final int port;
  MyHttpOverrides(this.port);

  static List<String> blocklist = [
    'streamtape',
    'strcloud',
    'tpead.net',
    'tapepops.com',
    'advtpe.com',
    'advtpe.net',
    'tpead.com',
    'eporner',
    'tnaflix',
    'fourhoi',
    'surrit',
    'dropmms',
    'imagetwist',
    'luluvdo',
    'lulustream',
    'lulucdn',
    'tnmr.org',
    'vidara',
    'merivo',
    'playmate',
    'vibevdo',
    'vidsonic',
  ];

  @override
  String findProxyFromEnvironment(Uri uri, Map<String, String>? environment) {
    final host = uri.host.toLowerCase();

    for (final pattern in blocklist) {
      if (host.contains(pattern)) {
        return 'PROXY 127.0.0.1:$port';
      }
    }
    return 'DIRECT';
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}
