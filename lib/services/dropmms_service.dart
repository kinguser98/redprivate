import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';
import 'streamtape_service.dart';

class DropmmsItem {
  final String title;
  final String topicUrl;
  final String categoryName;
  final String poster;
  final String date;
  final int replies;
  final int views;

  DropmmsItem({
    required this.title,
    required this.topicUrl,
    required this.categoryName,
    required this.poster,
    required this.date,
    this.replies = 0,
    this.views = 0,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'topic_url': topicUrl,
        'page_url': topicUrl,
        'category': categoryName,
        'poster': poster,
        'date': date,
        'replies': replies,
        'views': views,
        'is_dropmms': true,
      };
}

class DropmmsTopicDetails {
  final String title;
  final String topicUrl;
  final String categoryName;
  final String date;
  final List<String> images;
  final List<DropmmsMediaLink> videoLinks;
  final List<DropmmsMediaLink> downloadLinks;

  DropmmsTopicDetails({
    required this.title,
    required this.topicUrl,
    required this.categoryName,
    required this.date,
    required this.images,
    required this.videoLinks,
    required this.downloadLinks,
  });
}

class DropmmsMediaLink {
  final String name;
  final String url;
  final String host;
  final String type;
  final bool isDirectStreamable;

  DropmmsMediaLink({
    required this.name,
    required this.url,
    required this.host,
    required this.type,
    required this.isDirectStreamable,
  });
}

class DropmmsService {
  static const String baseUrl = 'https://dropmms.co';

  static const Map<String, String> categories = {
    'all': 'All Forums',
    '2-desi-new-videoz-hd-sd': 'Desi New Videos',
    '20-onlyfans-exclusive-leaks': 'OnlyFans Leaks',
    '6-desi-models-webcam-girls-lust-web-moviess-here': 'Desi Models & Movies',
    '58-social-media-famous-viral-paid-collections': 'Viral & Paid Packs',
    '49-watch-online-videoss': 'Watch Online',
    '3-desi-new-pictures-hd-sd': 'Desi Pictures',
    '5-overseas-desi-videoss-pics': 'Overseas Desi',
    '40-hollywood-hot-scenes': 'Hollywood Hot',
  };

  static final Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
    'Referer': 'https://dropmms.co/',
  };

  /// Fetch catalog list from DropMMS (by category or search query)
  static Future<List<DropmmsItem>> fetchCatalog({
    String category = 'all',
    String query = '',
    int page = 1,
  }) async {
    try {
      String fetchUrl;
      if (query.trim().isNotEmpty) {
        final q = Uri.encodeComponent(query.trim());
        fetchUrl = '$baseUrl/search/?q=$q&type=forums_topic&page=$page';
      } else if (category == 'all' || category.isEmpty) {
        fetchUrl = page > 1 ? '$baseUrl/discover/?page=$page' : '$baseUrl/';
      } else {
        final catSlug = category.endsWith('/') ? category : '$category/';
        fetchUrl = page > 1
            ? '$baseUrl/forum/${catSlug}page/$page/'
            : '$baseUrl/forum/$catSlug';
      }

      final uri = Uri.parse(fetchUrl);
      final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return [];

      final html = res.body;
      final results = <DropmmsItem>[];
      final seenUrls = <String>{};

      // Match topics in IPS Community Suite
      final rowReg = RegExp(
          r'<li[^>]+class="[^"]*ipsDataItem[^"]*"[^>]*>([\s\S]*?)<\/li>',
          caseSensitive: false);
      final rows = rowReg.allMatches(html);

      for (final r in rows) {
        final rowHtml = r.group(1) ?? '';
        final linkMatch = RegExp(
                r'<a[^>]+href="([^"]*\/topic\/[^"]+)"[^>]*title="([^"]*)"[^>]*>([\s\S]*?)<\/a>|<a[^>]+href="([^"]*\/topic\/[^"]+)"[^>]*>([\s\S]*?)<\/a>',
                caseSensitive: false)
            .firstMatch(rowHtml);

        if (linkMatch == null) continue;

        final topicUrl = (linkMatch.group(1) ?? linkMatch.group(4) ?? '').trim();
        if (topicUrl.isEmpty || topicUrl.contains('#') || seenUrls.contains(topicUrl)) continue;
        seenUrls.add(topicUrl);

        var title = (linkMatch.group(2) ?? linkMatch.group(3) ?? linkMatch.group(5) ?? '')
            .replaceAll(RegExp(r'<[^>]+>'), '')
            .trim();
        title = _unescapeHtml(title);
        if (title.length < 3) continue;

        // Poster / thumbnail
        var poster = '';
        final imgMatch = RegExp(r'<img[^>]+(?:data-src|src)="([^"]+)"', caseSensitive: false)
            .firstMatch(rowHtml);
        if (imgMatch != null) {
          final src = imgMatch.group(1) ?? '';
          if (!src.contains('spacer.png') &&
              !src.contains('avatar') &&
              !src.contains('theme') &&
              !src.contains('logo')) {
            poster = src;
          }
        }

        // Date
        var date = 'Recent';
        final dateMatch = RegExp(r'<time[^>]+datetime="([^"]+)"|<time[^>]*>([^<]+)<\/time>',
                caseSensitive: false)
            .firstMatch(rowHtml);
        if (dateMatch != null) {
          date = (dateMatch.group(2) ?? dateMatch.group(1) ?? 'Recent').trim();
        }

        // Category name
        var catName = categories[category] ?? 'DropMMS';
        final catMatch = RegExp(r'<a[^>]+href="[^"]*\/forum\/[^"]+"[^>]*>([^<]+)<\/a>',
                caseSensitive: false)
            .firstMatch(rowHtml);
        if (catMatch != null) {
          catName = catMatch.group(1)?.trim() ?? catName;
        }

        results.add(DropmmsItem(
          title: title,
          topicUrl: topicUrl,
          categoryName: catName,
          poster: poster,
          date: date,
        ));
      }

      // Fallback Pattern 2: direct topic links
      if (results.isEmpty) {
        final topicLinks = RegExp(
                r'<a[^>]+href="([^"]*\/topic\/[^"]+)"[^>]*>([\s\S]*?)<\/a>',
                caseSensitive: false)
            .allMatches(html);

        for (final tm in topicLinks) {
          final tUrl = tm.group(1)?.trim() ?? '';
          var tTitle = (tm.group(2) ?? '').replaceAll(RegExp(r'<[^>]+>'), '').trim();
          tTitle = _unescapeHtml(tTitle);

          if (tUrl.isNotEmpty &&
              tTitle.length > 5 &&
              !tUrl.contains('#') &&
              !tUrl.contains('page=') &&
              !seenUrls.contains(tUrl)) {
            seenUrls.add(tUrl);
            results.add(DropmmsItem(
              title: tTitle,
              topicUrl: tUrl,
              categoryName: categories[category] ?? 'DropMMS',
              poster: '',
              date: 'Latest',
            ));
          }
        }
      }

      return results;
    } catch (e) {
      if (kDebugMode) print("DropMMS fetchCatalog error: $e");
      return [];
    }
  }

