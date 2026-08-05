import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../details/details_data.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/download_service.dart';
import '../services/streamtape_service.dart';
import '../services/embed_resolver.dart';
import '../widgets/resolving_dialog.dart';
import 'downloads_screen.dart';
import 'subscription_vip_screen.dart';

Future<void> handleDownloadAction(BuildContext context, DetailsData data,
    {String? overrideUrl}) async {
  // Refresh VIP status from the server so admin grants / coupon redemptions take effect
  final uid = AppSession.user?.id ?? 0;
  if (uid > 0) {
    final fresh = await ApiService.refreshUser(uid);
    if (fresh != null) {
      AppSession.user = fresh;
      await ApiService.saveUserSession(fresh);
    }
  }

  // All content is premium: only active VIP subscribers can download
  if (!AppSession.isVip) {
    _showDownloadVipGate(context, data.movie.name);
    return;
  }

  // Web series: show an episode picker so the user chooses what to download
  if (overrideUrl == null && data.seasons.isNotEmpty) {
    _showSeriesEpisodePicker(context, data);
    return;
  }

  String url = overrideUrl ?? '';
  if (url.isEmpty && data.playLinks.isNotEmpty) {
    url = data.playLinks.first.url;
  }
  if (url.isEmpty && data.seasons.isNotEmpty && data.seasons.first.episodes.isNotEmpty) {
    final ep = data.seasons.first.episodes.first;
    if (ep.playLinks.isNotEmpty) url = ep.playLinks.first.url;
  }

  if (url.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("No downloadable link available.")),
    );
    return;
  }

  await _startDownload(context, url, data.movie.name, poster: data.movie.poster);
}

bool _isStreamtapeLike(String u) {
  final l = u.toLowerCase();
  return l.contains('streamtape') ||
      l.contains('strcloud') ||
      l.contains('tapepops') ||
      l.contains('tpead') ||
      l.contains('tapecontent') ||
      l.contains('vercel') ||
      l.contains('koyeb');
}

// Resolves Streamtape links on the phone IP so tickets match the device IP
Future<void> _startDownload(BuildContext context, String rawUrl, String title,
    {String poster = ''}) async {
  if (rawUrl.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("No downloadable link found for this video.")),
    );
    return;
  }

  showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.6),
    builder: (_) => ResolvingProgressDialog(
      title: title,
      subtitle: 'Preparing Download Link...',
    ),
  );

  String url = rawUrl;
  try {
    if (_isStreamtapeLike(rawUrl) || StreamtapeService.isStreamtapeFamily(rawUrl)) {
      String? resolved = await StreamtapeService.getDirectStreamUrl(rawUrl);
      if ((resolved == null || resolved.isEmpty || !resolved.startsWith('http')) && context.mounted) {
        resolved = await EmbedResolver.resolve(context, rawUrl);
      }
      if (resolved != null && resolved.isNotEmpty && resolved.startsWith('http')) {
        url = resolved;
      }
    }
  } catch (e) {
    print("Download resolution error: $e");
  } finally {
    if (context.mounted) Navigator.pop(context);
  }

  if (!url.startsWith('http')) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not resolve downloadable stream link.")),
      );
    }
    return;
  }

  final task = await DownloadManager.instance.start(url, title, poster: poster, originalUrl: rawUrl);
  if (!context.mounted) return;
  if (task == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Download could not be started.")),
    );
    return;
  }
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

// Episode picker for web series downloads (modern centered popup)
void _showSeriesEpisodePicker(BuildContext context, DetailsData data) {
  final seasons = data.seasons;
  showDialog(
    context: context,
    barrierColor: Colors.black.withOpacity(0.65),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            width: double.maxFinite,
            constraints: const BoxConstraints(maxWidth: 430),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1E2436), Color(0xFF0D0F16)],
              ),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.55), blurRadius: 40, offset: const Offset(0, 18)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 14, 10, 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF8E2DE2).withOpacity(0.30),
                        const Color(0xFFE50914).withOpacity(0.16),
                        Colors.transparent,
                      ],
                    ),
                    border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF8E2DE2), Color(0xFFE50914)]),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFF8E2DE2).withOpacity(0.4), blurRadius: 14, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: const Icon(Icons.download_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('DOWNLOAD EPISODES',
                                style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.4)),
                            const SizedBox(height: 2),
                            Text(data.movie.name,
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white60), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Flexible(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(ctx).size.height * 0.7,
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
                      itemCount: seasons.length,
                    itemBuilder: (ctx, si) {
                      final season = seasons[si];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
                            child: Text(season.seasonName,
                                style: const TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                          ),
                          ...season.episodes.map((ep) {
                            final hasLink = ep.playLinks.isNotEmpty;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: hasLink
                                    ? () {
                                        Navigator.pop(ctx);
                                        _startDownload(context, ep.playLinks.first.url,
                                            '${data.movie.name} — ${season.seasonName} ${ep.name}',
                                            poster: data.movie.poster);
                                      }
                                    : null,
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [const Color(0xFF232A3C).withOpacity(0.9), const Color(0xFF161B28).withOpacity(0.9)],
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: hasLink ? Colors.white.withOpacity(0.08) : Colors.white10),
                                  ),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: ep.image.isNotEmpty
                                            ? CachedNetworkImage(
                                                imageUrl: ep.image, width: 44, height: 44, fit: BoxFit.cover,
                                                errorWidget: (c, u, e) => Container(width: 44, height: 44, color: const Color(0xFF2A3145), child: const Icon(Icons.tv, color: Colors.white24)))
                                            : Container(width: 44, height: 44, color: const Color(0xFF2A3145), child: const Icon(Icons.tv, color: Colors.white24)),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(ep.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                            const SizedBox(height: 2),
                                            Text(hasLink ? 'Tap to download' : 'No playable link',
                                                style: TextStyle(color: hasLink ? Colors.white54 : Colors.redAccent, fontSize: 11)),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: hasLink ? Colors.greenAccent.withOpacity(0.15) : Colors.white10,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(Icons.download_rounded, color: hasLink ? Colors.greenAccent : Colors.white24, size: 18),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      );
                    },
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

void _showDownloadVipGate(BuildContext context, String title) {
  showDialog(
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
        "VIP Required to Download",
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: Text(
        "'$title' is a premium/VIP title. Only active VIP subscribers can download this content.",
        style: const TextStyle(color: Colors.white70),
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
