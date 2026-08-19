import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/download_service.dart';
import '../services/scraper_service.dart';
import '../services/xhamster_resolver.dart';
import '../services/eporner_resolver.dart';
import '../services/tnaflix_resolver.dart';
import '../services/hqporner_resolver.dart';
import '../services/freepornvideos_resolver.dart';
import '../widgets/resolving_dialog.dart';
import 'downloads_screen.dart';
import 'live_cams_screen.dart';
import 'subscription_vip_screen.dart';
import 'video_launcher.dart';

/// VIP gate shown when a non-premium user tries to open Fly Mode.
Future<void> showFlyModeVipGate(BuildContext context) async {
  await showDialog(
    context: context,
    barrierColor: Colors.black.withOpacity(0.6),
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1A2132),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: Colors.amber.withOpacity(0.3)),
      ),
      title: const Text(
        "Fly Mode Locked",
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: const Text(
        "Fly Mode is a premium/VIP feature. Subscribe to VIP to browse and watch content from foreign sites.",
        style: TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            final user = AppSession.user ??
                UserModel(id: 0, name: 'Guest', email: 'guest@redapp.space');
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SubscriptionVipScreen(user: user),
              ),
            );
          },
          child: const Text(
            "GET VIP",
            style: TextStyle(
                color: Colors.amber,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5),
          ),
        ),
      ],
    ),
  );
}

class FlyModeScreen extends StatefulWidget {
  const FlyModeScreen({super.key});

  @override
  State<FlyModeScreen> createState() => _FlyModeScreenState();
}

class _FlyModeScreenState extends State<FlyModeScreen> {
  List<ScraperSource> _sources = [];
  ScraperSource? _selectedSource;

  List<ScraperCard> _items = [];
  bool _loading = true;
  int _currentPage = 1;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  List<ScraperCategory> _categories = [];
  String _selectedCategory = '';