  /// Fetch full post topic details: all full-res screenshots, video streaming links, and download mirrors
  static Future<DropmmsTopicDetails?> fetchTopicDetails(String topicUrl) async {
    try {
      final res = await http.get(Uri.parse(topicUrl), headers: _headers).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;

      final html = res.body;

      // 1. Topic Title
      var title = 'DropMMS Video Post';
      final titleMatch = RegExp(r'<h1[^>]*>([\s\S]*?)<\/h1>', caseSensitive: false).firstMatch(html);
      if (titleMatch != null) {
        title = titleMatch.group(1)?.replaceAll(RegExp(r'<[^>]+>'), '').trim() ?? title;
        title = _unescapeHtml(title);
      }

      // 2. Date & Category
      var date = 'Recent';
      final dateMatch = RegExp(r'<time[^>]+datetime="([^"]+)"|<time[^>]*>([^<]+)<\/time>', caseSensitive: false).firstMatch(html);
      if (dateMatch != null) {
        date = (dateMatch.group(2) ?? dateMatch.group(1) ?? 'Recent').trim();
      }

      var categoryName = 'DropMMS';
      final catMatch = RegExp(r'<nav[^>]*>[\s\S]*?<a[^>]+href="[^"]*\/forum\/[^"]+"[^>]*>([^<]+)<\/a>', caseSensitive: false).firstMatch(html);
      if (catMatch != null) {
        categoryName = catMatch.group(1)?.trim() ?? categoryName;
      }

      // 3. Extract Images & Screenshots
      final images = <String>[];
      final seenImg = <String>{};

      // In-post embedded <img> tags
      final imgMatches = RegExp(r'<img[^>]+(?:data-src|src)="([^"]+)"', caseSensitive: false).allMatches(html);
      for (final im in imgMatches) {
        final src = im.group(1)?.trim() ?? '';
        if (src.isNotEmpty &&
            !src.contains('spacer.png') &&
            !src.contains('emoticons') &&
            !src.contains('avatar') &&
            !src.contains('theme') &&
            !src.contains('logo') &&
            !src.contains('reaction') &&
            !seenImg.contains(src)) {
          seenImg.add(src);
          images.add(src);
        }
      }

      // 4. Extract External Links (Images, Videos, Downloads)
      final linkMatches = RegExp(r'<a[^>]+href="([^"]+)"[^>]*>([\s\S]*?)<\/a>', caseSensitive: false).allMatches(html);
      final videoLinks = <DropmmsMediaLink>[];
      final downloadLinks = <DropmmsMediaLink>[];
      final seenLinks = <String>{};

      for (final lm in linkMatches) {
        final href = lm.group(1)?.trim() ?? '';
        var linkText = (lm.group(2) ?? '').replaceAll(RegExp(r'<[^>]+>'), '').trim();
        linkText = _unescapeHtml(linkText);

        if (href.isEmpty ||
            href.contains('dropmms.co') ||
            href.contains('javascript:') ||
            href.startsWith('#') ||
            seenLinks.contains(href)) {
          continue;
        }
        seenLinks.add(href);

        final lower = href.toLowerCase();

        // Check if image host
        if (lower.contains('imagetwist.com') ||
            lower.contains('ibb.co') ||
            lower.contains('postimg.cc') ||
            lower.contains('pixhost.to') ||
            lower.contains('imgbox.com') ||
            lower.contains('imagevenue.com') ||
            lower.contains('fastpic.org') ||
            lower.contains('imagebam.com')) {
          if (!seenImg.contains(href)) {
            seenImg.add(href);
            images.add(href);
          }
          continue;
        }

        // Check if Video Stream Link
        if (lower.contains('streamtape') ||
            lower.contains('tapeadsenjoyer') ||
            lower.contains('tapecontent') ||
            lower.contains('streamta.pe') ||
            lower.contains('strcloud')) {
          videoLinks.add(DropmmsMediaLink(
            name: linkText.isNotEmpty && linkText != href ? linkText : 'Streamtape HD 1080p (Direct CDN)',
            url: href,
            host: 'Streamtape',
            type: 'streamtape',
            isDirectStreamable: true,
          ));
        } else if (lower.contains('vibevdo')) {
          videoLinks.add(DropmmsMediaLink(
            name: linkText.isNotEmpty && linkText != href ? linkText : 'VibeVdo Player',
            url: href,
            host: 'VibeVdo',
            type: 'vibevdo',
            isDirectStreamable: false,
          ));
        } else if (lower.contains('vidsonic')) {
          videoLinks.add(DropmmsMediaLink(
            name: linkText.isNotEmpty && linkText != href ? linkText : 'VidSonic Stream',
            url: href,
            host: 'VidSonic',
            type: 'vidsonic',
            isDirectStreamable: false,
          ));
        } else if (lower.contains('luluvdo') || lower.contains('lulustream') || lower.contains('luluvid')) {
          videoLinks.add(DropmmsMediaLink(
            name: linkText.isNotEmpty && linkText != href ? linkText : 'LuluVdo Stream',
            url: href,
            host: 'LuluVdo',
            type: 'luluvdo',
            isDirectStreamable: false,
          ));
        } else if (lower.contains('playmate.to')) {
          videoLinks.add(DropmmsMediaLink(
            name: linkText.isNotEmpty && linkText != href ? linkText : 'Playmate Stream',
            url: href,
            host: 'Playmate',
            type: 'playmate',
            isDirectStreamable: false,
          ));
        } else if (lower.contains('vidara.to')) {
          videoLinks.add(DropmmsMediaLink(
            name: linkText.isNotEmpty && linkText != href ? linkText : 'Vidara Stream',
            url: href,
            host: 'Vidara',
            type: 'vidara',
            isDirectStreamable: false,
          ));
        } else if (lower.contains('streamwish') || lower.contains('dood') || lower.contains('filelions') || lower.contains('turbovid')) {
          videoLinks.add(DropmmsMediaLink(
            name: linkText.isNotEmpty && linkText != href ? linkText : 'Fast Video Player',
            url: href,
            host: 'Video Stream',
            type: 'other_video',
            isDirectStreamable: false,
          ));
        }
        // Check if Download / File Host Link
        else if (lower.contains('torupload') ||
            lower.contains('upfiles') ||
            lower.contains('frdl.io') ||
            lower.contains('cloudfam.io') ||
            lower.contains('flash-files') ||
            lower.contains('hexload') ||
            lower.contains('fastshare') ||
            lower.contains('gofile') ||
            lower.contains('mega.nz') ||
            lower.contains('terabox')) {
          var hostName = 'Download Mirror';
          if (lower.contains('torupload')) hostName = 'TorUpload';
          if (lower.contains('upfiles')) hostName = 'UpFiles';
          if (lower.contains('frdl.io')) hostName = 'FRDL';
          if (lower.contains('cloudfam')) hostName = 'CloudFam';
          if (lower.contains('flash-files')) hostName = 'FlashFiles';
          if (lower.contains('gofile')) hostName = 'GoFile';
          if (lower.contains('mega.nz')) hostName = 'Mega';
          if (lower.contains('terabox')) hostName = 'TeraBox';

          downloadLinks.add(DropmmsMediaLink(
            name: linkText.isNotEmpty && linkText != href ? linkText : '$hostName Direct File',
            url: href,
            host: hostName,
            type: 'download',
            isDirectStreamable: false,
          ));
        }
      }

      return DropmmsTopicDetails(
        title: title,
        topicUrl: topicUrl,
        categoryName: categoryName,
        date: date,
        images: images,
        videoLinks: videoLinks,
        downloadLinks: downloadLinks,
      );
    } catch (e) {
      if (kDebugMode) print("DropMMS fetchTopicDetails error: $e");
      return null;
    }
  }

