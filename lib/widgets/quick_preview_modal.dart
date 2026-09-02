import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/movie_model.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/app_image_cache.dart';
import '../screens/video_launcher.dart';
import '../screens/navigation_helper.dart';

class QuickPreviewModal extends StatefulWidget {
  final MovieModel movie;
  final UserModel? user;
  final BuildContext parentContext;

  const QuickPreviewModal({
    super.key,
    required this.movie,
    this.user,
    required this.parentContext,
  });

  static Future<void> show(BuildContext context, {required MovieModel movie, UserModel? user}) {
    HapticFeedback.mediumImpact();
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'QuickPreviewModal',
      barrierColor: Colors.black.withValues(alpha: 0.78),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (ctx, anim1, anim2) => QuickPreviewModal(
        movie: movie,
        user: user,
        parentContext: context,
      ),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curved = CurvedAnimation(
          parent: anim1,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        );
        return ScaleTransition(
          scale: Tween<double>(begin: 0.80, end: 1.0).animate(curved),
          child: FadeTransition(
            opacity: anim1,
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<QuickPreviewModal> createState() => _QuickPreviewModalState();
}

class _QuickPreviewModalState extends State<QuickPreviewModal> {
  bool _isFavorite = false;
  bool _isLoadingPlay = false;

  @override
  void initState() {
    super.initState();
    _checkFavorite();
  }

  Future<void> _checkFavorite() async {
    final favs = await ApiService.getFavorites();
    if (mounted) {
      setState(() {
        _isFavorite = favs.any((f) =>
            (int.tryParse('${f['content_id']}') ?? int.tryParse('${f['id']}')) ==
            widget.movie.id);
      });
    }
  }

  Future<void> _toggleFavorite() async {
    HapticFeedback.lightImpact();
    final newStatus = !_isFavorite;
    setState(() => _isFavorite = newStatus);

    if (newStatus) {
      await ApiService.addFavorite(
        widget.movie.id,
        widget.movie.itemType,
        name: widget.movie.name,
        poster: widget.movie.poster,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Added to Favorites ❤️"),
            backgroundColor: Color(0xFFE50914),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      await ApiService.removeFavorite(widget.movie.id, widget.movie.itemType);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Removed from Favorites"),
            backgroundColor: Color(0xFF1E2436),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _startInstantPlay() async {
    setState(() => _isLoadingPlay = true);
    HapticFeedback.heavyImpact();

    try {
      final isSeries = widget.movie.isWebSeries;
      final typeStr = isSeries ? 'series' : 'movie';
      final res = await ApiService.fetchDetails(widget.movie.id, typeStr);

      if (res['status'] == 'success' && res['data'] != null) {
        final data = res['data'];
        String? playUrl;
        String playTitle = widget.movie.name;
        int contentType = isSeries ? 2 : 1;

        if (isSeries) {
          final seasonsRaw = data['seasons'] as List?;
          if (seasonsRaw != null && seasonsRaw.isNotEmpty) {
            final firstSeason = seasonsRaw.first;
            final epsRaw = (firstSeason['episodes'] as List?) ?? [];
            if (epsRaw.isNotEmpty) {
              final firstEp = epsRaw.first;
              final links = (firstEp['play_links'] as List?) ?? [];
              if (links.isNotEmpty) {
                playUrl = (links.first['url'] ?? '').toString().trim();
                final epName = (firstEp['name'] ?? firstEp['Episoade_Name'] ?? 'Episode 1').toString();
                playTitle = "${widget.movie.name} - $epName";
              }
            }
          }
        } else {
          final linksRaw = (data['play_links'] as List?) ?? [];
          if (linksRaw.isNotEmpty) {
            playUrl = (linksRaw.first['url'] ?? '').toString().trim();
          }
        }

        if (playUrl != null && playUrl.isNotEmpty) {
          if (mounted) {
            Navigator.of(context, rootNavigator: true).pop();
            await playVideo(
              widget.parentContext,
              playUrl,
              playTitle,
              contentId: widget.movie.id,
              contentType: contentType,
            );
          }
          return;
        }
      }

      // Fallback: Open details screen
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        navigateToContent(widget.parentContext, widget.movie.id, widget.movie.itemType);
      }
    } catch (_) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        navigateToContent(widget.parentContext, widget.movie.id, widget.movie.itemType);
      }
    } finally {
      if (mounted) setState(() => _isLoadingPlay = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.movie;
    final isSeries = m.isWebSeries;
    final ottName = m.networkName.isNotEmpty ? m.networkName : (m.genre.isNotEmpty ? m.genre : 'CINEMA');
    final tagBg = m.customTagBg.isNotEmpty ? _hexColor(m.customTagBg) : const Color(0xFFE50914);

    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            constraints: const BoxConstraints(maxWidth: 390),
            decoration: BoxDecoration(
              color: const Color(0xFF0F111A).withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: (tagBg ?? const Color(0xFFE50914)).withValues(alpha: 0.35),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.8),
                  blurRadius: 36,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: (tagBg ?? const Color(0xFFE50914)).withValues(alpha: 0.22),
                  blurRadius: 30,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Poster & Quick Info Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Poster with glow
                            Container(
                              width: 100,
                              height: 146,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.7),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: CachedNetworkImage(
                                  imageUrl: m.poster.isNotEmpty ? m.poster : m.banner,
                                  cacheManager: AppImageCache.posters,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => Container(
                                    color: const Color(0xFF1E2436),
                                    child: const Icon(Icons.movie_rounded, color: Colors.white38),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Metadata Column
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  // OTT Badge & Type
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                        decoration: BoxDecoration(
                                          color: tagBg ?? const Color(0xFFE50914),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          ottName.toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
                                        decoration: BoxDecoration(
                                          color: isSeries ? const Color(0xFF8E2DE2).withValues(alpha: 0.3) : const Color(0xFF00E676).withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: isSeries ? const Color(0xFF8E2DE2) : const Color(0xFF00E676),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Text(
                                          isSeries ? "SERIES" : "MOVIE",
                                          style: TextStyle(
                                            color: isSeries ? const Color(0xFFB388FF) : const Color(0xFF00E676),
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // Title
                                  Text(
                                    m.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.bold,
                                      height: 1.25,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),

                                  // Release Date / Genres
                                  if (m.releaseDate.isNotEmpty || m.genre.isNotEmpty)
                                    Text(
                                      [if (m.releaseDate.isNotEmpty) m.releaseDate, if (m.genre.isNotEmpty) m.genre].join(" • "),
                                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  const SizedBox(height: 6),

                                  // Description preview
                                  if (m.description.isNotEmpty)
                                    Text(
                                      m.description,
                                      style: const TextStyle(color: Colors.white38, fontSize: 10.5, height: 1.3),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Action 1: Instant Play Button (Watch Now / Watch Episode 1 Now)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isLoadingPlay ? null : _startInstantPlay,
                            icon: _isLoadingPlay
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.2),
                                  )
                                : const Icon(Icons.play_arrow_rounded, size: 22),
                            label: Text(
                              isSeries ? "▶ WATCH EPISODE 1 NOW" : "▶ WATCH NOW",
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13.5,
                                letterSpacing: 0.5,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00E676),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Action 2 & 3: Favorites & Full Details Row
                        Row(
                          children: [
                            // Favorite Button
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _toggleFavorite,
                                icon: Icon(
                                  _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                  color: _isFavorite ? const Color(0xFFE50914) : Colors.white70,
                                  size: 18,
                                ),
                                label: Text(
                                  _isFavorite ? "FAVORITED" : "FAVORITE",
                                  style: TextStyle(
                                    color: _isFavorite ? const Color(0xFFE50914) : Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: _isFavorite ? const Color(0xFFE50914).withValues(alpha: 0.12) : const Color(0xFF1E2230),
                                  side: BorderSide(
                                    color: _isFavorite ? const Color(0xFFE50914).withValues(alpha: 0.6) : Colors.white12,
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),

                            // View Details Button
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.of(context, rootNavigator: true).pop();
                                  navigateToContent(widget.parentContext, m.id, m.itemType);
                                },
                                icon: const Icon(Icons.info_outline_rounded, color: Colors.cyanAccent, size: 18),
                                label: const Text(
                                  "DETAILS",
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E2230),
                                  side: const BorderSide(color: Colors.white12),
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

                  // Close (X) button in top-right
                  Positioned(
                    top: 10,
                    right: 10,
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white12),
                        ),
                        child: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color? _hexColor(String hex) {
    var h = hex.replaceAll('#', '').trim();
    if (h.length == 6) h = 'FF$h';
    if (h.length != 8) return null;
    final v = int.tryParse(h, radix: 16);
    if (v == null) return null;
    return Color(v);
  }
}
