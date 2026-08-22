import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import 'streamtape_service.dart';
import 'luluvdo_resolver.dart';

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
        fetchUrl = page > 1
            ? '$baseUrl/discover-dropmms/?page=$page'
            : '$baseUrl/discover-dropmms/';
      } else {
        final catSlug = category.endsWith('/') ? category : '$category/';
        fetchUrl = page > 1
            ? '$baseUrl/forum/${catSlug}page/$page/'
            : '$baseUrl/forum/$catSlug';
      }

      final html = await _fetchHtml(fetchUrl, headers: _headers);
      if (html.isEmpty) return [];
      final results = <DropmmsItem>[];
      final seenUrls = <String>{};

      // 1. Search Results & Activity Stream Parser
      final streamItems = RegExp(
        r'''<li[^>]+class=['"][^'"]*ipsStreamItem[^'"]*['"][^>]*>([\s\S]*?)<\/li>|<div[^>]+class=['"][^'"]*ipsStreamItem[^'"]*['"][^>]*>([\s\S]*?)<\/div>''',
        caseSensitive: false,
      ).allMatches(html);

      if (streamItems.isNotEmpty) {
        for (final sm in streamItems) {
          final sHtml = sm.group(1) ?? sm.group(2) ?? '';
          final linkMatch = RegExp(
            r'''<a[^>]+href=['"]([^'"]*\/topic\/[0-9]+-[^'"]+)['"][^>]*data-searchable[^>]*>([\s\S]*?)<\/a>|<span[^>]*class=['"][^'"]*ipsType_break[^'"]*['"][^>]*>[^<]*<a[^>]+href=['"]([^'"]*\/topic\/[0-9]+-[^'"]+)['"][^>]*>([\s\S]*?)<\/a>|<a[^>]+href=['"]([^'"]*\/topic\/[0-9]+-[^'"]+)['"][^>]*>([\s\S]*?)<\/a>''',
            caseSensitive: false,
          ).firstMatch(sHtml);

          if (linkMatch == null) continue;
          final rawUrl = (linkMatch.group(1) ?? linkMatch.group(3) ?? linkMatch.group(5) ?? '').trim();
          if (rawUrl.isEmpty) continue;
          final cleanUrl = rawUrl.split('?')[0].split('#')[0];
          if (seenUrls.contains(cleanUrl)) continue;

          final rawTitle = (linkMatch.group(2) ?? linkMatch.group(4) ?? linkMatch.group(6) ?? '').replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
          if (rawTitle.length < 3 || rawTitle.toLowerCase() == 'reply') continue;

          String poster = '';
          final imgM = RegExp(r'''(?:data-background-src|data-src|src)=['"]([^'"]+(?:\.jpg|\.png|\.webp|\.jpeg)[^'"]*)['"]''', caseSensitive: false).firstMatch(sHtml);
          if (imgM != null) {
            final src = imgM.group(1) ?? '';
            if (!src.contains('avatar') && !src.contains('spacer') && !src.contains('theme')) {
              poster = src;
            }
          }

          String date = 'Recent';
          final timeM = RegExp(r'''<time[^>]*>([^<]+)<\/time>''', caseSensitive: false).firstMatch(sHtml);
          if (timeM != null) {
            date = timeM.group(1)?.trim() ?? 'Recent';
          }

          seenUrls.add(cleanUrl);
          results.add(DropmmsItem(
            title: _unescapeHtml(rawTitle),
            topicUrl: cleanUrl,
            categoryName: categories[category] ?? 'DropMMS',
            poster: poster,
            date: date,
          ));
        }
      }

      // 2. Forum Category Grid Items (tthumb_grid_item on Category pages)
      if (results.isEmpty) {
        final gridItems = RegExp(
          r'''<div[^>]+class=['"][^'"]*tthumb_grid_item[^'"]*['"][^>]*>([\s\S]*?)<\/div>\s*<\/div>\s*<\/div>|<div[^>]+class=['"][^'"]*tthumb_grid_item[^'"]*['"][^>]*>([\s\S]*?)<\/div>\s*<\/div>''',
          caseSensitive: false,
        ).allMatches(html);

        for (final gm in gridItems) {
          final gHtml = gm.group(1) ?? gm.group(2) ?? '';
          final linkM = RegExp(
            r'''<a[^>]+href=['"]([^'"]*\/topic\/[0-9]+-[^'"]+)['"][^>]*>([\s\S]*?)<\/a>''',
            caseSensitive: false,
          ).firstMatch(gHtml);

          if (linkM == null) continue;
          final rawUrl = linkM.group(1)?.trim() ?? '';
          if (rawUrl.isEmpty) continue;
          final cleanUrl = rawUrl.split('?')[0].split('#')[0];
          if (seenUrls.contains(cleanUrl)) continue;

          String title = '';
          final titleM = RegExp(
            r'''<div[^>]+class=['"][^'"]*tthumb_gal_title[^'"]*['"][^>]*>[\s\S]*?<a[^>]+href=['"][^'"]*\/topic\/[^'"]+['"][^>]*>([\s\S]*?)<\/a>''',
            caseSensitive: false,
          ).firstMatch(gHtml);

          if (titleM != null) {
            title = titleM.group(1)?.replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
          }
          if (title.isEmpty) {
            final rawTitle = linkM.group(2) ?? '';
            title = rawTitle.replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
          }
          if (title.length < 3 || title.toLowerCase() == 'reply') continue;

          String poster = '';
          final bgM = RegExp(r'''data-background-src=['"]([^'"]+)['"]''', caseSensitive: false).firstMatch(gHtml);
          if (bgM != null) {
            poster = bgM.group(1)?.trim() ?? '';
          }
          if (poster.isEmpty) {
            final imgM = RegExp(r'''<img[^>]+(?:src|data-src)=['"]([^'"]+(?:\.jpg|\.png|\.webp|\.jpeg)[^'"]*)['"]''', caseSensitive: false).firstMatch(gHtml);
            if (imgM != null) {
              final src = imgM.group(1) ?? '';
              if (!src.contains('avatar') && !src.contains('spacer') && !src.contains('theme')) {
                poster = src;
              }
            }
          }

          seenUrls.add(cleanUrl);
          results.add(DropmmsItem(
            title: _unescapeHtml(title),
            topicUrl: cleanUrl,
            categoryName: categories[category] ?? 'DropMMS',
            poster: poster,
            date: 'Recent',
          ));
        }
      }

      // 3. IPS Data Items (Home Page & Category Rows)
      if (results.isEmpty) {
        final rowMatches = RegExp(
          r'''<li[^>]+class=['"][^'"]*ipsDataItem[^'"]*['"][^>]*>([\s\S]*?)<\/li>''',
          caseSensitive: false,
        ).allMatches(html);

        for (final r in rowMatches) {
          final rHtml = r.group(1) ?? '';
          final linkM = RegExp(
            r'''<a[^>]+href=['"]([^'"]*\/topic\/[0-9]+-[^'"]+)['"][^>]*title=['"]([^'"]*)['"][^>]*>([\s\S]*?)<\/a>|<a[^>]+href=['"]([^'"]*\/topic\/[0-9]+-[^'"]+)['"][^>]*alt=['"]([^'"]*)['"][^>]*>([\s\S]*?)<\/a>|<a[^>]+href=['"]([^'"]*\/topic\/[0-9]+-[^'"]+)['"][^>]*>([\s\S]*?)<\/a>''',
            caseSensitive: false,
          ).firstMatch(rHtml);

          if (linkM == null) continue;
          final rawUrl = (linkM.group(1) ?? linkM.group(4) ?? linkM.group(7) ?? '').trim();
          if (rawUrl.isEmpty) continue;
          final cleanUrl = rawUrl.split('?')[0].split('#')[0];
          if (seenUrls.contains(cleanUrl)) continue;

          String title = (linkM.group(2)?.isNotEmpty == true
              ? linkM.group(2)
              : (linkM.group(5)?.isNotEmpty == true
                  ? linkM.group(5)
                  : (linkM.group(3) ?? linkM.group(6) ?? linkM.group(8)))) ?? '';
          title = title.replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
          if (title.length < 3 || title.toLowerCase() == 'reply' || title.toLowerCase().startsWith('page')) continue;

          String poster = '';
          final bgM = RegExp(r'''data-background-src=['"]([^'"]+)['"]''', caseSensitive: false).firstMatch(rHtml);
          if (bgM != null) {
            poster = bgM.group(1)?.trim() ?? '';
          }
          if (poster.isEmpty) {
            final imgM = RegExp(r'''(?:data-src|src|data-lazyload)=['"]([^'"]+(?:\.jpg|\.png|\.webp|\.jpeg)[^'"]*)['"]''', caseSensitive: false).firstMatch(rHtml);
            if (imgM != null) {
              final src = imgM.group(1) ?? '';
              if (!src.contains('avatar') && !src.contains('spacer') && !src.contains('theme') && !src.contains('logo')) {
                poster = src;
              }
            }
          }

          String date = 'Recent';
          final timeM = RegExp(r'''<time[^>]*>([^<]+)<\/time>''', caseSensitive: false).firstMatch(rHtml);
          if (timeM != null) {
            date = timeM.group(1)?.trim() ?? 'Recent';
          }

          seenUrls.add(cleanUrl);
          results.add(DropmmsItem(
            title: _unescapeHtml(title),
            topicUrl: cleanUrl,
            categoryName: categories[category] ?? 'DropMMS',
            poster: poster,
            date: date,
          ));
        }
      }

      // 4. Fallback Direct Link Matcher
      if (results.length < 5) {
        final directLinks = RegExp(
          r'''<a[^>]+href=['"]([^'"]*\/topic\/[0-9]+-[^'"]+)['"][^>]*>([\s\S]*?)<\/a>''',
          caseSensitive: false,
        ).allMatches(html);

        for (final tm in directLinks) {
          final tUrl = (tm.group(1) ?? '').trim();
          final cleanUrl = tUrl.split('?')[0].split('#')[0];
          if (cleanUrl.isEmpty || cleanUrl.contains('#') || seenUrls.contains(cleanUrl)) continue;

          var tTitle = (tm.group(2) ?? '').replaceAll(RegExp(r'<[^>]+>'), ' ').trim();
          tTitle = _unescapeHtml(tTitle);

          if (tTitle.length > 5 &&
              !tTitle.toLowerCase().startsWith('page') &&
              tTitle.toLowerCase() != 'reply') {
            seenUrls.add(cleanUrl);
            results.add(DropmmsItem(
              title: tTitle,
              topicUrl: cleanUrl,
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

  /// Public DoH HTML fetcher
  static Future<String> fetchHtmlDirect(String url, {Map<String, String>? headers, String method = 'GET', dynamic body}) =>
      _fetchHtml(url, headers: headers, method: method, body: body);

  /// Fetch full details of a topic
  static Future<DropmmsTopicDetails?> fetchTopicDetails(String topicUrl) async {
    try {
      final html = await _fetchHtml(topicUrl, headers: _headers);
      if (html.isEmpty) return null;
      return parseTopicHtml(html, topicUrl);
    } catch (e) {
      debugPrint('DropmmsService.fetchTopicDetails error: $e');
      return null;
    }
  }

  /// Parse Topic Details directly from HTML string
  static DropmmsTopicDetails? parseTopicHtml(String html, String topicUrl) {
    try {
      // 1. Topic Title
      var title = 'DropMMS Video Post';
      final titleMatch = RegExp(r'''<h1[^>]*>([\s\S]*?)<\/h1>''', caseSensitive: false).firstMatch(html);
      if (titleMatch != null) {
        title = titleMatch.group(1)?.replaceAll(RegExp(r'<[^>]+>'), '').trim() ?? title;
        title = _unescapeHtml(title);
      }

      // 2. Date & Category
      var date = 'Recent';
      final dateMatch = RegExp(r'''<time[^>]+datetime=['"]([^'"]+)['"]|<time[^>]*>([^<]+)<\/time>''', caseSensitive: false).firstMatch(html);
      if (dateMatch != null) {
        date = (dateMatch.group(2) ?? dateMatch.group(1) ?? 'Recent').trim();
      }

      var categoryName = 'DropMMS';
      final catMatch = RegExp(r'''<nav[^>]*>[\s\S]*?<a[^>]+href=['"][^'"]*\/forum\/[^'"]+['"][^>]*>([^<]+)<\/a>''', caseSensitive: false).firstMatch(html);
      if (catMatch != null) {
        categoryName = catMatch.group(1)?.trim() ?? categoryName;
      }

      // 3. Isolate First Post Comment Content
      final postMatch = RegExp(r'''<div[^>]+data-role=['"]commentContent['"][^>]*>([\s\S]*?)<\/div>\s*<\/div>''', caseSensitive: false).firstMatch(html);
      final postHtml = postMatch?.group(1) ?? html;

      // 4. Extract Images & Screenshots
      final images = <String>[];
      final seenImg = <String>{};

      final imgMatches = RegExp(r'''(?:data-src|src|data-background-src)=['"]([^'"]+(?:\.jpg|\.jpeg|\.png|\.webp|\.gif)[^'"]*)['"]''', caseSensitive: false).allMatches(postHtml);
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

      // 5. Extract External Links (Images, Videos, Downloads)
      final linkMatches = RegExp(r'''<a[^>]+href=['"]([^'"]+)['"][^>]*>([\s\S]*?)<\/a>''', caseSensitive: false).allMatches(postHtml);
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
        } else if (lower.contains('torupload') ||
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

  static final List<String> _dropmmsIpPool = [
    '172.67.218.172',
    '104.26.1.182',
    '104.26.2.182',
    '104.21.5.196',
    '104.18.20.12',
    '104.18.21.12',
    '104.21.95.155',
  ];

  static final Map<String, String> _dohCache = {
    'dropmms.co': '172.67.218.172',
    'imagetwist.com': '104.21.68.217',
    'streamtape.com': '104.26.1.182',
    'tapecontent.net': '104.26.1.182',
    'luluvdo.com': '104.21.5.196',
    'lulustream.com': '104.21.5.196',
    'lulucdn.com': '104.21.5.196',
    'playmate.to': '104.21.78.212',
    'merivo.fit': '104.21.49.200',
    'vibevdo.xyz': '104.21.25.105',
    'vidsonic.net': '104.21.36.190',
  };

  /// DoH-powered HTTP fetcher to bypass all ISP DNS blocks
  static Future<String> _fetchHtml(String url, {Map<String, String>? headers, String method = 'GET', dynamic body}) async {
    final client = HttpClient()..badCertificateCallback = (c, h, p) => true;
    client.findProxy = (uri) => 'DIRECT'; // Bypass local proxy tunnel, use direct socket factory!
    client.connectionTimeout = const Duration(seconds: 8);
    final uri = Uri.parse(url);

    client.connectionFactory = (targetUri, proxyHost, proxyPort) async {
      String host = targetUri.host;

      // For dropmms.co, cycle through resilient Cloudflare Anycast IPs with auto-retry
      if (host.contains('dropmms.co')) {
        for (final ip in _dropmmsIpPool) {
          try {
            final s = await Socket.connect(ip, targetUri.port, timeout: const Duration(seconds: 3));
            if (targetUri.scheme == 'https') {
              final sec = await SecureSocket.secure(s, host: host, onBadCertificate: (c) => true);
              return ConnectionTask.fromSocket(Future.value(sec), () {});
            }
            return ConnectionTask.fromSocket(Future.value(s), () {});
          } catch (_) {
            continue;
          }
        }
      }

      String targetIp = _dohCache[host] ?? '';
      if (targetIp.isEmpty) {
        try {
          final dohClient = HttpClient()..badCertificateCallback = (c, h, p) => true;
          final dohReq = await dohClient.getUrl(Uri.parse('https://dns.google/resolve?name=$host&type=A')).timeout(const Duration(seconds: 3));
          final dohResp = await dohReq.close();
          final dohBody = await utf8.decodeStream(dohResp);
          final json = jsonDecode(dohBody);
          final answers = json['Answer'] as List?;
          if (answers != null && answers.isNotEmpty) {
            for (final a in answers) {
              if (a['type'] == 1) {
                targetIp = a['data'] as String;
                _dohCache[host] = targetIp;
                break;
              }
            }
          }
        } catch (_) {}
      }
      if (targetIp.isEmpty) targetIp = host;
      final s = await Socket.connect(targetIp, targetUri.port, timeout: const Duration(seconds: 5));
      if (targetUri.scheme == 'https') {
        final sec = await SecureSocket.secure(s, host: host, onBadCertificate: (c) => true);
        return ConnectionTask.fromSocket(Future.value(sec), () {});
      }
      return ConnectionTask.fromSocket(Future.value(s), () {});
    };

    final req = method == 'POST' ? await client.postUrl(uri) : await client.getUrl(uri);
    headers?.forEach((k, v) => req.headers.set(k, v));
    if (body != null) {
      if (body is String) {
        req.write(body);
      } else if (body is Map) {
        req.headers.set('Content-Type', 'application/json');
        req.write(jsonEncode(body));
      }
    }
    final resp = await req.close().timeout(const Duration(seconds: 10));
    final html = await utf8.decodeStream(resp);
    client.close();
    return html;
  }

  /// Direct Stream Resolver for multiple third-party video hosts
  static Future<String?> resolveDirectStream(String url) async {
    try {
      final lower = url.toLowerCase();

      // 1. Streamtape
      if (lower.contains('streamtape') ||
          lower.contains('tapeadsenjoyer') ||
          lower.contains('tapecontent') ||
          lower.contains('streamta.pe') ||
          lower.contains('strcloud')) {
        final st = await StreamtapeService.getDirectStreamUrl(url);
        if (st != null && st.isNotEmpty) return st;
      }

      // 2. Vidara / Merivo
      if (lower.contains('vidara') || lower.contains('merivo')) {
        final uri = Uri.parse(url);
        final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
        if (segs.isNotEmpty) {
          final filecode = segs.last;
          final resp = await _fetchHtml(
            'https://merivo.fit/api/stream',
            method: 'POST',
            headers: {
              'User-Agent': 'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
              'Referer': 'https://merivo.fit/e/$filecode',
              'Origin': 'https://merivo.fit',
            },
            body: {'filecode': filecode, 'device': 'android'},
          );

          final json = jsonDecode(resp);
          final streamUrl = json['streaming_url'] as String?;
          if (streamUrl != null && streamUrl.isNotEmpty) {
            return streamUrl;
          }
        }
      }

      // 3. LuluStream / LuluVdo
      if (lower.contains('luluvdo') || lower.contains('lulustream') || lower.contains('luluvid') || lower.contains('lulucdn')) {
        final luluRes = await LuluvdoResolver.resolveOnDevice(url, forceRefresh: true);
        if (luluRes != null && luluRes.isNotEmpty) return luluRes;
      }

      // 4. Playmate
      if (lower.contains('playmate')) {
        try {
          final uri = Uri.parse(url);
          final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
          if (segs.isNotEmpty) {
            final filecode = segs.last;
            // Try embed URL first
            for (final embedUrl in [
              'https://playmate.to/embed/$filecode',
              'https://playmate.to/v/$filecode',
              'https://playmate.tv/embed/$filecode',
              'https://playmate.tv/v/$filecode',
            ]) {
              try {
                final htmlBody = await _fetchHtml(embedUrl, headers: {
                  ..._headers,
                  'Referer': 'https://dropmms.co/',
                });
                // Look for m3u8 or mp4 directly
                final streamMatch = RegExp(
                  r'''(?:file|src|source)\s*[=:]\s*['"](https?://[^'"]+\.(?:m3u8|mp4)[^'"]*)['"']''',
                  caseSensitive: false,
                ).firstMatch(htmlBody);
                if (streamMatch != null) return streamMatch.group(1);
                // Try eval unpack
                final evalMatch = RegExp(
                  r'''eval\s*\(\s*(function\(p,a,c,k,e,d\)[\s\S]*?\.split\('\|'\)\s*\))\s*\)''',
                ).firstMatch(htmlBody);
                if (evalMatch != null) {
                  final unpacked = _unpackJs(evalMatch.group(1)!);
                  final m = RegExp(
                    r'''(?:file|src)\s*:\s*['"](https?://[^'"]+\.(?:m3u8|mp4)[^'"]*)['"']''',
                    caseSensitive: false,
                  ).firstMatch(unpacked);
                  if (m != null) return m.group(1);
                }
                // Look for jwplayer sources
                final jwMatch = RegExp(r'file\s*:\s*"(https?://[^"]+)"').firstMatch(htmlBody)
                    ?? RegExp(r"file\s*:\s*'(https?://[^']+)'").firstMatch(htmlBody);
                if (jwMatch != null) return jwMatch.group(1);
              } catch (_) {}
            }
          }
        } catch (_) {}
      }

      // 5. VidSonic
      if (lower.contains('vidsonic')) {
        final body = await _fetchHtml(url, headers: _headers);
        final m3u8Match = RegExp(r'''(?:file|src)\s*:\s*['"]([^'"]+\.(?:m3u8|mp4)[^'"]*)['"]''').firstMatch(body);
        if (m3u8Match != null) {
          return m3u8Match.group(1);
        }
        final evalMatch = RegExp(r'''eval\s*\(\s*(function\(p,a,c,k,e,d\)[\s\S]*?\.split\('\|'\)\s*\))\s*\)''').firstMatch(body);
        if (evalMatch != null) {
          final unpacked = _unpackJs(evalMatch.group(1)!);
          final m = RegExp(r'''(?:file|src)\s*:\s*['"]([^'"]+\.(?:m3u8|mp4)[^'"]*)['"]''').firstMatch(unpacked);
          if (m != null) return m.group(1);
        }
      }

      // 6. VibeVdo
      if (lower.contains('vibevdo')) {
        final body = await _fetchHtml(url, headers: _headers);
        final m = RegExp(r'''(?:file|src)\s*:\s*['"]([^'"]+\.(?:m3u8|mp4)[^'"]*)['"]''').firstMatch(body);
        if (m != null) return m.group(1);
      }

      return null;
    } catch (e) {
      if (kDebugMode) print("resolveDirectStream error: $e");
      return null;
    }
  }

  /// P.A.C.K.E.R. JavaScript Unpacker
  static String _unpackJs(String packed) {
    try {
      final reg = RegExp(r'''\}\s*\(\s*['"]([\s\S]*?)['"]\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*['"]([\s\S]*?)['"]\.split\(['"]\|['"]\)''');
      final match = reg.firstMatch(packed);
      if (match == null) return packed;

      String payload = match.group(1) ?? '';
      int radix = int.parse(match.group(2) ?? '10');
      int count = int.parse(match.group(3) ?? '0');
      List<String> dict = (match.group(4) ?? '').split('|');

      String unbase(int c) {
        if (c < radix) return c.toRadixString(radix);
        return unbase(c ~/ radix) + (c % radix).toRadixString(radix);
      }

      while (count > 0) {
        count--;
        final key = unbase(count);
        final val = count < dict.length && dict[count].isNotEmpty ? dict[count] : key;
        payload = payload.replaceAll(RegExp('\\b$key\\b'), val);
      }

      return payload;
    } catch (_) {
      return packed;
    }
  }

  /// In-App Chunked File Downloader with Progress Notification & Media Scanner
  static Future<void> downloadInApp({
    required BuildContext context,
    required String rawUrl,
    required String defaultFileName,
    String? mediaType,
  }) async {
    // 1. Resolve direct stream URL if possible
    String downloadUrl = rawUrl;
    final resolved = await resolveDirectStream(rawUrl);
    if (resolved != null && resolved.isNotEmpty) {
      downloadUrl = resolved;
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
      safeName += (mediaType == 'image' ? '.jpg' : '.mp4');
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
      final isHls = downloadUrl.contains('.m3u8');
      final lowerDl = downloadUrl.toLowerCase();
      String referer = 'https://dropmms.co/';
      if (lowerDl.contains('luluvdo') || lowerDl.contains('lulustream') || lowerDl.contains('tnmr.org') || lowerDl.contains('lulucdn')) {
        referer = 'https://luluvdo.com/';
      } else if (lowerDl.contains('merivo') || lowerDl.contains('vidara')) {
        referer = 'https://merivo.fit/';
      } else if (lowerDl.contains('vibevdo')) {
        referer = 'https://vibevdo.xyz/';
      } else if (lowerDl.contains('vidsonic')) {
        referer = 'https://vidsonic.net/';
      }

      if (isHls) {
        // Full HLS Video Stream Downloader (downloads & stitches TS video chunks into complete .mp4)
        final client = HttpClient()..badCertificateCallback = (c, h, p) => true;
        final req = await client.getUrl(Uri.parse(downloadUrl));
        req.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
        req.headers.set('Referer', referer);
        final resp = await req.close();
        final m3u8Content = await utf8.decodeStream(resp);

        var targetPlaylistUrl = downloadUrl;
        var subM3u8Content = m3u8Content;

        if (m3u8Content.contains('#EXT-X-STREAM-INF')) {
          final lines = m3u8Content.split('\n');
          String? subVariant;
          for (int i = 0; i < lines.length; i++) {
            if (lines[i].contains('#EXT-X-STREAM-INF') && i + 1 < lines.length) {
              final nextLine = lines[i + 1].trim();
              if (nextLine.isNotEmpty && !nextLine.startsWith('#')) {
                subVariant = nextLine;
              }
            }
          }
          if (subVariant != null) {
            if (subVariant.startsWith('http')) {
              targetPlaylistUrl = subVariant;
            } else {
              final base = downloadUrl.substring(0, downloadUrl.lastIndexOf('/') + 1);
              targetPlaylistUrl = base + subVariant;
            }
            final sReq = await client.getUrl(Uri.parse(targetPlaylistUrl));
            sReq.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
            sReq.headers.set('Referer', referer);
            final sResp = await sReq.close();
            subM3u8Content = await utf8.decodeStream(sResp);
          }
        }

        final lines = subM3u8Content.split('\n');
        final chunkUrls = <String>[];
        final playlistBase = targetPlaylistUrl.substring(0, targetPlaylistUrl.lastIndexOf('/') + 1);

        for (final l in lines) {
          final line = l.trim();
          if (line.isNotEmpty && !line.startsWith('#')) {
            if (line.startsWith('http')) {
              chunkUrls.add(line);
            } else {
              chunkUrls.add(playlistBase + line);
            }
          }
        }

        if (chunkUrls.isEmpty) throw Exception("Failed to extract HLS video segments.");

        if (await targetFile.exists()) await targetFile.delete();
        final sink = targetFile.openWrite(mode: FileMode.writeOnlyAppend);
        int totalChunks = chunkUrls.length;

        for (int i = 0; i < totalChunks; i++) {
          if (isCancelled) {
            await sink.close();
            if (await targetFile.exists()) await targetFile.delete();
            client.close();
            return;
          }

          final chunkUrl = chunkUrls[i];
          final cReq = await client.getUrl(Uri.parse(chunkUrl));
          cReq.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
          cReq.headers.set('Referer', referer);
          final cResp = await cReq.close();
          await sink.addStream(cResp);

          final progress = (i + 1) / totalChunks;
          progressNotifier.value = progress;
          statusNotifier.value = "Segment ${i + 1} / $totalChunks";
        }

        await sink.flush();
        await sink.close();
        client.close();
      } else {
        // Direct MP4 / Binary Downloader
        final client = http.Client();
        final request = http.Request('GET', Uri.parse(downloadUrl));
        request.headers.addAll({
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          'Referer': referer,
        });

        final response = await client.send(request);

        // If returned content is an HTML webpage rather than a media file, redirect to browser
        if (response.headers['content-type']?.contains('text/html') == true) {
          client.close();
          if (context.mounted && Navigator.canPop(context)) {
            Navigator.pop(context);
          }
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("File locker mirror requires verification. Opening in browser..."),
                backgroundColor: Colors.amber,
              ),
            );
          }
          await launchUrl(Uri.parse(rawUrl), mode: LaunchMode.externalApplication);
          return;
        }

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
      }

      // Trigger MediaScanner on Android so file shows up in Downloads/Gallery immediately
      if (Platform.isAndroid) {
        try {
          await Process.run('am', [
            'broadcast',
            '-a',
            'android.intent.action.MEDIA_SCANNER_SCAN_FILE',
            '-d',
            'file://$savePath'
          ]);
        } catch (_) {}
      }

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
                  child: Text("Downloaded to Downloads/$safeName", overflow: TextOverflow.ellipsis),
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

  /// Download multiple images directly to Gallery (Pictures/DropMMS) with MediaScanner
  static Future<void> downloadMultipleImages({
    required BuildContext context,
    required List<String> imageUrls,
    required String postTitle,
  }) async {
    if (imageUrls.isEmpty) return;

    if (Platform.isAndroid) {
      await Permission.storage.request();
    }

    Directory galleryDir;
    try {
      if (Platform.isAndroid) {
        galleryDir = Directory('/storage/emulated/0/Pictures/DropMMS');
        if (!await galleryDir.exists()) {
          await galleryDir.create(recursive: true);
        }
      } else {
        galleryDir = await getApplicationDocumentsDirectory();
      }
    } catch (_) {
      galleryDir = await getApplicationDocumentsDirectory();
    }

    final safeFolder = postTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    final progressNotifier = ValueNotifier<int>(0);
    final total = imageUrls.length;
    bool isCancelled = false;

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
              side: const BorderSide(color: Colors.pinkAccent, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.photo_library_rounded, color: Colors.pinkAccent, size: 40),
                  const SizedBox(height: 12),
                  const Text(
                    "Saving to Gallery",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Pictures/DropMMS",
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(height: 18),
                  ValueListenableBuilder<int>(
                    valueListenable: progressNotifier,
                    builder: (_, done, __) {
                      final p = total > 0 ? (done / total) : 0.0;
                      return Column(
                        children: [
                          LinearProgressIndicator(
                            value: p > 0 ? p : null,
                            backgroundColor: Colors.white10,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.pinkAccent),
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Saved $done of $total images",
                                style: const TextStyle(color: Colors.white54, fontSize: 11),
                              ),
                              Text(
                                "${(p * 100).toStringAsFixed(0)}%",
                                style: const TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold, fontSize: 12),
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
                    child: const Text("Cancel"),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    int savedCount = 0;
    try {
      final client = http.Client();
      for (int i = 0; i < imageUrls.length; i++) {
        if (isCancelled) break;
        final url = imageUrls[i];
        try {
          final res = await client.get(Uri.parse(url), headers: _headers).timeout(const Duration(seconds: 10));
          if (res.statusCode == 200) {
            String ext = '.jpg';
            if (url.toLowerCase().endsWith('.png')) ext = '.png';
            if (url.toLowerCase().endsWith('.webp')) ext = '.webp';
            if (url.toLowerCase().endsWith('.gif')) ext = '.gif';

            final fileName = "${safeFolder}_img_${i + 1}$ext";
            final filePath = "${galleryDir.path}/$fileName";
            final file = File(filePath);
            await file.writeAsBytes(res.bodyBytes);

            // Notify Android Media Scanner
            if (Platform.isAndroid) {
              try {
                await Process.run('am', [
                  'broadcast',
                  '-a',
                  'android.intent.action.MEDIA_SCANNER_SCAN_FILE',
                  '-d',
                  'file://$filePath'
                ]);
              } catch (_) {}
            }
            savedCount++;
            progressNotifier.value = savedCount;
          }
        } catch (_) {}
      }
      client.close();

      if (context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.photo_library_rounded, color: Colors.greenAccent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text("Saved $savedCount images to Gallery (Pictures/DropMMS)"),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF161B26),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } catch (e) {
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving images: $e"), backgroundColor: Colors.red),
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