  @override
  void initState() {
    super.initState();
    // Only premium users may access Fly Mode.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted && !AppSession.isVip) {
        await showFlyModeVipGate(context);
        if (!mounted) return;
        // Refresh VIP status so a just-made subscription is honored.
        final uid = AppSession.user?.id ?? 0;
        if (uid > 0) {
          final fresh = await ApiService.refreshUser(uid);
          if (fresh != null) {
            AppSession.user = fresh;
            await ApiService.saveUserSession(fresh);
          }
        }
        if (mounted && !AppSession.isVip) {
          Navigator.of(context).pop();
        }
      }
    });
    _loadSourcesAndGrid();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Some hosts 403 plain (browserless) image requests; HQPorner's poster CDN
  /// requires a mobile UA + site Referer, so send them for matching URLs.
  static Map<String, String> _posterHeaders(String url) {
    if (url.contains('hqporner.com')) {
      return {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36',
        'Referer': 'https://m.hqporner.com/',
      };
    }
    return const {};
  }

  Future<void> _loadSourcesAndGrid() async {
    setState(() => _loading = true);
    final sources = await ScraperService.fetchSources();
    if (mounted) {
      setState(() {
        _sources = sources;
        if (_sources.isNotEmpty) {
          _selectedSource = _sources.first;
        }
      });
    }
    await _loadCategories();
    await _fetchGrid();
  }

  Future<void> _loadCategories() async {
    if (_selectedSource == null) return;
    final id = _selectedSource!.id;
    if (id == 'cambaddies') return;
    List<ScraperCategory> cats;
    if (id == 'eporner' || id == 'tnaflix' || id == 'hqporner') {
      cats = await ScraperService.fetchCategories(id);
    } else {
      cats = <ScraperCategory>[];
    }
    if (mounted) {
      setState(() {
        _categories = cats;
        if (!cats.any((c) => c.slug == _selectedCategory)) {
          // Auto-select the default category so MILF-oriented sources open on it.
          _selectedCategory = (id == 'eporner' || id == 'hqporner')
              ? (cats.any((c) => c.slug == 'milf') ? 'milf' : '')
              : (id == 'tnaflix'
                  ? (cats.any((c) => c.slug == 'milf-porn') ? 'milf-porn' : '')
                  : '');
        }
      });
    }
  }

  Future<void> _fetchGrid({int page = 1, String query = ''}) async {
    if (_selectedSource == null) return;
    setState(() {
      _loading = true;
      _currentPage = page;
      _searchQuery = query;
    });

    final id = _selectedSource!.id;
    if (id == 'cambaddies') {
      // Live cam site — opened in an in-app browser, never a grid.
      setState(() {
        _items = [];
        _loading = false;
      });
      return;
    }
    final items = await ScraperService.fetchGrid(id,
        page: page, query: query, category: _selectedCategory);
    if (mounted) {
      setState(() {
        _items = items;
        _loading = false;
      });
    }
  }

  void _selectCategory(ScraperCategory cat) {
    setState(() {
      _selectedCategory = _selectedCategory == cat.slug ? '' : cat.slug;
      _searchCtrl.clear();
      _searchQuery = '';
    });
    _fetchGrid(page: 1, query: '');
  }

  void _onSearchSubmitted(String val) {
    setState(() => _selectedCategory = '');
    _fetchGrid(page: 1, query: val.trim());
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() => _selectedCategory = '');
    _fetchGrid(page: 1, query: '');
  }

  Widget _buildLiveCamsLauncher() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF00C6FF), Color(0xFF8E2DE2)],
                ),
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00C6FF).withOpacity(0.35),
                    blurRadius: 30,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(Icons.videocam_rounded, color: Colors.white, size: 56),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFE53935),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, color: Colors.white, size: 7),
                  SizedBox(width: 5),
                  Text(
                    "LIVE",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Cambaddies Live Cams",
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Browse thousands of live models streaming right now.\nOpens in the in-app browser.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C6FF),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.launch_rounded, size: 20),
              label: const Text("OPEN LIVE CAMS", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LiveCamsScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _onCardTapped(ScraperCard card) {
    _showActionDialog(card);
  }

  void _showActionDialog(ScraperCard card) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.65),
      builder: (modalCtx) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  width: 320,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1E2436), Color(0xFF0D0F16)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.cyanAccent.withOpacity(0.2)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 30, spreadRadius: 4),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.cyanAccent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.flight_takeoff_rounded, color: Colors.cyanAccent, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Fly Mode Option",
                                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                Text(card.title,
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white54, fontSize: 11)),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(modalCtx),
                            child: const Icon(Icons.close_rounded, color: Colors.white60, size: 20),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Colors.white12, height: 1),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.cyanAccent,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.play_arrow_rounded, size: 20),
                              label: const Text("PLAY", style: TextStyle(fontWeight: FontWeight.bold)),
                              onPressed: () {
                                Navigator.pop(modalCtx);
                                _processOption(card, isDownload: false);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF8E2DE2),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.download_rounded, size: 20),
                              label: const Text("DOWNLOAD", style: TextStyle(fontWeight: FontWeight.bold)),
                              onPressed: () {
                                Navigator.pop(modalCtx);
                                _processOption(card, isDownload: true);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _processOption(ScraperCard card, {required bool isDownload}) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (_) => ResolvingProgressDialog(
        title: card.title,
        subtitle: 'Fetching media qualities...',
      ),
    );

    Map<String, String>? qualities;
    Map<String, String> headers = const {};

    if (XHamsterResolver.isXHamsterUrl(card.link) || card.link.contains('xhamster')) {
      final res = await XHamsterResolver.resolveQualities(card.link, forceRefresh: true);
      if (res != null && res.qualities.isNotEmpty) {
        qualities = res.qualities;
      }
    }

    if (qualities == null && EpornerResolver.isEpornerUrl(card.link)) {
      final res = await EpornerResolver.resolveQualities(card.link, forceRefresh: true);
      if (res != null && res.qualities.isNotEmpty) {
        qualities = res.qualities;
      }
    }

    if (qualities == null && TnaflixResolver.isTnaflixUrl(card.link)) {
      final res = await TnaflixResolver.resolveQualities(card.link, forceRefresh: true);
      if (res != null && res.qualities.isNotEmpty) {
        qualities = res.qualities;
      }
    }

    if (qualities == null && HqpornerResolver.isHqpornerUrl(card.link)) {
      // HQPorner: the bigcdn CDN IP-binds stream URLs to whoever fetched the
      // mydaddy.cc embed, so resolution must happen on-device (requests from
      // the phone's IP). Server resolve cannot work here.
      final res = await HqpornerResolver.resolveItem(card.link);
      if (res != null && res.qualities.isNotEmpty) {
        qualities = res.qualities;
        headers = res.headers;
      }
    }

    if (qualities == null && FreepornvideosResolver.isFreepornvideosUrl(card.link)) {
      // freepornvideos.xxx get_file links 302-redirect to an IP-bound,
      // time-limited fpvcdn.com CDN URL, so resolution must happen on-device
      // (requests from the phone's IP). Server resolve would hand back a URL
      // that 403s from the phone.
      final res = await FreepornvideosResolver.resolveItem(card.link);
      if (res != null && res.qualities.isNotEmpty) {
        qualities = res.qualities;
        headers = res.headers;
      }
    }

    if (qualities == null &&
        !HqpornerResolver.isHqpornerUrl(card.link) &&
        !FreepornvideosResolver.isFreepornvideosUrl(card.link)) {
      final res = await ScraperService.resolveItem(card.link);
      if (res != null) {
        qualities = res.qualities;
        headers = res.headers;
      }
    }

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    if (qualities == null || qualities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not resolve media stream for this video."), backgroundColor: Colors.red),
      );
      return;
    }

    _showQualitySelectionDialog(card, qualities, isDownload: isDownload, headers: headers);
  }

  void _showQualitySelectionDialog(ScraperCard card, Map<String, String> qualities, {required bool isDownload, Map<String, String> headers = const {}}) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.65),
      builder: (modalCtx) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  width: 320,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1E2436), Color(0xFF0D0F16)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.amberAccent.withOpacity(0.25)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 30, spreadRadius: 4),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(isDownload ? Icons.download_rounded : Icons.play_circle_fill_rounded,
                              color: isDownload ? const Color(0xFF8E2DE2) : Colors.amberAccent, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isDownload ? "Select Download Quality" : "Select Play Quality",
                              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(modalCtx),
                            child: const Icon(Icons.close_rounded, color: Colors.white60, size: 20),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Divider(color: Colors.white12, height: 1),
                      const SizedBox(height: 14),
                      Column(
                        children: qualities.entries.map((e) {
                          final label = e.key;
                          final streamUrl = e.value;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF161B22),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: ListTile(
                              dense: true,
                              leading: Icon(
                                isDownload ? Icons.file_download_outlined : Icons.open_in_browser_rounded,
                                color: isDownload ? Colors.cyanAccent : Colors.amberAccent,
                                size: 20,
                              ),
                              title: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 18),
                              onTap: () {
                                Navigator.pop(modalCtx);
                                _logFlyEvent(card, isDownload ? 'download' : 'play');
                                if (isDownload) {
                                  _startDownload(streamUrl, '${card.title} ($label)', card.poster,
                                      headers: headers, originalUrl: card.link);
                                } else {
                                  playVideo(context, streamUrl, '${card.title} ($label)',
                                      qualities: qualities,
                                      initialQuality: label,
                                      headers: headers);
                                }
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openNativeBrowser(String url) async {
    try {
      final uri = Uri.parse(url);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not open native browser.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Browser error: $e")),
        );
      }
    }
  }

  void _startDownload(String url, String title, String poster,
      {Map<String, String> headers = const {}, String originalUrl = ''}) {
    DownloadManager.instance
        .start(url, title, poster: poster, headers: headers, originalUrl: originalUrl);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Downloading: $title"),
        backgroundColor: Colors.green,
        action: SnackBarAction(
          label: "VIEW",
          textColor: Colors.white,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DownloadsScreen()),
          ),
        ),
      ),
    );
  }

  /// Non-blocking analytics ping so the admin panel can see who is playing /
  /// downloading content and from which site. Never interrupts the user.
  void _logFlyEvent(ScraperCard card, String action) {
    final user = AppSession.user;
    final source = _selectedSource;
    if (user == null || source == null) return;
    ScraperService.logFlyModeEvent(
      userId: user.id,
      userName: user.name,
      sourceId: source.id,
      sourceName: source.name,
      videoTitle: card.title,
      videoLink: card.link,
      action: action,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14141C),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF00c6ff), Color(0xFF0072ff)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.flight_takeoff_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              "Fly Mode",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded, color: Colors.cyanAccent),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DownloadsScreen())),
          ),
        ],
      ),
      body: Column(
        children: [
          // Modern Unique Top Control Bar (Neon Glassmorphic Design)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            decoration: BoxDecoration(
              color: const Color(0xFF14141C),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // 1. Sleek Site Selector Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E2638), Color(0xFF111522)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF00C6FF).withOpacity(0.5), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00C6FF).withOpacity(0.2),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<ScraperSource>(
                      value: _selectedSource,
                      dropdownColor: const Color(0xFF161B26),
                      icon: const Icon(Icons.arrow_drop_down_circle_rounded, color: Color(0xFF00C6FF), size: 18),
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                      items: _sources.map((s) {
                        return DropdownMenuItem<ScraperSource>(
                          value: s,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.language_rounded, color: Color(0xFF00C6FF), size: 16),
                              const SizedBox(width: 6),
                              Text(s.name),
                              if (s.id == 'cambaddies') ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE53935),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: const Text(
                                    "LIVE",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          if (val.id == 'cambaddies') {
                            // Live cams run in the in-app browser, not the grid.
                            setState(() {
                              _selectedSource = val;
                              _searchCtrl.clear();
                              _selectedCategory = '';
                              _items = [];
                            });
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LiveCamsScreen(),
                              ),
                            );
                            return;
                          }
                          setState(() {
                            _selectedSource = val;
                            _searchCtrl.clear();
                            _selectedCategory = '';
                          });
                          _loadCategories();
                          _fetchGrid(page: 1, query: '');
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // 2. Futuristic Glassmorphic Search Bar
                Expanded(
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B2234),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      onSubmitted: _onSearchSubmitted,
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                      textAlignVertical: TextAlignVertical.center,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: "Search Indian content...",
                        hintStyle: GoogleFonts.outfit(color: Colors.white38, fontSize: 12),
                        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF00C6FF), size: 20),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.cancel_rounded, color: Colors.white54, size: 18),
                                onPressed: _clearSearch,
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Category Chips Row (Eporner / TNAFlix)
          if (_categories.isNotEmpty)
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              color: const Color(0xFF0D0D12),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, idx) {
                  final cat = _categories[idx];
                  final selected = cat.slug == _selectedCategory;
                  return GestureDetector(
                    onTap: () => _selectCategory(cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: selected
                            ? const LinearGradient(colors: [Color(0xFF00c6ff), Color(0xFF0072ff)])
                            : null,
                        color: selected ? null : const Color(0xFF1B2234),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: selected ? Colors.cyanAccent : Colors.white12,
                        ),
                      ),
                      child: Text(
                        cat.name,
                        style: GoogleFonts.outfit(
                          color: selected ? Colors.black : Colors.white70,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          // Main Video Poster Grid
          Expanded(
            child: _selectedSource?.id == 'cambaddies'
                ? _buildLiveCamsLauncher()
                : _loading
                    ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
                    : _items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.flight_land_rounded, color: Colors.white24, size: 64),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? "No results found for '$_searchQuery'"
                                  : _selectedCategory.isNotEmpty
                                      ? "No videos found in this category."
                                      : "No video items found.",
                              style: const TextStyle(color: Colors.white54, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.35, // Landscape Card
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: _items.length,
                        itemBuilder: (ctx, idx) {
                          final item = _items[idx];
                          return InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => _onCardTapped(item),
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF1B202D),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white10),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: CachedNetworkImage(
                                      imageUrl: item.poster,
                                      httpHeaders: _posterHeaders(item.poster),
                                      width: double.infinity,
                                      height: double.infinity,
                                      fit: BoxFit.cover,
                                      errorWidget: (c, u, e) => Container(
                                        color: const Color(0xFF22283A),
                                        child: const Icon(Icons.movie_rounded, color: Colors.white24, size: 36),
                                      ),
                                    ),
                                  ),
                                  // Gradient Overlay & Title Text
                                  Positioned(
                                    left: 0, right: 0, bottom: 0,
                                    child: Container(
                                      padding: const EdgeInsets.fromLTRB(10, 20, 10, 8),
                                      decoration: BoxDecoration(
                                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                                        gradient: LinearGradient(
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                          colors: [
                                            Colors.black.withOpacity(0.92),
                                            Colors.black.withOpacity(0.60),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                      child: Text(
                                        item.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          height: 1.2,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Play Icon Badge
                                  Positioned(
                                    top: 8, right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.6),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.play_arrow_rounded, color: Colors.cyanAccent, size: 16),
                                    ),
                                  ),
                                  // Duration Badge (e.g. "4 min", "90 sec")
                                  if (item.duration.isNotEmpty)
                                    Positioned(
                                      right: 6, bottom: 6,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.75),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.schedule_rounded, color: Colors.white70, size: 10),
                                            const SizedBox(width: 3),
                                            Text(
                                              item.duration,
                                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // Pagination Navigation Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF14141C),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF22283A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.chevron_left_rounded, size: 18),
                  label: const Text("Prev", style: TextStyle(fontSize: 12)),
                  onPressed: _currentPage > 1 ? () => _fetchGrid(page: _currentPage - 1, query: _searchQuery) : null,
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.cyanAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
                  ),
                  child: Text(
                    "Page $_currentPage",
                    style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF22283A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.chevron_right_rounded, size: 18),
                  label: const Text("Next", style: TextStyle(fontSize: 12)),
                  onPressed: _items.isNotEmpty ? () => _fetchGrid(page: _currentPage + 1, query: _searchQuery) : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
