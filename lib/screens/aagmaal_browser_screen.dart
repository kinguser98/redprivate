import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'extractor_telegram_dialog.dart';
import 'video_launcher.dart';
import '../services/dropmms_service.dart';
import '../services/streamtape_service.dart';

class AagmaalBrowserScreen extends StatefulWidget {
  final String initialUrl;

  const AagmaalBrowserScreen({
    super.key,
    this.initialUrl = 'https://aagmaal.bz/',
  });

  @override
  State<AagmaalBrowserScreen> createState() => _AagmaalBrowserScreenState();
}

class _AagmaalBrowserScreenState extends State<AagmaalBrowserScreen> {
  InAppWebViewController? _webViewController;
  bool _isLoading = false;
  double _progress = 0;
  String _currentUrl = 'https://aagmaal.bz/';
  String _currentTitle = 'AAGMaal.bz Cinema';
  bool _isPostPage = false;
  List<Map<String, String>> _detectedStreams = [];

  final List<String> _history = [];
  int _historyIndex = -1;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.initialUrl;
    _history.add(_currentUrl);
    _historyIndex = 0;
  }

  // Detect if the URL is a post/video page on aagmaal.bz
  bool _checkIsPost(String url) {
    if (url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final path = uri.path;
    if (path == '/' || path.isEmpty || path.startsWith('/page/') || path.startsWith('/category/') || path.startsWith('/tag/') || path.contains('?s=')) {
      return false;
    }
    return path.length > 3;
  }

  // Sniff video streams from aagmaal.bz post HTML
  Future<void> _sniffPostStreams(String postUrl) async {
    try {
      final res = await http.get(
        Uri.parse(postUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          'Referer': 'https://aagmaal.bz/',
        },
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final html = res.body;
        final streams = <Map<String, String>>[];
        final seen = <String>{};

        // Extract title
        final titleMatch = RegExp(r'<h1[^>]*>(.*?)</h1>', caseSensitive: false, dotAll: true).firstMatch(html);
        if (titleMatch != null) {
          final t = titleMatch.group(1)!.replaceAll(RegExp(r'<[^>]*>'), '').trim();
          if (t.isNotEmpty) {
            setState(() {
              _currentTitle = t.replaceAll(' | Watch Now', '').replaceAll(' - Watch Free Now', '').trim();
            });
          }
        }

        // 1. Scan all <a> server links (tpead.net, streamtape, advtpe, luluvdo, playmogo, cdn1)
        final aMatches = RegExp(r'<a[^>]+href=["\x27](https?://[^"\x27]+)["\x27][^>]*>(.*?)</a>', caseSensitive: false, dotAll: true).allMatches(html);
        for (final m in aMatches) {
          final href = m.group(1)?.trim() ?? '';
          final text = m.group(2)?.replaceAll(RegExp(r'<[^>]*>'), '').trim() ?? '';
          
          if (href.isNotEmpty && !seen.contains(href)) {
            final low = href.toLowerCase();
            if (low.contains('tpead.net') || low.contains('streamtape') || low.contains('advtpe') ||
                low.contains('tapepops') || low.contains('luluvdo') || low.contains('playmogo') ||
                low.contains('cdn1.site') || low.contains('strcloud') || low.contains('dood')) {
              seen.add(href);
              
              String hostName = 'Server';
              try { hostName = Uri.parse(href).host; } catch (_) {}

              if (low.contains('streamtape') || low.contains('tpead') || low.contains('advtpe') || low.contains('tapepops')) {
                streams.add({
                  'title': '⚡ Streamtape / Tpead (Server 2 - Fast HD)',
                  'url': href,
                  'host': hostName,
                  'type': 'streamtape',
                  'referer': 'https://streamtape.com/',
                });
              } else if (low.contains('luluvdo')) {
                streams.add({
                  'title': 'Luluvdo (Server 1)',
                  'url': href,
                  'host': hostName,
                  'type': 'luluvdo',
                  'referer': 'https://luluvdo.com/',
                });
              } else if (low.contains('playmogo')) {
                streams.add({
                  'title': 'Playmogo (Server 3)',
                  'url': href,
                  'host': hostName,
                  'type': 'embed',
                  'referer': 'https://aagmaal.bz/',
                });
              } else {
                streams.add({
                  'title': text.isNotEmpty ? text : 'Stream ($hostName)',
                  'url': href,
                  'host': hostName,
                  'type': 'embed',
                  'referer': 'https://aagmaal.bz/',
                });
              }
            }
          }
        }

        // 2. Scan iframes
        final iframeMatches = RegExp(r'<iframe[^>]+src=["\x27]([^"\x27]+)["\x27]', caseSensitive: false).allMatches(html);
        for (final m in iframeMatches) {
          var src = m.group(1)?.trim() ?? '';
          if (src.startsWith('//')) src = 'https:$src';
          if (src.isNotEmpty && !seen.contains(src)) {
            final low = src.toLowerCase();
            if (!low.contains('whitetrafsa') && !low.contains('smartpop') && !low.contains('ad')) {
              seen.add(src);
              String host = 'Player';
              try { host = Uri.parse(src).host; } catch (_) {}
              streams.add({
                'title': 'Embedded Player ($host)',
                'url': src,
                'host': host,
                'type': 'embed',
                'referer': 'https://aagmaal.bz/',
              });
            }
          }
        }

        // 3. Direct MP4 / M3U8 links
        final directMatches = RegExp(r'https?://[^\s"\x27<>]+\.(?:mp4|m3u8)[^\s"\x27<>]*', caseSensitive: false).allMatches(html);
        for (final m in directMatches) {
          final dUrl = m.group(0)?.trim() ?? '';
          if (dUrl.isNotEmpty && !seen.contains(dUrl)) {
            seen.add(dUrl);
            streams.add({
              'title': dUrl.contains('.m3u8') ? 'HLS Stream (.m3u8)' : 'Direct Video (.mp4)',
              'url': dUrl,
              'host': Uri.tryParse(dUrl)?.host ?? 'Direct CDN',
              'type': dUrl.contains('.m3u8') ? 'hls' : 'direct',
              'referer': 'https://aagmaal.bz/',
            });
          }
        }

        if (mounted) {
          setState(() {
            _detectedStreams = streams;
          });
        }
      }
    } catch (_) {}
  }

  // Play stream in In-App Player with Streamtape direct resolver
  Future<void> _playStream(String rawUrl, String title, {String? referer, String? type}) async {
    String finalUrl = rawUrl;
    String finalReferer = referer ?? 'https://aagmaal.bz/';

    // If streamtape / tpead / advtpe, resolve direct clean MP4 stream
    if (type == 'streamtape' || rawUrl.contains('streamtape') || rawUrl.contains('tpead') || rawUrl.contains('advtpe')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                SizedBox(width: 12),
                Text("Resolving Streamtape direct MP4..."),
              ],
            ),
            duration: Duration(seconds: 4),
            backgroundColor: Color(0xFF1E2436),
          ),
        );
      }
      try {
        final direct = await StreamtapeService.getDirectStreamUrl(rawUrl);
        if (direct != null && direct.isNotEmpty) {
          finalUrl = direct;
          finalReferer = 'https://streamtape.com/';
        }
      } catch (_) {}
    }

    if (!mounted) return;
    playVideo(
      context,
      finalUrl,
      title.isNotEmpty ? title : _currentTitle,
    );
  }

  // Show action sheet for detected stream
  void _showStreamActionSheet(Map<String, String> stream) {
    final streamUrl = stream['url'] ?? '';
    final streamTitle = stream['title'] ?? 'Video Stream';
    final streamHost = stream['host'] ?? 'Server';
    final streamType = stream['type'] ?? 'direct';
    final referer = stream['referer'] ?? 'https://aagmaal.bz/';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141722),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (bctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFE50914), Color(0xFF8E2DE2)]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.movie_filter_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentTitle,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "$streamTitle • $streamHost",
                            style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                
                // 1. Play in In-App Player
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(bctx);
                      _playStream(streamUrl, _currentTitle, referer: referer, type: streamType);
                    },
                    icon: const Icon(Icons.play_circle_fill_rounded, size: 20),
                    label: const Text("PLAY IN IN-APP PLAYER (ZERO ADS)", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E676),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 4,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // 2. Download In-App
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(bctx);
                      DropmmsService.downloadInApp(
                        context: context,
                        rawUrl: streamUrl,
                        defaultFileName: "${_currentTitle}_$streamHost",
                      );
                    },
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text("DOWNLOAD VIDEO", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E2638),
                      foregroundColor: Colors.cyanAccent,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.cyanAccent, width: 1)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // 3. Post to Telegram Studio & Copy Link
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(bctx);
                          ExtractorTelegramDialog.show(
                            context,
                            title: _currentTitle,
                            category: "AAGMaal.bz",
                            topicUrl: _currentUrl,
                            initialImages: const [],
                            videoLinks: [
                              DropmmsMediaLink(
                                name: streamTitle,
                                url: streamUrl,
                                host: streamHost,
                                type: streamType,
                                isDirectStreamable: true,
                              ),
                            ],
                            downloadLinks: const [],
                          );
                        },
                        icon: const Icon(Icons.send_rounded, size: 16),
                        label: const Text("TG POST", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF182838),
                          foregroundColor: const Color(0xFF229ED9),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFF229ED9), width: 1)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: streamUrl));
                          Navigator.pop(bctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Stream URL copied to clipboard!"), backgroundColor: Colors.green),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text("COPY LINK", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF222634),
                          foregroundColor: Colors.white70,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF10121A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text("⚡ AAGMAAL.BZ CINEMA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(color: Colors.greenAccent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                  child: const Text("ZERO ADS", style: TextStyle(color: Colors.greenAccent, fontSize: 8.5, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            Text(
              _currentUrl,
              style: const TextStyle(color: Colors.white54, fontSize: 10.5),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.cyanAccent),
            tooltip: "Reload Page",
            onPressed: () => _webViewController?.reload(),
          ),
          IconButton(
            icon: const Icon(Icons.home_rounded, color: Colors.amberAccent),
            tooltip: "Home",
            onPressed: () => _webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri('https://aagmaal.bz/'))),
          ),
        ],
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(_currentUrl)),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              domStorageEnabled: true,
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,
              useShouldOverrideUrlLoading: true,
              userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
            ),
            onWebViewCreated: (ctrl) {
              _webViewController = ctrl;
            },
            onProgressChanged: (ctrl, progress) {
              setState(() {
                _progress = progress / 100;
              });
            },
            shouldOverrideUrlLoading: (ctrl, navigationAction) async {
              final uri = navigationAction.request.url;
              if (uri == null) return NavigationActionPolicy.ALLOW;
              final url = uri.toString().toLowerCase();

              // Block known ad networks and popup redirects
              if (url.contains('popcash') || url.contains('popads') || url.contains('adcash') ||
                  url.contains('trafficjunky') || url.contains('exoclick') || url.contains('syndication') ||
                  url.contains('betting') || url.contains('gambling') || url.contains('clickadu') ||
                  url.contains('propellerads') || url.contains('hilltopads') || url.contains('monetag') ||
                  url.contains('whitetrafsa') || url.contains('smartpop')) {
                return NavigationActionPolicy.CANCEL;
              }

              return NavigationActionPolicy.ALLOW;
            },
            onLoadStart: (ctrl, url) {
              final urlStr = url?.toString() ?? '';
              setState(() {
                _isLoading = true;
                _currentUrl = urlStr;
                _isPostPage = _checkIsPost(urlStr);
                if (_isPostPage) {
                  _detectedStreams.clear();
                }
              });
            },
            onLoadStop: (ctrl, url) async {
              final urlStr = url?.toString() ?? '';
              final title = await ctrl.getTitle() ?? 'AAGMaal.bz Cinema';
              setState(() {
                _isLoading = false;
                _currentUrl = urlStr;
                _currentTitle = title.replaceAll(' - Aagmaal', '').replaceAll(' - AAGMAAL', '').replaceAll(' | Watch Now', '').trim();
                _isPostPage = _checkIsPost(urlStr);
              });

              // Inject aggressive ad-remover CSS & JS (kills popups, overlays, and smartpop redirects)
              await ctrl.evaluateJavascript(source: """
                (function() {
                  window.open = function() { return null; };
                  const removeAds = () => {
                    const selectors = [
                      'iframe[src*="ad"]', 'iframe[src*="banner"]', 'iframe[src*="pop"]',
                      'iframe[src*="whitetrafsa"]', 'iframe[src*="smartpop"]',
                      '.adsbox', '.ad-container', '.banner-ad', '#ad-overlay',
                      'div[id*="ad_"]', 'div[class*="ad_"]', '.exo-native-widget',
                      'a[href*="facebook"]', 'a[href*="twitter"]', 'a[href*="reddit"]'
                    ];
                    selectors.forEach(s => {
                      document.querySelectorAll(s).forEach(el => el.remove());
                    });
                  };
                  removeAds();
                  setInterval(removeAds, 1000);
                })();
              """);

              // If on a post page, sniff streams
              if (_isPostPage) {
                _sniffPostStreams(urlStr);
              }
            },
          ),

          // Loading Progress Bar
          if (_isLoading)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                value: _progress > 0 && _progress < 1 ? _progress : null,
                backgroundColor: Colors.transparent,
                color: const Color(0xFFE50914),
                minHeight: 3,
              ),
            ),

          // Bottom Action Bar when on a Post Page with detected streams
          if (_isPostPage)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF1E2436), Color(0xFF141722)]),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.6), width: 1.2),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 16, offset: const Offset(0, 4)),
                    BoxShadow(color: const Color(0xFF00E676).withValues(alpha: 0.2), blurRadius: 8),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E676).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.flash_on_rounded, color: Color(0xFF00E676), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "STREAM READY",
                            style: TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5),
                          ),
                          Text(
                            _detectedStreams.isNotEmpty
                                ? "${_detectedStreams.length} stream server(s) found"
                                : "Sniffing stream servers...",
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        if (_detectedStreams.isNotEmpty) {
                          if (_detectedStreams.length == 1) {
                            _showStreamActionSheet(_detectedStreams.first);
                          } else {
                            // Show selector sheet
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: const Color(0xFF141722),
                              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                              builder: (ctx) {
                                return SafeArea(
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text("Select Server to Play / Download (${_detectedStreams.length})",
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                        const SizedBox(height: 14),
                                        ..._detectedStreams.map((s) => ListTile(
                                          tileColor: const Color(0xFF1C2232),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          leading: Icon(
                                            s['type'] == 'streamtape' ? Icons.flash_on_rounded : Icons.play_circle_fill_rounded,
                                            color: const Color(0xFF00E676),
                                          ),
                                          title: Text(s['title'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                          subtitle: Text(s['host'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                          trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 14),
                                          onTap: () {
                                            Navigator.pop(ctx);
                                            _showStreamActionSheet(s);
                                          },
                                        )),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          }
                        } else {
                          _sniffPostStreams(_currentUrl);
                        }
                      },
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: const Text("ACTIONS", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E676),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
