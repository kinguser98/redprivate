import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Loads a URL in a background [HeadlessInAppWebView] (real Chromium / WebKit
/// engine), runs injected JS, and returns the JSON string posted back through
/// [handlerName]. Because the page runs in a genuine browser engine, Cloudflare
/// "Just a moment" challenges auto-solve (JS executes, cookies persist), which
/// plain `dart:io` HttpClient cannot do — so CF-protected hosts like redtube.com
/// and spankbang.com are resolvable on-device this way.
class HeadlessCapture {
  static String get mobileUa {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1';
    }
    return 'Mozilla/5.0 (Linux; Android 13; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.5615.135 Mobile Safari/537.36';
  }

  static void _log(String msg) {
    debugPrint('[HeadlessCapture] $msg');
  }

  /// Runs a headless browser session against [url]. [js] is injected at document
  /// start and end, and must eventually call
  /// `window.flutter_inappwebview.callHandler(handlerName, <JSON string>)`.
  /// Returns the JSON string, or null on timeout/failure.
  static Future<String?> capture(
    String url,
    String handlerName,
    String js, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final completer = Completer<String?>();
    HeadlessInAppWebView? webView;
    final targetUa = mobileUa;
    try {
      webView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(
          url: WebUri(url),
          headers: {'User-Agent': targetUa},
        ),
        initialUserScripts: UnmodifiableListView<UserScript>([
          UserScript(
            source: js,
            injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
            forMainFrameOnly: true,
          ),
          UserScript(
            source: js,
            injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
            forMainFrameOnly: true,
          ),
        ]),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          domStorageEnabled: true,
          thirdPartyCookiesEnabled: true,
          cacheEnabled: true,
          userAgent: targetUa,
          supportMultipleWindows: false,
          javaScriptCanOpenWindowsAutomatically: false,
          mediaPlaybackRequiresUserGesture: false,
          allowsInlineMediaPlayback: true,
          mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
          useShouldOverrideUrlLoading: false,
        ),
        onWebViewCreated: (controller) {
          _log('created for $url');
          controller.addJavaScriptHandler(
            handlerName: handlerName,
            callback: (args) {
              _log('handler fired, args=${args.length}');
              if (!completer.isCompleted && args.isNotEmpty) {
                final s = args.elementAt(0).toString();
                _log('capture result len=${s.length} head=${s.length > 60 ? s.substring(0, 60) : s}');
                completer.complete(s);
              }
            },
          );
        },
        onLoadStart: (controller, u) => _log('loadStart ${u?.toString() ?? '?'}'),
        onLoadStop: (controller, u) => _log('loadStop ${u?.toString() ?? '?'}'),
        onReceivedError: (controller, request, error) =>
            _log('receivedError type=${error.type} desc=${error.description}'),
        onConsoleMessage: (controller, m) =>
            _log('console[${m.messageLevel}] ${m.message}'),
        onProgressChanged: (controller, progress) {
          if (progress % 25 == 0) _log('progress $progress');
        },
      );

      await webView.run();
      _log('webview running');

      final result = await completer.future.timeout(timeout, onTimeout: () {
        _log('TIMEOUT after ${timeout.inSeconds}s');
        return null;
      });
      return result;
    } catch (e) {
      _log('error for $url: $e');
      return null;
    } finally {
      await webView?.dispose();
    }
  }
}