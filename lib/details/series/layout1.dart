import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/movie_model.dart';
import '../../screens/download_helper.dart';
import '../../widgets/more_like_this_row.dart';
import '../details_data.dart';
import '../../services/api_service.dart';
import '../../models/user_model.dart';

class AuroraGlassSeriesLayout extends StatefulWidget {
  final DetailsData data;
  final VoidCallback onPlay;
  final VoidCallback onWatchlist;
  final VoidCallback onShare;
  final void Function(String, String) onPlayEpisode;
  final void Function(int, String) onNavigateToContent;

  const AuroraGlassSeriesLayout({
    super.key,
    required this.data,
    required this.onPlay,
    required this.onWatchlist,
    required this.onShare,
    required this.onPlayEpisode,
    required this.onNavigateToContent,
  });

  @override
  State<AuroraGlassSeriesLayout> createState() =>
      _AuroraGlassSeriesLayoutState();
}

class _AuroraGlassSeriesLayoutState extends State<AuroraGlassSeriesLayout> {
  final ScrollController _scrollController = ScrollController();
  SeasonModel? _selectedSeason;
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    if (widget.data.seasons.isNotEmpty) {
      _selectedSeason = widget.data.seasons.first;
    }
  }

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
          // Background Backdrop with Gradient Blur
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

          // Main Scrollable Content
          SafeArea(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Navigation Bar (Back & Share)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _circularIconButton(
                          icon: Icons.chevron_left_rounded,
                          onTap: () => Navigator.pop(context),
                        ),
                        _circularIconButton(
                          icon: Icons.share_rounded,
                          onTap: widget.onShare,
                        ),
                      ],
                    ),
                  ),

                  // Hero Poster + Title & Badges
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Floating Poster
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
                              color: const Color(0xFF9333EA).withOpacity(0.35),
                              blurRadius: 20,
                              spreadRadius: -4,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: CachedNetworkImage(
                            imageUrl: movie.poster,
                            fit: BoxFit.cover,
                            errorWidget: (c, u, e) =>
                                Container(color: const Color(0xFF1E1E28)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Title + Metadata Badges + Rating
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
                            // Season & Episode Badges
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _metadataPill(
                                  icon: Icons.layers_rounded,
                                  label:
                                      '${data.totalSeasons} Season${data.totalSeasons != 1 ? 's' : ''}',
                                ),
                                _metadataPill(
                                  icon: Icons.videocam_rounded,
                                  label:
                                      '${data.totalEpisodes} Episodes',
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Rating Star
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

                  // Main CTAs: Watch Now (Yellow) & Favorite (Dark)
                  Row(
                    children: [
                      // Watch Now Button
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFB703),
                              foregroundColor: Colors.black,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: widget.onPlay,
                            icon: const Icon(Icons.play_arrow_rounded,
                                color: Colors.black, size: 24),
                            label: const Text(
                              'Watch Now',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
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

                  // Secondary Action Tiles (Trailer, Download, Share)
                  Row(
                    children: [
                      Expanded(
                        child: _actionTile(
                          icon: Icons.flag_rounded,
                          label: 'Report',
                          onTap: _showReportDialog,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _actionTile(
                          icon: Icons.file_download_outlined,
                          label: 'Download',
                          onTap: () => handleDownloadAction(context, widget.data),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _actionTile(
                          icon: Icons.share_outlined,
                          label: 'Share',
                          onTap: widget.onShare,
                        ),
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
                        : 'Story : ${movie.name} Free Download & Watch Online Only On',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Seasons & Episodes Section
                  const Text(
                    'Seasons & Episodes',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Season Pills (Purple)
                  if (data.seasons.isNotEmpty) ...[
                    SizedBox(
                      height: 42,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: data.seasons.length,
                        itemBuilder: (context, index) {
                          final season = data.seasons[index];
                          final isSelected = _selectedSeason == season;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedSeason = season),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(right: 10),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 22, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF9333EA)
                                    : const Color(0xFF14141E),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFFC084FC)
                                      : Colors.white12,
                                ),
                              ),
                              child: Text(
                                season.seasonName,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Episode Cards List
                    if (_selectedSeason != null)
                      ...(_selectedSeason!.episodes.map((ep) {
                        final rawUrl = ep.playLinks.isNotEmpty
                            ? ep.playLinks.first.url
                            : '';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF14141E),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.08)),
                          ),
                          child: Row(
                            children: [
                              // Episode Thumbnail with overlay play icon
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SizedBox(
                                  width: 110,
                                  height: 68,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      CachedNetworkImage(
                                        imageUrl: ep.image.isNotEmpty
                                            ? ep.image
                                            : movie.poster,
                                        width: 110,
                                        height: 68,
                                        fit: BoxFit.cover,
                                        errorWidget: (c, u, e) => Container(
                                          color: const Color(0xFF1E1E28),
                                        ),
                                      ),
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.black.withOpacity(0.5),
                                        ),
                                        child: const Icon(
                                          Icons.play_arrow_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              // Episode Title + Subtitle + Quality Tag
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ep.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Watch Now',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.5),
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF6366F1)
                                            .withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: const Color(0xFF818CF8)
                                              .withOpacity(0.5),
                                        ),
                                      ),
                                      child: Text(
                                        ep.playLinks.isNotEmpty
                                            ? ep.playLinks.first.quality
                                            : '720p',
                                        style: const TextStyle(
                                          color: Color(0xFFA5B4FC),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Right Play Button
                              IconButton(
                                icon: const Icon(
                                  Icons.play_circle_fill_rounded,
                                  color: Colors.white70,
                                  size: 36,
                                ),
                                onPressed: rawUrl.isNotEmpty
                                    ? () => widget.onPlayEpisode(rawUrl, ep.name)
                                    : widget.onPlay,
                              ),
                            ],
                          ),
                        );
                      })),
                  ],

                  // More Like This (same genre / OTT)
                  if (widget.data.related.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    MoreLikeThisRow(
                      items: widget.data.related,
                      itemType: 'series',
                      onTap: widget.onNavigateToContent,
                    ),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
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
                            2, // 2 = Web Series
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withOpacity(0.4),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _metadataPill({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1428),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFA855F7).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFFC084FC), size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: const Color(0xFF14141E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white70, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