  /// In-App Chunked File Downloader with Progress Notification
  static Future<void> downloadInApp({
    required BuildContext context,
    required String rawUrl,
    required String defaultFileName,
    String? mediaType,
  }) async {
    // 1. Resolve URL if it is Streamtape
    String downloadUrl = rawUrl;
    if (rawUrl.contains('streamtape') ||
        rawUrl.contains('tapeadsenjoyer') ||
        rawUrl.contains('tapecontent') ||
        rawUrl.contains('streamta.pe') ||
        rawUrl.contains('strcloud')) {
      final resolved = await StreamtapeService.getDirectStreamUrl(rawUrl);
      if (resolved != null && resolved.isNotEmpty) {
        downloadUrl = resolved;
      }
    }

    // 2. Request Storage Permissions on Android if needed
    if (Platform.isAndroid) {
      await Permission.storage.request();
    }

    // 3. Determine save directory
    Directory? saveDir;
    try {
      if (Platform.isAndroid) {
        saveDir = Directory('/storage/emulated/0/Download');
        if (!await saveDir.exists()) {
          saveDir = await getExternalStorageDirectory();
        }
      } else {
        saveDir = await getApplicationDocumentsDirectory();
      }
    } catch (_) {
      saveDir = await getApplicationDocumentsDirectory();
    }

    if (saveDir == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Cannot access storage directory for download."), backgroundColor: Colors.red),
        );
      }
      return;
    }

    // Clean file name
    String safeName = defaultFileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    if (!safeName.contains('.')) {
      safeName += '.mp4';
    }

    final savePath = '${saveDir.path}/$safeName';
    final targetFile = File(savePath);

    // Progress State Notifiers
    final progressNotifier = ValueNotifier<double>(0.0);
    final statusNotifier = ValueNotifier<String>("Starting download...");
    bool isCancelled = false;

    // Show persistent progress dialog
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: const Color(0xFF161B26),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Colors.cyanAccent, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_download_rounded, color: Colors.cyanAccent, size: 40),
                  const SizedBox(height: 12),
                  const Text(
                    "Downloading Content",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    safeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(height: 18),
                  ValueListenableBuilder<double>(
                    valueListenable: progressNotifier,
                    builder: (_, progress, __) {
                      return Column(
                        children: [
                          LinearProgressIndicator(
                            value: progress > 0 ? progress : null,
                            backgroundColor: Colors.white10,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              ValueListenableBuilder<String>(
                                valueListenable: statusNotifier,
                                builder: (_, status, __) => Text(
                                  status,
                                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                                ),
                              ),
                              Text(
                                "${(progress * 100).toStringAsFixed(1)}%",
                                style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton(
                    onPressed: () {
                      isCancelled = true;
                      Navigator.pop(dialogCtx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white12,
                      foregroundColor: Colors.white70,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text("Cancel Download"),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(downloadUrl));
      request.headers.addAll({
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'Referer': 'https://dropmms.co/',
      });

      final response = await client.send(request);
      final totalBytes = response.contentLength ?? 0;
      int receivedBytes = 0;

      final sink = targetFile.openWrite();

      await for (final chunk in response.stream) {
        if (isCancelled) {
          await sink.close();
          if (await targetFile.exists()) await targetFile.delete();
          client.close();
          return;
        }

        sink.add(chunk);
        receivedBytes += chunk.length;

        if (totalBytes > 0) {
          final progress = receivedBytes / totalBytes;
          progressNotifier.value = progress;
          final currentMb = (receivedBytes / (1024 * 1024)).toStringAsFixed(1);
          final totalMb = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
          statusNotifier.value = "$currentMb MB / $totalMb MB";
        } else {
          final currentMb = (receivedBytes / (1024 * 1024)).toStringAsFixed(1);
          statusNotifier.value = "$currentMb MB downloaded";
        }
      }

      await sink.flush();
      await sink.close();
      client.close();

      if (context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context); // Close progress dialog
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text("Downloaded to $safeName", overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF161B26),
            action: SnackBarAction(
              label: "OPEN",
              textColor: Colors.cyanAccent,
              onPressed: () {
                OpenFilex.open(savePath);
              },
            ),
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } catch (e) {
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Download error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  static String _unescapeHtml(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
