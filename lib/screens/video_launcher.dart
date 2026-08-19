import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/aagmaal_resolver.dart';
import '../services/streamtape_service.dart';
import '../services/embed_resolver.dart';
import '../services/luluvdo_resolver.dart';
import '../services/xhamster_resolver.dart';
import '../services/eporner_resolver.dart';
import '../services/tnaflix_resolver.dart';
import '../widgets/resolving_dialog.dart';
import 'subscription_vip_screen.dart';
import 'video_player_screen.dart';

Future<void> playVideo(
    BuildContext context, String rawUrl, String title,
    {bool premium = false,
    int? contentId,
    int? contentType,
    Map<String, String>? qualities,
    String? initialQuality,
    Map<String, String>? headers,
    List<Map<String, dynamic>>? playlist,
    int initialEpisodeIndex = 0}) async {
  // Refresh VIP status from the server so admin grants / coupon redemptions take effect
  final uid = AppSession.user?.id ?? 0;
  if (uid > 0) {
    final fresh = await ApiService.refreshUser(uid);
    if (fresh != null) {
      AppSession.user = fresh;
      await ApiService.saveUserSession(fresh);
    }
  }

  // All content is premium: only active VIP subscribers can play
  if (!AppSession.isVip) {
    _showVipGate(context, title);
    return;
  }

  if (rawUrl.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("No playable link found for this video.")),
    );
    return;
  }

  showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.6),
    builder: (_) => ResolvingProgressDialog(
      title: title,
      subtitle: 'Resolving Stream...',
    ),
  );

  try {
    String? finalUrl;
    final lowerRaw = rawUrl.toLowerCase();

    Map<String, String>? streamQualities;
    String? currentQuality;

    if (qualities != null && qualities.isNotEmpty) {
      finalUrl = rawUrl;
      streamQualities = qualities;
      currentQuality = initialQuality;
    } else if (AagmaalResolver.isAagmaalUrl(rawUrl)) {
      finalUrl = await AagmaalResolver.resolveStream(rawUrl);
    } else if (lowerRaw.contains('.mp4') || lowerRaw.contains('.m3u8') || lowerRaw.contains('rdtcdn') || lowerRaw.contains('sb-cdn') || lowerRaw.contains('spankbang')) {
      finalUrl = rawUrl;
    } else if (XHamsterResolver.isXHamsterUrl(rawUrl)) {
      final res = await XHamsterResolver.resolveQualities(rawUrl, forceRefresh: true);
      if (res != null && res.defaultUrl.isNotEmpty) {
        finalUrl = res.defaultUrl;
        streamQualities = res.qualities;
        currentQuality = res.defaultQuality;
      } else if (context.mounted) {
        finalUrl = await EmbedResolver.resolve(context, rawUrl);
      }
    } else if (EpornerResolver.isEpornerUrl(rawUrl)) {
      if (EpornerResolver.isEpornerMediaUrl(rawUrl)) {
        // Already a resolved (client-IP-bound) CDN link — play it directly.
        finalUrl = rawUrl;
      } else {
        final res = await EpornerResolver.resolveQualities(rawUrl, forceRefresh: true);
        if (res != null && res.defaultUrl.isNotEmpty) {
          finalUrl = res.defaultUrl;
          streamQualities = res.qualities;
          currentQuality = res.defaultQuality;
        } else if (context.mounted) {
          finalUrl = await EmbedResolver.resolve(context, rawUrl);
        }
      }
    } else if (TnaflixResolver.isTnaflixUrl(rawUrl)) {
      if (TnaflixResolver.isTnaflixMediaUrl(rawUrl)) {
        // Already a playable signed CDN URL — play it directly.
        finalUrl = rawUrl;
      } else {
        final res = await TnaflixResolver.resolveQualities(rawUrl, forceRefresh: true);
        if (res != null && res.defaultUrl.isNotEmpty) {
          finalUrl = res.defaultUrl;
          streamQualities = res.qualities;
          currentQuality = res.defaultQuality;
        } else if (context.mounted) {
          finalUrl = await EmbedResolver.resolve(context, rawUrl);
        }
      }
    } else if (lowerRaw.contains('luluvdo') || lowerRaw.contains('lulustream') || lowerRaw.contains('lulucdn')) {
      finalUrl = await LuluvdoResolver.resolveOnDevice(rawUrl, forceRefresh: true);
    } else if (StreamtapeService.isDirectMediaUrl(rawUrl)) {
      finalUrl = rawUrl;
    } else {
      String? resolved = await StreamtapeService.getDirectStreamUrl(rawUrl, forceRefresh: true);
      if ((resolved == null ||
              resolved.isEmpty ||
              !resolved.startsWith('http')) &&
          context.mounted) {
        resolved = await EmbedResolver.resolve(context, rawUrl);
      }
      if (resolved != null && resolved.isNotEmpty && resolved.startsWith('http')) {
        finalUrl = resolved;
      }
    }

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    if (finalUrl == null || finalUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "Could not resolve this stream. It may be dead or removed."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(
          videoUrl: finalUrl!,
          videoTitle: title,
          contentId: contentId,
          contentType: contentType,
          qualities: qualities ?? streamQualities,
          initialQuality: initialQuality ?? currentQuality,
          headers: headers,
          playlist: playlist,
          initialEpisodeIndex: initialEpisodeIndex,
        ),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to resolve stream: $e')),
    );
  }
}

