import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/download_service.dart';
import '../services/scraper_service.dart';
import '../services/xhamster_resolver.dart';
import '../widgets/resolving_dialog.dart';
import 'downloads_screen.dart';
import 'video_launcher.dart';

class ForeignTripScreen extends StatefulWidget {
  const ForeignTripScreen({super.key});

  @override
  State<ForeignTripScreen> createState() => _ForeignTripScreenState();
}

class _ForeignTripScreenState extends State<ForeignTripScreen> {
  List<ScraperSource> _sources = [];
  ScraperSource? _selectedSource;

  List<ScraperCard> _items = [];
  bool _loading = true;
  int _currentPage = 1;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSourcesAndGrid();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
    await _fetchGrid();
  }

  Future<void> _fetchGrid({int page = 1, String query = ''}) async {
    if (_selectedSource == null) return;
    setState(() {
      _loading = true;
      _currentPage = page;
      _searchQuery = query;
    });

    final items = await ScraperService.fetchGrid(_selectedSource!.id, page: page, query: query);
    if (mounted) {
      setState(() {
        _items = items;
        _loading = false;
      });
    }
  }

  void _onSearchSubmitted(String val) {
    _fetchGrid(page: 1, query: val.trim());
  }

  void _clearSearch() {
    _searchCtrl.clear();
    _fetchGrid(page: 1, query: '');
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
                                const Text("Foreign Trip Option",
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

    if (XHamsterResolver.isXHamsterUrl(card.link) || card.link.contains('xhamster')) {
      final res = await XHamsterResolver.resolveQualities(card.link, forceRefresh: true);
      if (res != null && res.qualities.isNotEmpty) {
        qualities = res.qualities;
      }
    }

    qualities ??= await ScraperService.resolveItem(card.link);

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    if (qualities == null || qualities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not resolve media stream for this video."), backgroundColor: Colors.red),
      );
      return;
    }

    _showQualitySelectionDialog(card, qualities, isDownload: isDownload);
  }

  void _showQualitySelectionDialog(ScraperCard card, Map<String, String> qualities, {required bool isDownload}) {
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
                                if (isDownload) {
                                  _startDownload(streamUrl, '${card.title} ($label)', card.poster);
                                } else {
                                  playVideo(context, streamUrl, '${card.title} ($label)');
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

  void _startDownload(String url, String title, String poster) {
    DownloadManager.instance.start(url, title, poster: poster);
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
              "Foreign Trip",
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
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedSource = val);
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

          // Main Video Poster Grid
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
                : _items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.flight_land_rounded, color: Colors.white24, size: 64),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isNotEmpty ? "No results found for '$_searchQuery'" : "No video items found.",
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
