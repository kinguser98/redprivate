import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../widgets/resolving_dialog.dart';

class EmbedResolver {
  static final Map<String, String> _cache = {};

  static bool _isValidVideoResource(Uri? uri) {
    if (uri == null) return false;
    final urlStr = uri.toString();
    final lower = urlStr.toLowerCase();
    
    final path = uri.path.toLowerCase();
    if (path.endsWith('.js') ||
        path.endsWith('.css') ||
        path.endsWith('.png') ||
        path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.gif') ||
        path.endsWith('.json') ||
        path.endsWith('.html')) {
      return false;
    }
    
    if (lower.contains('analytics') ||
        lower.contains('doubleclick') ||
        lower.contains('telemetry') ||
        lower.contains('hls.js') ||
        lower.contains('video.js') ||
        lower.contains('/ads/') ||
        lower.contains('adserver') ||
        lower.contains('conermoocher') ||
        lower.contains('popads')) {
      return false;
    }
    
    return lower.contains('.m3u8') ||
           lower.contains('.mp4') ||
           lower.contains('/stream/') ||
           lower.contains('.mkv') ||
           lower.contains('get_video') ||
           lower.contains('tapecontent.net');
  }

  /// Resolves an embed page URL to its direct media streaming URL (.mp4/.mkv/tapecontent.net)
  /// using a background HeadlessInAppWebView to intercept network requests.
  static Future<String?> resolve(BuildContext context, String rawUrl) async {
    if (rawUrl.isEmpty) return null;

    if (_cache.containsKey(rawUrl)) {
      print("EmbedResolver: Loaded from cache: ${_cache[rawUrl]}");
      return _cache[rawUrl];
    }

    if (rawUrl.endsWith('.mp4') ||
        rawUrl.endsWith('.mkv') ||
        rawUrl.contains('tapecontent.net') ||
        rawUrl.contains('vercel.app') ||
        rawUrl.contains('raw/')) {
      _cache[rawUrl] = rawUrl;
      return rawUrl;
    }

    final embedUrl = rawUrl.replaceAll(RegExp(r'/(?:v|f)/'), '/e/');
    final completer = Completer<String?>();
    bool dialogOpen = true;
    HeadlessInAppWebView? headlessWebView;

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return PopScope(
          canPop: true,
          onPopInvokedWithResult: (didPop, result) {
            dialogOpen = false;
            if (!completer.isCompleted) {
              completer.complete(null);
            }
          },
          child: const ResolvingProgressDialog(
            title: 'RESOLVING STREAM LINK',
            subtitle: 'Generating phone-authenticated stream...',
          ),
        );
      },
    ).then((_) {
      dialogOpen = false;
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });

    void closeDialogIfOpen() {
      if (dialogOpen) {
        dialogOpen = false;
        try {
          if (Navigator.of(context, rootNavigator: true).canPop()) {
            Navigator.of(context, rootNavigator: true).pop();
          }
        } catch (_) {}
      }
    }

    try {
      headlessWebView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(
          url: WebUri(embedUrl),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          },
        ),
        initialUserScripts: UnmodifiableListView<UserScript>([
          UserScript(
            source: """
              (function() {
                window.open = function() { return null; };
                function simulateClick(el) {
                  try {
                    el.focus();
                    ['mousedown', 'mouseup', 'click'].forEach(function(type) {
                      var e = new MouseEvent(type, {
                        bubbles: true,
                        cancelable: true,
                        view: window,
                        clientX: el.getBoundingClientRect().left + el.clientWidth / 2,
                        clientY: el.getBoundingClientRect().top + el.clientHeight / 2
                      });
                      el.dispatchEvent(e);
                    });
                  } catch(e) {}
                }

                var checkVideo = setInterval(function() {
                  try {
                    var vids = document.querySelectorAll('video');
                    vids.forEach(function(v) {
                      if (v.src && v.src.startsWith('http') && !v.src.startsWith('blob:')) {
                        clearInterval(checkVideo);
                        window.flutter_inappwebview.callHandler('videoFound', v.src);
                      }
                    });
                  } catch(e) {}
                }, 500);

                var count = 0;
                var interval = setInterval(function() {
                  count++;
                  if (count > 20) {
                    clearInterval(interval);
                    return;
                  }
                  ['.vjs-big-play-button', '#robotlink', '#norobotlink', '#ideoolink', '#ideoooolink', '#captchalink', '.play-button', '#play', '.play'].forEach(function(sel) {
                    try {
                      document.querySelectorAll(sel).forEach(function(el) { simulateClick(el); });
                    } catch(e) {}
                  });
                }, 400);
              })();
            """,
            injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
            forMainFrameOnly: false,
          )
        ]),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          domStorageEnabled: true,
          supportMultipleWindows: false,
          javaScriptCanOpenWindowsAutomatically: false,
          mediaPlaybackRequiresUserGesture: false,
          allowsInlineMediaPlayback: true,
          mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
        ),
        onWebViewCreated: (controller) {
          controller.addJavaScriptHandler(
            handlerName: 'videoFound',
            callback: (args) {
              if (args.isNotEmpty) {
                final String urlStr = args[0].toString();
                if (!completer.isCompleted) {
                  _cache[rawUrl] = urlStr;
                  completer.complete(urlStr);
                  closeDialogIfOpen();
                }
              }
            },
          );
        },
        shouldOverrideUrlLoading: (controller, navigationAction) async {
          final url = navigationAction.request.url?.toString() ?? '';
          final lower = url.toLowerCase();
          if (lower.contains('conermoocher') || 
              lower.contains('adserver') || 
              lower.contains('popads') || 
              lower.contains('exoclick') || 
              lower.contains('adsterra') ||
              lower.contains('redirect')) {
            return NavigationActionPolicy.CANCEL;
          }
          return NavigationActionPolicy.ALLOW;
        },
        onLoadResource: (controller, resource) {
          final urlStr = resource.url?.toString() ?? '';
          if (_isValidVideoResource(resource.url)) {
            print('EmbedResolver: Found direct video URL: $urlStr');
            if (!completer.isCompleted) {
              _cache[rawUrl] = urlStr;
              completer.complete(urlStr);
              closeDialogIfOpen();
            }
          }
        },
      );

      await headlessWebView.run();

      final result = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          closeDialogIfOpen();
          return null;
        },
      );

      closeDialogIfOpen();
      return result;
    } catch (e) {
      print('EmbedResolver error: $e');
      closeDialogIfOpen();
      return null;
    } finally {
      closeDialogIfOpen();
      await headlessWebView?.dispose();
    }
  }
}