Future<void> playVideoWithServerSelection(
    BuildContext context, List<dynamic> playLinks, String title,
    {bool premium = false, int? contentId, int? contentType, String defaultFallbackUrl = ''}) async {

  if (playLinks.isEmpty) {
    if (defaultFallbackUrl.isNotEmpty) {
      await playVideo(context, defaultFallbackUrl, title, premium: premium, contentId: contentId, contentType: contentType);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No playable video servers available.")),
      );
    }
    return;
  }

  // Filter active links with non-empty URL
  final activeLinks = playLinks.where((link) {
    final u = (link['url'] ?? link['link'] ?? '').toString().trim();
    return u.isNotEmpty;
  }).toList();

  if (activeLinks.isEmpty) {
    if (defaultFallbackUrl.isNotEmpty) {
      await playVideo(context, defaultFallbackUrl, title, premium: premium, contentId: contentId, contentType: contentType);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No active video links found.")),
      );
    }
    return;
  }

  if (activeLinks.length == 1) {
    final singleUrl = (activeLinks.first['url'] ?? activeLinks.first['link'] ?? '').toString().trim();
    await playVideo(context, singleUrl, title, premium: premium, contentId: contentId, contentType: contentType);
    return;
  }

  // Multi-link: Show sleek "Select Server" Centered Popup (Auto-sizing)
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
                width: 330,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1E2436), Color(0xFF0D0F16)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.6),
                      blurRadius: 30,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.amberAccent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.dns_rounded, color: Colors.amberAccent, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Select Play Server",
                                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                title,
                                style: const TextStyle(color: Colors.white60, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(modalCtx),
                          child: const Icon(Icons.close_rounded, color: Colors.white60, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Colors.white12, height: 1),
                    const SizedBox(height: 12),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: activeLinks.asMap().entries.map((entry) {
                            final index = entry.key;
                            final link = entry.value;
                            final serverName = (link['name'] != null && link['name'].toString().trim().isNotEmpty)
                                ? link['name'].toString().trim()
                                : "Server ${index + 1}";
                            final quality = link['quality'] ?? 'HD';
                            final url = (link['url'] ?? link['link'] ?? '').toString().trim();

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF161B22),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                leading: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.amberAccent.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.play_arrow_rounded, color: Colors.amberAccent, size: 18),
                                ),
                                title: Text(
                                  serverName,
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  "Quality: $quality",
                                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                                ),
                                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 18),
                                onTap: () {
                                  Navigator.pop(modalCtx);
                                  playVideo(context, url, '$title ($serverName)', premium: premium, contentId: contentId, contentType: contentType);
                                },
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

void _showVipGate(BuildContext context, String title) {
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
        "VIP Content Locked",
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: Text(
        "'$title' is a premium/VIP title. Subscribe to VIP to watch and download this content.",
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
