import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// In-app browser for Cambaddies live cams. The site is loaded as a normal
/// web page (no scraping) — users browse the model grid and the site's own
/// player streams the live cam. Portrait only.
class LiveCamsScreen extends StatefulWidget {
  const LiveCamsScreen({Key? key}) : super(key: key);

  @override
  State<LiveCamsScreen> createState() => _LiveCamsScreenState();
}

class _LiveCamsScreenState extends State<LiveCamsScreen> {
  InAppWebViewController? _webViewController;
  bool _isLoading = true;
  bool _useDesktopUa = false;
  String? _errorMessage;

  static const String _iosMobileUa =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1';
  static const String _iosDesktopUa =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15';

  static const String _androidMobileUa =
      'Mozilla/5.0 (Linux; Android 13; SM-G991B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';
  static const String _androidDesktopUa =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }

  @override
  void dispose() {
    _webViewController?.pause();
    super.dispose();
  }

  String get _ua {
    if (Platform.isIOS) {
      return _useDesktopUa ? _iosDesktopUa : _iosMobileUa;
    }
    return _useDesktopUa ? _androidDesktopUa : _androidMobileUa;
  }

  Future<void> _reload({bool toggleUa = false}) async {
    if (toggleUa) {
      setState(() {
        _useDesktopUa = !_useDesktopUa;
        _errorMessage = null;
      });
      await _webViewController?.setSettings(
        settings: InAppWebViewSettings(userAgent: _ua),
      );
    } else {
      setState(() => _errorMessage = null);
    }
    await _webViewController?.reload();
  }

  Future<bool> _handleBack() async {
    final controller = _webViewController;
    if (controller != null) {
      final canGoBack = await controller.canGoBack();
      if (canGoBack) {
        await controller.goBack();
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _handleBack();
        if (!mounted) return;
        if (shouldPop) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              // The site itself.
              InAppWebView(
                initialUrlRequest: URLRequest(
                  url: WebUri('https://www.cambaddies.com'),
                  headers: {
                    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
                    'Accept-Language': 'en-US,en;q=0.9',
                    'Upgrade-Insecure-Requests': '1',
                  },
                ),
                initialUserScripts: UnmodifiableListView<UserScript>([
                  UserScript(
                    source: _browserScript,
                    injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
                    forMainFrameOnly: false,
                  ),
                ]),
                initialSettings: InAppWebViewSettings(
                  userAgent: _ua,
                  javaScriptEnabled: true,
                  domStorageEnabled: true,
                  supportMultipleWindows: false,
                  javaScriptCanOpenWindowsAutomatically: false,
                  mediaPlaybackRequiresUserGesture: false,
                  allowsInlineMediaPlayback: true,
                  allowsAirPlayForMediaPlayback: true,
                  allowsBackForwardNavigationGestures: true,
                  isFraudulentWebsiteWarningEnabled: false,
                  transparentBackground: false,
                  useOnDownloadStart: true,
                  mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                ),
                onWebViewCreated: (controller) {
                  _webViewController = controller;
                },
                onCreateWindow: (controller, createWindowRequest) async {
                  // Never open popups / popunders.
                  return true;
                },
                onLoadStart: (controller, url) {
                  if (mounted) {
                    setState(() {
                      _isLoading = true;
                      _errorMessage = null;
                    });
                  }
                },
                onLoadStop: (controller, url) {
                  if (mounted) setState(() => _isLoading = false);
                },
                onProgressChanged: (controller, progress) {
                  if (progress >= 100 && mounted) {
                    setState(() => _isLoading = false);
                  }
                },
                onReceivedError: (controller, request, error) {
                  if (request.isForMainFrame ?? true) {
                    if (mounted) {
                      setState(() {
                        _isLoading = false;
                        _errorMessage = error.description;
                      });
                    }
                  }
                },
                onReceivedHttpError: (controller, request, errorResponse) {
                  if (request.isForMainFrame ?? true) {
                    if (errorResponse.statusCode != null && errorResponse.statusCode! >= 400) {
                      if (mounted) {
                        setState(() {
                          _isLoading = false;
                          _errorMessage = "HTTP ${errorResponse.statusCode}: ${errorResponse.reasonPhrase ?? 'Error'}";
                        });
                      }
                    }
                  }
                },
                shouldOverrideUrlLoading: (controller, navigationAction) async {
                  final url = navigationAction.request.url?.toString() ?? '';
                  final lower = url.toLowerCase();
                  if (_isAdUrl(lower)) {
                    return NavigationActionPolicy.CANCEL;
                  }
                  return NavigationActionPolicy.ALLOW;
                },
              ),

              // Loading spinner.
              if (_isLoading && _errorMessage == null)
                const Center(
                  child: CircularProgressIndicator(color: Color(0xFF00C6FF)),
                ),

              // Error display with retry
              if (_errorMessage != null)
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161B26),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.wifi_off_rounded, color: Colors.orangeAccent, size: 48),
                        const SizedBox(height: 12),
                        const Text(
                          "Failed to Load Cambaddies",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _reload(),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text("Retry"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00C6FF),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Top bar: back, title, UA toggle, reload.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      _barButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () async {
                          final shouldPop = await _handleBack();
                          if (!mounted) return;
                          if (shouldPop) Navigator.of(context).pop();
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.videocam_rounded, color: Color(0xFF00C6FF), size: 18),
                              SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Live Cams',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _barButton(
                        icon: _useDesktopUa ? Icons.smartphone_rounded : Icons.desktop_windows_rounded,
                        tooltip: _useDesktopUa ? 'Mobile view' : 'Desktop view',
                        onTap: () => _reload(toggleUa: true),
                      ),
                      const SizedBox(width: 8),
                      _barButton(
                        icon: Icons.refresh_rounded,
                        onTap: () => _reload(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _barButton({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white12),
        ),
        child: Tooltip(
          message: tooltip ?? '',
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  bool _isAdUrl(String lower) {
    const adMarkers = [
      'conermoocher',
      'popads',
      'popunder',
      'exoclick',
      'adsterra',
      'adserver',
      'adservice.google',
      'doubleclick',
      'googlesyndication',
      'googleadservices',
      'taboola',
      'outbrain',
      'propellerads',
      'onclck',
      'adsrvr',
      'adnxs',
      'criteo',
      'adform',
      'pubmatic',
      'advertising',
    ];
    for (final marker in adMarkers) {
      if (lower.contains(marker)) return true;
    }
    return false;
  }

  static const String _browserScript = r'''
    (function() {
      // Kill popups / popunders.
      window.open = function() { return null; };

      // Auto-dismiss the age gate + cookie consent banner on first load.
      var _clicked = {};
      function _visible(el) {
        try { return !!(el.offsetWidth || el.offsetHeight || el.getClientRects().length); } catch (e) { return false; }
      }
      function _clickText(re) {
        var els = document.querySelectorAll('button, a, [role="button"], input[type="button"], input[type="submit"], .btn');
        for (var i = 0; i < els.length; i++) {
          var el = els[i];
          var t = (el.innerText || el.textContent || el.value || '').trim();
          if (t && _visible(el) && re.test(t)) {
            var k = t.toLowerCase().slice(0, 48);
            if (!_clicked[k]) { _clicked[k] = true; try { el.click(); } catch (e) {} }
          }
        }
      }
      var _t = 0;
      var _iv = setInterval(function() {
        _t++;
        _clickText(/(over\s*18|i\s*'?m\s*18|enter the site|enter site|continue|accept all|accept cookies|agree|got it|i understand|confirm my age)/i);
        if (_t >= 30) clearInterval(_iv);
      }, 1000);
    })();
  ''';
}
