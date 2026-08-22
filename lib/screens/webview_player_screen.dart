import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class WebViewPlayerScreen extends StatefulWidget {
  final String embedUrl;
  final String videoTitle;

  const WebViewPlayerScreen({
    Key? key,
    required this.embedUrl,
    required this.videoTitle,
  }) : super(key: key);

  @override
  State<WebViewPlayerScreen> createState() => _WebViewPlayerScreenState();
}

class _WebViewPlayerScreenState extends State<WebViewPlayerScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cleanEmbedUrl = widget.embedUrl
        .replaceAll('/v/', '/e/')
        .replaceAll('/watch/', '/embed/');

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Fullscreen InAppWebView Player
          InAppWebView(
            initialUrlRequest: URLRequest(
              url: WebUri(cleanEmbedUrl),
              headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
              },
            ),
            initialUserScripts: UnmodifiableListView<UserScript>([
              UserScript(
                source: """
                  (function() {
                    window.open = function() { return null; };
                    
                    function autoPlayVideo() {
                      try {
                        if (window.jwplayer && typeof window.jwplayer === 'function') {
                          try { window.jwplayer().play(); } catch(e) {}
                        }
                        var v = document.querySelector('video');
                        if (v) {
                          v.play().catch(function(e) {});
                          v.setAttribute('controls', 'true');
                          v.style.width = '100vw';
                          v.style.height = '100vh';
                          v.style.objectFit = 'contain';
                        }
                      } catch(e) {}
                    }

                    var timer = setInterval(function() {
                      autoPlayVideo();
                      ['.jw-display-icon-container', '.jw-icon-display', '.vjs-big-play-button', '#robotlink', '.play-button', '#play'].forEach(function(s) {
                        try {
                          var el = document.querySelector(s);
                          if (el) el.click();
                        } catch(e) {}
                      });
                    }, 400);

                    setTimeout(function() { clearInterval(timer); }, 12000);
                  })();
                """,
                injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
                forMainFrameOnly: false,
              ),
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
              _webViewController = controller;
            },
            onLoadStop: (controller, url) async {
              setState(() => _isLoading = false);
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
          ),

          // Loading Spinner
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFFE50914)),
            ),

          // Top Header Overlay with Back Button & Title
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.videoTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
