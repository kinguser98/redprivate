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
import '../services/luluvdo_resolver.dart';
import '../services/xhamster_resolver.dart';
import '../services/tnaflix_resolver.dart';
import '../services/hls_quality_parser.dart';
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

  debugPrint("[DL] handleDownloadAction: isMovie=${data.isMovie}, isSeries=${data.isSeries}, itemType=${data.movie.itemType}, playLinks=${data.playLinks.length}, seasons=${data.seasons.length}, seriesOverride=${data.seriesOverride}");

  // All content is premium: only active VIP subscribers can download
  if (!AppSession.isVip) {
    _showDownloadVipGate(context, data.movie.name);
    return;
  }

  // Web series: show the episode picker popup
  if (overrideUrl == null && data.isSeries) {
    debugPrint("[DL] → Showing series episode picker");
    _showSeriesEpisodePicker(context, data);
    return;
  }

  // Movie with multiple server links: show link selector popup
  if (overrideUrl == null && data.isMovie && data.playLinks.length > 1) {
    debugPrint("[DL] → Showing movie link picker (${data.playLinks.length} links)");
    _showMovieLinkPicker(context, data);
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

  debugPrint("[DL] → Calling _startDownload with url: $url");

  if (url.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("No downloadable link available.")),
    );
    return;
  }

  await _startDownload(context, url, data.movie.name, poster: data.movie.poster, contentId: data.movie.id, contentType: data.isMovie ? 1 : 2);
}

bool _isStreamtapeLike(String u) {
  final l = u.toLowerCase();
  return l.contains('streamtape') ||
      l.contains('strcloud') ||
      l.contains('strcolud') ||
      l.contains('tapepops') ||
      l.contains('tpead') ||
      l.contains('tapecontent') ||
      l.contains('advtpe') ||
      l.contains('advtape') ||
      l.contains('adtape') ||
      l.contains('shavetape') ||
      l.contains('adblocktape') ||
      l.contains('stape.fun') ||
      l.contains('streamta.pe') ||
      l.contains('vercel') ||
      l.contains('koyeb');
}

// Resolves Streamtape & Luluvdo links on the phone IP so tickets match the device IP
Future<void> _startDownload(BuildContext context, String rawUrl, String title,
    {String poster = '', int? contentId, int? contentType}) async {
  if (rawUrl.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("No downloadable link found for this video.")),
    );
    return;
  }

  debugPrint("[DL] _startDownload rawUrl=$rawUrl");
  debugPrint("[DL] isStreamtapeLike=${_isStreamtapeLike(rawUrl)}, isStreamtapeFamily=${StreamtapeService.isStreamtapeFamily(rawUrl)}");

  showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.6),
    builder: (_) => ResolvingProgressDialog(
      title: title,
      subtitle: 'Preparing Download Link...',
    ),
  );

  debugPrint("[DL] Resolving dialog shown");

  String url = rawUrl;
  Map<String, String>? availableQualities;

  try {
    final lowerRaw = rawUrl.toLowerCase();
    if (XHamsterResolver.isXHamsterUrl(rawUrl)) {
      final res = await XHamsterResolver.resolveQualities(rawUrl, forceRefresh: true);
      if (res != null && res.defaultUrl.isNotEmpty) {
        url = res.defaultUrl;
        availableQualities = res.qualities;
      }
    } else if (TnaflixResolver.isTnaflixUrl(rawUrl)) {
      final res = await TnaflixResolver.resolveQualities(rawUrl, forceRefresh: true);
      if (res != null && res.defaultUrl.isNotEmpty) {
        url = res.defaultUrl;
        availableQualities = res.qualities;
      }
    } else if (lowerRaw.contains('luluvdo') || lowerRaw.contains('lulustream') || lowerRaw.contains('lulucdn') || lowerRaw.contains('tnmr')) {
      final resolved = await LuluvdoResolver.resolveOnDevice(rawUrl, forceRefresh: true);
      if (resolved != null && resolved.isNotEmpty) {
        url = resolved;
      }
    } else if (_isStreamtapeLike(rawUrl) ||
        StreamtapeService.isStreamtapeFamily(rawUrl) ||
        lowerRaw.contains('uplinks')) {
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

  // Parse HLS master playlist if availableQualities is empty
  if (availableQualities == null || availableQualities.isEmpty) {
    if (url.contains('.m3u8')) {
      availableQualities = await HlsQualityParser.parseQualities(url);
    }
  }

  // Show Download Quality Selection Popup:
  // - For xHamster: always show if at least 1 quality available (user wants to see/confirm)
  // - For others: only show if multiple qualities extracted
  final isXHamster = XHamsterResolver.isXHamsterUrl(rawUrl);
  String? chosenUrl = url;
  if (availableQualities != null && availableQualities.isNotEmpty &&
      (availableQualities.length > 1 || isXHamster) && context.mounted) {
    chosenUrl = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  width: 310,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161A26).withOpacity(0.95),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.6),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.download_for_offline_rounded, color: Colors.cyanAccent, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                "Download Quality",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: () => Navigator.of(ctx).pop(null),
                            child: const Icon(Icons.close_rounded, color: Colors.white60, size: 20),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      const Divider(color: Colors.white12, height: 1),
                      const SizedBox(height: 8),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: availableQualities!.entries.map((e) {
                              final qLabel = e.key;
                              final qUrl = e.value;
                              final isDefault = qLabel.contains('720p') || qLabel.contains('HD');

                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 3),
                                decoration: BoxDecoration(
                                  color: isDefault ? const Color(0xFF231F10) : const Color(0xFF0F121C),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isDefault ? Colors.amberAccent : Colors.white10,
                                  ),
                                ),
                                child: ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                  leading: Icon(
                                    isDefault ? Icons.star_rounded : Icons.file_download_outlined,
                                    color: isDefault ? Colors.amberAccent : Colors.cyanAccent,
                                    size: 18,
                                  ),
                                  title: Text(
                                    qLabel,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: isDefault ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                  trailing: const Icon(Icons.download_rounded, color: Colors.white70, size: 16),
                                  onTap: () => Navigator.of(ctx).pop(qUrl),
                                ),
                              );
                            }).toList(),
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
      },
    );
  }

  if (chosenUrl == null || chosenUrl.isEmpty) {
    return;
  }

  final task = await DownloadManager.instance.start(chosenUrl, title, poster: poster, originalUrl: rawUrl, contentId: contentId, contentType: contentType);
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
                                              poster: data.movie.poster,
                                              contentId: data.movie.id,
                                              contentType: 2);
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

void _showMovieLinkPicker(BuildContext context, DetailsData data) {
  showDialog(
    context: context,
    barrierColor: Colors.black.withOpacity(0.65),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
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
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 14, 10, 14),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF8E2DE2), Color(0xFFE50914)]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.download_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('SELECT DOWNLOAD LINK',
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
                ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(14),
                  itemCount: data.playLinks.length,
                  itemBuilder: (ctx, i) {
                    final link = data.playLinks[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          Navigator.pop(ctx);
                           _startDownload(context, link.url, '${data.movie.name} (${link.name})', poster: data.movie.poster, contentId: data.movie.id, contentType: 1);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF232A3C).withOpacity(0.9),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.movie_rounded, color: Colors.cyanAccent, size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(link.name.isNotEmpty ? link.name : 'Server ${i + 1}',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                    if (link.quality.isNotEmpty)
                                      Text(link.quality, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.download_rounded, color: Colors.greenAccent, size: 20),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
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
