import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import '../services/dropmms_service.dart';
import 'video_launcher.dart';

class DropmmsBrowserScreen extends StatefulWidget {
  final String initialUrl;

  const DropmmsBrowserScreen({
    super.key,
    this.initialUrl = 'https://dropmms.co/',
  });

  @override
  State<DropmmsBrowserScreen> createState() => _DropmmsBrowserScreenState();
}

class _DropmmsBrowserScreenState extends State<DropmmsBrowserScreen> {
  InAppWebViewController? _webViewController;
  bool _isLoading = false;
  String _currentUrl = 'https://dropmms.co/';
  String _currentTitle = 'DropMMS Forum';
  bool _isTopicPage = false;
  DropmmsTopicDetails? _currentTopicDetails;

  final List<String> _history = [];
  int _historyIndex = -1;
  final Set<String> _selectedImages = {};

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.initialUrl;
    _history.add(_currentUrl);
    _historyIndex = 0;
  }

  Future<void> _loadUrlWithDoH(String url, {bool addToHistory = true}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _currentUrl = url;
      _isTopicPage = url.contains('/topic/');
    });

    try {
      final html = await DropmmsService.fetchHtmlDirect(url);
      if (html.isEmpty) throw Exception("Empty response received");

      // Extract title from HTML
      final titleMatch = RegExp(r'<title>([^<]+)<\/title>', caseSensitive: false).firstMatch(html);
      final pageTitle = titleMatch?.group(1)?.replaceAll(' - DropMMS', '').trim() ?? 'DropMMS';

      // Parse topic details if on a topic page
      if (url.contains('/topic/')) {
        _currentTopicDetails = DropmmsService.parseTopicHtml(html, url);
      } else {
        _currentTopicDetails = null;
      }

      // Ad-clean and inject link handler script
      final cleanHtml = _prepareCleanHtml(html, url);

      if (_webViewController != null) {
        await _webViewController!.loadData(
          data: cleanHtml,
          baseUrl: WebUri('https://dropmms.co'),
          mimeType: 'text/html',
          encoding: 'utf-8',
        );
      }

      if (addToHistory) {
        if (_historyIndex < _history.length - 1) {
          _history.removeRange(_historyIndex + 1, _history.length);
        }
        _history.add(url);
        _historyIndex = _history.length - 1;
      }

      if (mounted) {
        setState(() {
          _currentTitle = pageTitle;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error loading page: $e"),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: "Retry",
              textColor: Colors.white,
              onPressed: () => _loadUrlWithDoH(url, addToHistory: false),
            ),
          ),
        );
      }
    }
  }


  String _prepareCleanHtml(String rawHtml, String currentUrl) {
    var html = rawHtml;

    // 1. Remove all inline popup/redirect event handlers
    html = html.replaceAll(RegExp(r'''on(?:click|mousedown|mouseup|pointerdown|touchstart)=['"][^'"]*['"]''', caseSensitive: false), '');

    // 2. Remove third-party ad scripts, iframes, monetag, and tracking banners
    html = html.replaceAll(RegExp(r'<script[^>]*>(?:(?!<\/script>)[\s\S])*(?:monetag|popunder|onclickalgo|cpmrate|adkeeper|adsterra|revenuehits|googlesyndication|yandex)[\s\S]*?<\/script>', caseSensitive: false), '');
    html = html.replaceAll(RegExp(r'<script[^>]*src=[^>]+(?:monetag|popunder|cpm|adkeeper|adsterra|banner)[^>]*><\/script>', caseSensitive: false), '');
    html = html.replaceAll(RegExp(r'<iframe[\s\S]*?<\/iframe>', caseSensitive: false), '');

    // 3. Inject lightweight JS to load background images, block popups, and route links
    final injectedHead = """
      <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=2.0">
      <style>
        /* Hide third-party ads and spam banners without altering forum layout */
        .cAnnouncements, div[class*="ad_"], div[id*="ad_"], div[class*="banner"], div[id*="banner"],
        .ipsLayout_sidebar, #elSidebar { display: none !important; }

        /* Ensure thumbnails display cleanly */
        .tthumbGridview_img, .tthumb_standard, [data-background-src] {
          background-size: cover !important;
          background-position: center top !important;
        }
      </style>
      <script>
        window.open = function() { return null; };

        function applyBgImages() {
          var els = document.querySelectorAll('[data-background-src]');
          for (var i = 0; i < els.length; i++) {
            var el = els[i];
            var src = el.getAttribute('data-background-src');
            if (src) {
              var cur = el.style.backgroundImage || '';
              if (!cur || cur.indexOf('spacer') !== -1 || cur === 'none') {
                el.style.backgroundImage = "url('" + src + "')";
              }
            }
          }
        }

        if (document.readyState === 'loading') {
          document.addEventListener('DOMContentLoaded', applyBgImages);
        } else {
          applyBgImages();
        }
        setTimeout(applyBgImages, 200);
        setTimeout(applyBgImages, 800);
        setTimeout(applyBgImages, 2000);

        document.addEventListener('click', function(e) {
          var a = e.target.closest('a');
          if (a && a.href) {
            e.preventDefault();
            e.stopPropagation();
            window.flutter_inappwebview.callHandler('onLinkClick', a.href);
          }
        }, true);
      </script>
    """;

    if (html.contains('<head>')) {
      html = html.replaceFirst('<head>', '<head>$injectedHead');
    } else {
      html = injectedHead + html;
    }

    return html;
  }




  void _handleLinkClick(String href) {
    var cleanHref = href.trim();
    if (cleanHref.isEmpty || cleanHref.startsWith('javascript:') || cleanHref.startsWith('#')) {
      return;
    }

    final lower = cleanHref.toLowerCase();

    // 1. Block known ad / spam networks completely
    if (lower.contains('monetag') ||
        lower.contains('profitablecpmrate') ||
        lower.contains('onclick') ||
        lower.contains('popunder') ||
        lower.contains('adsterra') ||
        lower.contains('bit.ly') ||
        lower.contains('tinyurl') ||
        lower.contains('telegram.me') ||
        lower.contains('t.me') ||
        lower.contains('revenuehits')) {
      debugPrint("Blocked ad click: $cleanHref");
      return;
    }

    // 2. Check if internal DropMMS navigation across all mirror domains
    final isDropmms = lower.contains('dropmms') ||
        cleanHref.startsWith('/') ||
        lower.contains('dropmms.co') ||
        lower.contains('dropmms.com') ||
        lower.contains('dropmms.net') ||
        lower.contains('dropmms.fun') ||
        lower.contains('dropmms.us') ||
        lower.contains('dropmms.wtf') ||
        lower.contains('dropmms.link') ||
        lower.contains('dropmms.forum');

    if (isDropmms) {
      var fullUrl = cleanHref;
      if (cleanHref.startsWith('/')) {
        fullUrl = 'https://dropmms.co$cleanHref';
      }
      _loadUrlWithDoH(fullUrl);
      return;
    }

    // 3. Check if video stream or download mirror
    if (lower.contains('streamtape') ||
        lower.contains('vidara') ||
        lower.contains('luluvdo') ||
        lower.contains('lulustream') ||
        lower.contains('playmate') ||
        lower.contains('vidsonic') ||
        lower.contains('vibevdo')) {
      _playMediaStream(cleanHref, "DropMMS Stream");
      return;
    } else if (lower.contains('torupload') || lower.contains('upfiles') || lower.contains('frdl')) {
      DropmmsService.downloadInApp(
        context: context,
        rawUrl: cleanHref,
        defaultFileName: "DropMMS_Download.mp4",
      );
      return;
    }

    // If it's another domain, ignore it to prevent ad redirects
    debugPrint("Ignored external URL click: $cleanHref");
  }

  void _goBack() {
    if (_historyIndex > 0) {
      _historyIndex--;
      _loadUrlWithDoH(_history[_historyIndex], addToHistory: false);
    }
  }

  void _goForward() {
    if (_historyIndex < _history.length - 1) {
      _historyIndex++;
      _loadUrlWithDoH(_history[_historyIndex], addToHistory: false);
    }
  }

  void _showDomainSwitcher() {
    // Known working DropMMS mirror domains
    const domains = [
      ('dropmms.co', 'https://dropmms.co/'),
      ('dropmms.com', 'https://dropmms.com/'),
      ('dropmms.net', 'https://dropmms.net/'),
      ('dropmms.fun', 'https://dropmms.fun/'),
      ('dropmms.us', 'https://dropmms.us/'),
      ('dropmms.wtf', 'https://dropmms.wtf/'),
      ('m2.dropmms.forum', 'https://m2.dropmms.forum/'),
    ];

    // Extract current path so we switch domain but keep the same page
    String currentPath = '/';
    try {
      final uri = Uri.parse(_currentUrl);
      currentPath = uri.path + (uri.query.isNotEmpty ? '?${uri.query}' : '');
    } catch (_) {}
    final savedPath = currentPath;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B26),
        title: const Text('🌐 Switch Mirror Domain', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('All mirrors load the same content. Switch if current domain is slow.', style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 12),
            ...domains.map((d) {
              final domainLabel = d.$1;
              final baseUrl = d.$2;
              final isCurrent = _currentUrl.contains(domainLabel);
              return ListTile(
                dense: true,
                leading: Icon(
                  isCurrent ? Icons.check_circle_rounded : Icons.language_rounded,
                  color: isCurrent ? Colors.cyanAccent : Colors.white38,
                  size: 18,
                ),
                title: Text(
                  domainLabel,
                  style: TextStyle(
                    color: isCurrent ? Colors.cyanAccent : Colors.white,
                    fontSize: 14,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  if (!isCurrent) {
                    final newUrl = baseUrl.endsWith('/') && savedPath.startsWith('/')
                        ? baseUrl.substring(0, baseUrl.length - 1) + savedPath
                        : baseUrl + savedPath;
                    _loadUrlWithDoH(newUrl);
                  }
                },
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  Future<void> _playMediaStream(String rawUrl, String videoTitle) async {
    await playVideo(context, rawUrl, videoTitle);
  }

  void _showExtractedMediaSheet(DropmmsTopicDetails details) {
    _selectedImages.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bctx) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.88,
              maxChildSize: 0.95,
              minChildSize: 0.5,
              builder: (_, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF121622),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    border: Border(top: BorderSide(color: Colors.cyanAccent, width: 1.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(top: 10, bottom: 12),
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.cyanAccent.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.cyanAccent, width: 0.8),
                                  ),
                                  child: Text(
                                    details.categoryName.toUpperCase(),
                                    style: const TextStyle(color: Colors.cyanAccent, fontSize: 10.5, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.greenAccent.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    "100% AD-FREE",
                                    style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              details.title,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: Colors.white10, height: 1),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.all(18),
                          children: [
                            // 1. Photos & Screenshots Section
                            if (details.images.isNotEmpty) ...[
                              Row(
                                children: [
                                  const Icon(Icons.photo_library_rounded, color: Colors.cyanAccent, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    "PHOTOS & SCREENSHOTS (${details.images.length})",
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                                  ),
                                  const Spacer(),
                                  TextButton.icon(
                                    onPressed: () {
                                      setSheetState(() {
                                        if (_selectedImages.length == details.images.length) {
                                          _selectedImages.clear();
                                        } else {
                                          _selectedImages.addAll(details.images);
                                        }
                                      });
                                    },
                                    icon: Icon(
                                      _selectedImages.length == details.images.length ? Icons.deselect_rounded : Icons.select_all_rounded,
                                      color: Colors.cyanAccent,
                                      size: 15,
                                    ),
                                    label: Text(
                                      _selectedImages.length == details.images.length ? "Deselect All" : "Select All",
                                      style: const TextStyle(color: Colors.cyanAccent, fontSize: 11.5, fontWeight: FontWeight.bold),
                                    ),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Multi-Select Action Buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _selectedImages.isEmpty
                                          ? null
                                          : () {
                                              DropmmsService.downloadMultipleImages(
                                                context: context,
                                                imageUrls: _selectedImages.toList(),
                                                postTitle: details.title,
                                              );
                                            },
                                      icon: const Icon(Icons.download_for_offline_rounded, size: 16),
                                      label: Text(
                                        _selectedImages.isEmpty ? "SELECT PHOTOS" : "SAVE (${_selectedImages.length}) TO GALLERY",
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF00E676),
                                        foregroundColor: Colors.black,
                                        disabledBackgroundColor: Colors.white10,
                                        disabledForegroundColor: Colors.white30,
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      DropmmsService.downloadMultipleImages(
                                        context: context,
                                        imageUrls: details.images,
                                        postTitle: details.title,
                                      );
                                    },
                                    icon: const Icon(Icons.photo_album_rounded, size: 16),
                                    label: Text(
                                      "SAVE ALL (${details.images.length})",
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1E2638),
                                      foregroundColor: Colors.cyanAccent,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        side: const BorderSide(color: Colors.cyanAccent, width: 0.8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Horizontal Image Carousel
                              SizedBox(
                                height: 145,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: details.images.length,
                                  itemBuilder: (context, imgIdx) {
                                    final imgUrl = details.images[imgIdx];
                                    final isSelected = _selectedImages.contains(imgUrl);

                                    return Container(
                                      width: 115,
                                      margin: const EdgeInsets.only(right: 10),
                                      child: InkWell(
                                        onTap: () => _showFullscreenGallery(details.images, imgIdx),
                                        borderRadius: BorderRadius.circular(10),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              CachedNetworkImage(
                                                imageUrl: imgUrl,
                                                fit: BoxFit.cover,
                                                errorWidget: (_, __, ___) => Container(
                                                  color: const Color(0xFF1E2433),
                                                  child: const Icon(Icons.broken_image_rounded, color: Colors.white24),
                                                ),
                                              ),
                                              if (isSelected)
                                                Container(
                                                  decoration: BoxDecoration(
                                                    border: Border.all(color: const Color(0xFF00E676), width: 3),
                                                    borderRadius: BorderRadius.circular(10),
                                                    color: const Color(0xFF00E676).withValues(alpha: 0.2),
                                                  ),
                                                ),
                                              Positioned(
                                                top: 4,
                                                right: 4,
                                                child: GestureDetector(
                                                  onTap: () {
                                                    setSheetState(() {
                                                      if (isSelected) {
                                                        _selectedImages.remove(imgUrl);
                                                      } else {
                                                        _selectedImages.add(imgUrl);
                                                      }
                                                    });
                                                  },
                                                  child: Container(
                                                    padding: const EdgeInsets.all(4),
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: isSelected ? const Color(0xFF00E676) : Colors.black54,
                                                      border: Border.all(color: Colors.white, width: 1),
                                                    ),
                                                    child: Icon(
                                                      isSelected ? Icons.check : Icons.circle_outlined,
                                                      size: 14,
                                                      color: isSelected ? Colors.black : Colors.white70,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Positioned(
                                                bottom: 4,
                                                right: 4,
                                                child: Container(
                                                  padding: const EdgeInsets.all(3),
                                                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                                                  child: const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 14),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],

                            // 2. Video Streams Section
                            Row(
                              children: [
                                const Icon(Icons.play_circle_filled_rounded, color: Color(0xFF00E676), size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  "IN-APP VIDEO STREAMS (${details.videoLinks.length})",
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (details.videoLinks.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(color: const Color(0xFF161B26), borderRadius: BorderRadius.circular(12)),
                                child: const Text("No video streams found for this post. Check download mirrors below.", style: TextStyle(color: Colors.white54, fontSize: 12)),
                              )
                            else
                              ...details.videoLinks.map((vLink) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF161B26),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF00E676).withValues(alpha: 0.18),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              vLink.host.toUpperCase(),
                                              style: const TextStyle(
                                                color: Color(0xFF00E676),
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              vLink.name,
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: () {
                                                Navigator.pop(bctx);
                                                _playMediaStream(vLink.url, details.title);
                                              },
                                              icon: const Icon(Icons.play_arrow_rounded, size: 16),
                                              label: const Text("PLAY IN-APP", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF00E676),
                                                foregroundColor: Colors.black,
                                                padding: const EdgeInsets.symmetric(vertical: 9),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: () {
                                                DropmmsService.downloadInApp(
                                                  context: context,
                                                  rawUrl: vLink.url,
                                                  defaultFileName: "${details.title}_${vLink.host}.mp4",
                                                );
                                              },
                                              icon: const Icon(Icons.download_rounded, size: 16),
                                              label: const Text("DOWNLOAD", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF1E2638),
                                                foregroundColor: Colors.cyanAccent,
                                                padding: const EdgeInsets.symmetric(vertical: 9),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Colors.cyanAccent, width: 0.8)),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }),

                            const SizedBox(height: 16),

                            // 3. Download Mirrors Section
                            if (details.downloadLinks.isNotEmpty) ...[
                              Row(
                                children: [
                                  const Icon(Icons.cloud_download_rounded, color: Colors.amberAccent, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    "DOWNLOAD MIRRORS (${details.downloadLinks.length})",
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ...details.downloadLinks.map((dl) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF161B26),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.white10),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.insert_drive_file_outlined, color: Colors.amberAccent, size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          dl.name,
                                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      TextButton.icon(
                                        onPressed: () {
                                          DropmmsService.downloadInApp(
                                            context: context,
                                            rawUrl: dl.url,
                                            defaultFileName: "${details.title}_${dl.host}.mp4",
                                          );
                                        },
                                        icon: const Icon(Icons.download_rounded, size: 14),
                                        label: const Text("Download", style: TextStyle(fontSize: 11)),
                                        style: TextButton.styleFrom(foregroundColor: Colors.amberAccent),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.copy_rounded, color: Colors.white38, size: 16),
                                        tooltip: "Copy Link",
                                        onPressed: () {
                                          Clipboard.setData(ClipboardData(text: dl.url));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text("Download link copied to clipboard")),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showFullscreenGallery(List<String> images, int initialIdx) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text("Photo ${initialIdx + 1} of ${images.length}"),
          ),
          body: PageView.builder(
            itemCount: images.length,
            controller: PageController(initialPage: initialIdx),
            itemBuilder: (ctx, i) {
              return InteractiveViewer(
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: images[i],
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const Center(child: CircularProgressIndicator(color: Colors.cyanAccent)),
                    errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white38, size: 48),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D111A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121622),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.cyanAccent, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shield_rounded, color: Colors.greenAccent, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _currentTitle,
                    style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Text(
              _currentUrl,
              style: const TextStyle(color: Colors.white38, fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: _historyIndex > 0 ? Colors.white : Colors.white24),
            onPressed: _historyIndex > 0 ? _goBack : null,
          ),
          IconButton(
            icon: Icon(Icons.arrow_forward_rounded, color: _historyIndex < _history.length - 1 ? Colors.white : Colors.white24),
            onPressed: _historyIndex < _history.length - 1 ? _goForward : null,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.cyanAccent),
            onPressed: () => _loadUrlWithDoH(_currentUrl, addToHistory: false),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            color: const Color(0xFF161B26),
            onSelected: (val) {
              if (val == 'change_domain') {
                _showDomainSwitcher();
              } else if (val.startsWith('http')) {
                _loadUrlWithDoH(val);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'https://dropmms.co/', child: Text("🏠 Forum Home", style: TextStyle(color: Colors.white))),
              const PopupMenuItem(value: 'https://dropmms.co/discover/', child: Text("🔥 Recent Updates", style: TextStyle(color: Colors.white))),
              const PopupMenuItem(value: 'https://dropmms.co/forum/20-indian-actress-and-models-mms/', child: Text("⭐ Indian Actress & Models", style: TextStyle(color: Colors.white))),
              const PopupMenuItem(value: 'https://dropmms.co/forum/58-exclusive-mms-collection/', child: Text("💎 Exclusive Collection", style: TextStyle(color: Colors.white))),
              const PopupMenuItem(value: 'https://dropmms.co/forum/2-general-discussion/', child: Text("💬 General Discussion", style: TextStyle(color: Colors.white))),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'change_domain', child: Text("🌐 Change Domain / Mirror", style: TextStyle(color: Colors.cyanAccent))),
            ],
          ),
        ],
        bottom: _isLoading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
                  minHeight: 3,
                ),
              )
            : null,
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              domStorageEnabled: true,
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,
              supportZoom: true,
              builtInZoomControls: true,
              displayZoomControls: false,
            ),
            onWebViewCreated: (ctrl) {
              _webViewController = ctrl;
              ctrl.addJavaScriptHandler(
                handlerName: 'onLinkClick',
                callback: (args) {
                  if (args.isNotEmpty) {
                    final href = args[0].toString();
                    _handleLinkClick(href);
                  }
                },
              );
              _loadUrlWithDoH(_currentUrl, addToHistory: false);
            },
            onLoadStop: (ctrl, url) async {
              await ctrl.evaluateJavascript(source: r"""
                (function() {
                  function applyBgImages() {
                    var els = document.querySelectorAll('[data-background-src]');
                    for (var i = 0; i < els.length; i++) {
                      var el = els[i];
                      var src = el.getAttribute('data-background-src');
                      if (src) {
                        var cur = el.style.backgroundImage || '';
                        if (!cur || cur.indexOf('spacer') !== -1 || cur === 'none') {
                          el.style.backgroundImage = "url('" + src + "')";
                        }
                      }
                    }
                  }
                  applyBgImages();
                  setTimeout(applyBgImages, 500);
                  setTimeout(applyBgImages, 1500);
                })();
              """);
            },
          ),

          // Floating Action Button for Instant Media Extraction & Playback
          if (_isTopicPage && _currentTopicDetails != null)
            Positioned(
              bottom: 24,
              left: 20,
              right: 20,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E676).withValues(alpha: 0.45),
                      blurRadius: 16,
                      spreadRadius: 2,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () => _showExtractedMediaSheet(_currentTopicDetails!),
                  icon: const Icon(Icons.flash_on_rounded, color: Colors.black, size: 22),
                  label: Text(
                    "⚡ EXTRACT MEDIA & PLAY / DOWNLOAD (${_currentTopicDetails!.videoLinks.length} Vids, ${_currentTopicDetails!.images.length} Pics)",
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 12.5,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E676),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 8,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
