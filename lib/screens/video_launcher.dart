import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/streamtape_service.dart';
import '../services/embed_resolver.dart';
import '../widgets/resolving_dialog.dart';
import 'subscription_vip_screen.dart';
import 'video_player_screen.dart';

Future<void> playVideo(
    BuildContext context, String rawUrl, String title,
    {bool premium = false}) async {
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

    if (StreamtapeService.isDirectMediaUrl(rawUrl)) {
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
        builder: (_) =>
            VideoPlayerScreen(videoUrl: finalUrl!, videoTitle: title),
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
