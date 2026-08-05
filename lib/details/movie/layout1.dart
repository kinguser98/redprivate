import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/movie_model.dart';
import '../../services/app_image_cache.dart';
import '../../screens/all_movies_series_screen.dart';
import '../../screens/download_helper.dart';
import '../../widgets/more_like_this_row.dart';
import '../details_data.dart';
import '../../services/api_service.dart';
import '../../models/user_model.dart';

class AuroraGlassLayout extends StatefulWidget {
  final DetailsData data;
  final VoidCallback onPlay;
  final VoidCallback onWatchlist;
  final VoidCallback onShare;
  final void Function(String, String) onPlayEpisode;
  final void Function(int, String) onNavigateToContent;

  const AuroraGlassLayout({
    super.key,
    required this.data,
    required this.onPlay,
    required this.onWatchlist,
    required this.onShare,
    required this.onPlayEpisode,
    required this.onNavigateToContent,
  });

  @override
  State<AuroraGlassLayout> createState() => _AuroraGlassLayoutState();
}

class _AuroraGlassLayoutState extends State<AuroraGlassLayout> {
  final ScrollController _scrollController = ScrollController();
  bool _isFavorite = false;
  bool _inWatchlist = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final movie = data.movie;

    return Scaffold(
      backgroundColor: const Color(0xFF09090D),
      body: Stack(
        children: [
          // 1. Background Backdrop Image with Gradient Scrim & Blur
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 380,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: movie.banner.isNotEmpty ? movie.banner : movie.poster,
                  fit: BoxFit.cover,
                  cacheManager: AppImageCache.posters,
                  memCacheWidth: AppImageCache.posterMaxWidth,
                  memCacheHeight: AppImageCache.posterMaxHeight,
                  errorWidget: (c, u, e) => Container(color: const Color(0xFF14141C)),
                ),
                ClipRect(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black38,
                            Colors.black26,
                            Color(0xFF09090D),
                          ],
                          stops: [0.0, 0.45, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Main Scrollable Content
          SafeArea(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Spacing for floating buttons
                  const SizedBox(height: 54),

                  // Hero Poster + Title & Badges
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Floating Poster with Deep 3D Shadow & Border
                      Container(
                        width: 125,
                        height: 175,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.18),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.85),
                              blurRadius: 24,
                              spreadRadius: 2,
                              offset: const Offset(0, 10),
                            ),
                            BoxShadow(
                              color: const Color(0xFFE50914).withOpacity(0.35),
                              blurRadius: 20,
                              spreadRadius: -4,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: CachedNetworkImage(
                            imageUrl: movie.poster,
                            fit: BoxFit.cover,
                            cacheManager: AppImageCache.posters,
                            memCacheWidth: AppImageCache.posterMaxWidth,
                            memCacheHeight: AppImageCache.posterMaxHeight,
                            errorWidget: (c, u, e) =>
                                Container(color: const Color(0xFF1E1E28)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Title + Metadata Badges
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              movie.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),
                            // Metadata Badges
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _metaBadge(
                                  movie.releaseDate.isNotEmpty
                                      ? movie.releaseDate
                                      : '2025',
                                ),
                                _metaBadge(
                                  movie.customTag.isNotEmpty
                                      ? movie.customTag
                                      : '1080p � HD',
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Rating Star (Without TMDb/IMDb logo)
                            Row(
                              children: [
                                const Icon(Icons.star_rounded,
                                    color: Colors.amber, size: 20),
                                const SizedBox(width: 6),
                                Text(
                                  movie.rating.isNotEmpty &&
                                          movie.rating != '0' &&
                                          movie.rating != '0.0'
                                      ? movie.rating
                                      : '8.5',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Main CTAs: Watch Now (Red/Yellow) & Favorite (Dark)
                  Row(
                    children: [
                      // Watch Now Button
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE50914),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: widget.onPlay,
                            icon: const Icon(Icons.play_arrow_rounded,
                                color: Colors.white, size: 24),
                            label: const Text(
                              'Watch Now',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Favorite Button
                      SizedBox(
                        height: 52,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: const Color(0xFF14141E).withOpacity(0.8),
                            foregroundColor: Colors.white,
                            side: BorderSide(
                                color: Colors.white.withOpacity(0.18)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                          ),
                          onPressed: () {
                            setState(() => _isFavorite = !_isFavorite);
                            widget.onWatchlist();
                          },
                          icon: Icon(
                            _isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: _isFavorite ? Colors.redAccent : Colors.white,
                            size: 20,
                          ),
                          label: const Text(
                            'Favorite',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Secondary Action Grid (Trailer, Download, Watchlist, OTT Provider)
                  Row(
                    children: [
                      _actionCard(
                        icon: Icons.flag_rounded,
                        label: 'Report',
                        onTap: _showReportDialog,
                      ),
                      _actionCard(
                        icon: Icons.file_download_outlined,
                        label: 'Download',
                        onTap: () => handleDownloadAction(context, widget.data),
                      ),
                      _actionCard(
                        icon: _inWatchlist
                            ? Icons.playlist_add_check_rounded
                            : Icons.playlist_add_rounded,
                        label: 'Watchlist',
                        onTap: () {
                          setState(() => _inWatchlist = !_inWatchlist);
                          widget.onWatchlist();
                        },
                      ),
                      if (data.ottName != null && data.ottName!.isNotEmpty)
                        _actionCard(
                          logoUrl: data.ottLogo,
                          label: data.ottName!,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AllMoviesSeriesScreen(
                                  initialSearch: data.ottName!,
                                  initialNetworkId: data.ottId ?? 0,
                                  title: data.ottName!,
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Synopsis Section
                  const Text(
                    'Synopsis',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    movie.description.isNotEmpty
                        ? movie.description
                        : 'Enjoy premium movie streaming of ${movie.name} in full HD quality.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Featured Cast Section
                  if (data.castMembers.isNotEmpty) ...[
                    const Text(
                      'Featured Cast',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 105,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: data.castMembers.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 14),
                        itemBuilder: (context, index) {
                          final actor = data.castMembers[index];
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AllMoviesSeriesScreen(
                                    initialSearch: actor.name,
                                    title: actor.name,
                                  ),
                                ),
                              );
                            },
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF14141E),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: actor.profileUrl.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: actor.profileUrl,
                                            fit: BoxFit.cover,
                                            errorWidget: (c, u, e) => const Icon(
                                              Icons.person_rounded,
                                              color: Colors.white30,
                                              size: 24,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.person_rounded,
                                            color: Colors.white30,
                                            size: 24,
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: 80,
                                  child: Text(
                                    actor.name,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Bottom Grid Info Container
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      border: Border.all(color: Colors.white10, width: 0.8),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        _bottomGridItem(
                          icon: Icons.language_rounded,
                          title: 'Language',
                          value: 'Hindi',
                        ),
                        _verticalDivider(),
                        _bottomGridItem(
                          icon: Icons.volume_up_rounded,
                          title: 'Audio',
                          value: '5.1 Surround',
                        ),
                        _verticalDivider(),
                        _bottomGridItem(
                          icon: Icons.closed_caption_rounded,
                          title: 'Subtitles',
                          value: 'English',
                        ),
                        _verticalDivider(),
                        _bottomGridItem(
                          icon: Icons.hd_rounded,
                          title: 'Quality',
                          value: '1080p � HD',
                        ),
                      ],
                    ),
                  ),

                  // More Like This (same genre / OTT)
                  if (data.related.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    MoreLikeThisRow(
                      items: data.related,
                      itemType: 'movie',
                      onTap: widget.onNavigateToContent,
                    ),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // 3. Floating Top App Bar (Back & Share)
          Positioned(
            left: 16,
            right: 16,
            top: MediaQuery.of(context).padding.top + 6,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _circularIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
                _circularIconButton(
                  icon: Icons.share_rounded,
                  onTap: widget.onShare,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showReportDialog() {
    final TextEditingController reasonController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF14141C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              title: Row(
                children: const [
                  Icon(Icons.report_problem_rounded, color: Color(0xFFFF1744)),
                  SizedBox(width: 10),
                  Text("Report Content", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Describe the issue (e.g. broken link, bad audio, wrong language):",
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonController,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: "Enter the reason for reporting...",
                      hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFFF1744)),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final msg = reasonController.text.trim();
                          if (msg.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Please enter a reason.")),
                            );
                            return;
                          }
                          setDialogState(() => isSubmitting = true);
                          final userId = AppSession.user?.id ?? 0;
                          final success = await ApiService.submitReport(
                            userId,
                            widget.data.movie.id,
                            1, // 1 = Movie
                            msg,
                          );
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(success
                                    ? "Report submitted successfully! Thank you."
                                    : "Failed to submit report. Please try again."),
                                backgroundColor: success ? Colors.green : Colors.red,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF1744),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text("Submit", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _circularIconButton({required IconData icon, required VoidCallback onTap}) {
    return ClipOval(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          color: Colors.black26,
          child: IconButton(
            icon: Icon(icon, color: Colors.white, size: 18),
            onPressed: onTap,
          ),
        ),
      ),
    );
  }

  Widget _metaBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _actionCard({
    IconData? icon,
    String? logoUrl,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            border: Border.all(color: Colors.white10, width: 0.8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (logoUrl != null && logoUrl.isNotEmpty)
                Container(
                  width: 22,
                  height: 22,
                  decoration: BorderRadius.circular(4) != null
                      ? BoxDecoration(borderRadius: BorderRadius.circular(4))
                      : null,
                  clipBehavior: Clip.antiAlias,
                  child: Image.network(
                    logoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.tv_rounded, color: Colors.white, size: 20),
                  ),
                )
              else
                Icon(icon ?? Icons.tv_rounded, color: Colors.white70, size: 20),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomGridItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF3B82F6), size: 20),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFFFB300),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(width: 0.8, height: 40, color: Colors.white10);
  }
}
