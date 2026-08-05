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

  Future<List<String>> _resolveHostList(String host) async {
    final cleanHost = host.trim().toLowerCase();
    if (cleanHost == '127.0.0.1' ||
        cleanHost == 'localhost' ||
        cleanHost == '::1') {
      return ['127.0.0.1'];
    }
    if (InternetAddress.tryParse(cleanHost) != null) {
      return [cleanHost];
    }

    final List<String> ips = [];

    // System DNS
    try {
      final list = await InternetAddress.lookup(host)
          .timeout(const Duration(seconds: 2));
      for (final addr in list) {
        final ip = addr.address;
        if (ip != '0.0.0.0' && ip != '::') {
          ips.add(ip);
        }
      }
    } catch (_) {}

    // Cloudflare DoH
    if (ips.isEmpty) {
      try {
        final uri =
            Uri.parse('https://cloudflare-dns.com/dns-query?name=$host&type=A');
        final client = HttpClient();
        client.badCertificateCallback = (cert, h, p) => true;
        final req = await client.getUrl(uri);
        req.headers.set('Accept', 'application/dns-json');
        final resp = await req.close().timeout(const Duration(seconds: 4));
        if (resp.statusCode == 200) {
          final body = await resp.transform(utf8.decoder).join();
          final data = jsonDecode(body);
          final answers = data['Answer'] as List?;
          if (answers != null) {
            for (final ans in answers) {
              if (ans['type'] == 1 && ans['data'] != null) {
                ips.add(ans['data'].toString());
              }
            }
          }
        }
        client.close();
      } catch (_) {}
    }

    // Google DoH
    if (ips.isEmpty) {
      try {
        final uri = Uri.parse('https://dns.google/resolve?name=$host&type=A');
        final client = HttpClient();
        client.badCertificateCallback = (cert, h, p) => true;
        final req = await client.getUrl(uri);
        final resp = await req.close().timeout(const Duration(seconds: 4));
        if (resp.statusCode == 200) {
          final body = await resp.transform(utf8.decoder).join();
          final data = jsonDecode(body);
          final answers = data['Answer'] as List?;
          if (answers != null) {
            for (final ans in answers) {
              if (ans['type'] == 1 && ans['data'] != null) {
                ips.add(ans['data'].toString());
              }
            }
          }
        }
        client.close();
      } catch (_) {}
    }

    if (ips.isNotEmpty) {
      debugPrint('CustomDnsProxy resolved $host -> $ips');
      return ips;
    }
    throw Exception('Failed to resolve host $host');
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
    var authority = request.uri.authority.isNotEmpty
        ? request.uri.authority
        : (request.headers.value('host') ?? '');
    if (authority.isEmpty) {
      request.response.statusCode = 400;
      await request.response.close();
      return;
    }
    final parts = authority.split(':');
    final host = parts[0];
    final portVal = parts.length > 1 ? int.parse(parts[1]) : 443;

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
  ];

  @override
  String findProxyFromEnvironment(Uri uri, Map<String, String>? environment) {
    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();

    // Direct video content streams MUST ALWAYS be DIRECT (0 proxy socket overhead)
    if (path.contains('get_video') ||
        host.contains('tapecontent') ||
        uri.path.endsWith('.mp4') ||
        uri.path.endsWith('.mkv')) {
      return 'DIRECT';
    }

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
