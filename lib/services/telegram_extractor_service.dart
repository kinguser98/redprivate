import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import 'dropmms_service.dart';
import 'streamtape_service.dart';
import 'telegram_collage_helper.dart';

class TelegramExtractorService {
  static const String _keyBotToken = 'extractor_tg_bot_token';
  static const String _keyChannelId = 'extractor_tg_channel_id';
  static const String _keyUseServer = 'extractor_tg_use_server_engine';

  /// Load stored Extractor Telegram Settings
  static Future<Map<String, dynamic>> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    String botToken = prefs.getString(_keyBotToken) ?? '';
    String channelId = prefs.getString(_keyChannelId) ?? '';
    bool useServer = prefs.getBool(_keyUseServer) ?? true; // Default: server-side (0 MB mobile data)

    if (botToken.isEmpty) {
      botToken = prefs.getString('telegram_bot_token') ?? '';
    }
    if (channelId.isEmpty) {
      channelId = prefs.getString('telegram_channel_id') ?? '';
    }

    return {
      'botToken': botToken,
      'channelId': channelId,
      'useServer': useServer,
    };
  }

  /// Save Extractor Telegram Settings
  static Future<void> saveSettings({
    required String botToken,
    required String channelId,
    bool useServer = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBotToken, botToken.trim());
    await prefs.setString(_keyChannelId, channelId.trim());
    await prefs.setBool(_keyUseServer, useServer);
  }

  /// High-Speed 10Gbps Server-Side Upload (0 MB Mobile Data Usage)
  static Future<Map<String, dynamic>> uploadViaServer({
    required String botToken,
    required String channelId,
    required String title,
    String? caption,
    List<String>? imageUrls,
    String? videoUrl,
    bool uploadPhotos = true,
    bool uploadVideo = true,
    Function(String status)? onStatus,
  }) async {
    onStatus?.call("Connecting to server-side 10Gbps pipeline...");

    try {
      final endpoint = "${ApiConfig.baseUrl}/telegram_extractor.php";
      final body = {
        'bot_token': botToken.trim(),
        'channel_id': channelId.trim(),
        'title': title,
        'caption': caption ?? '',
        'image_urls': imageUrls ?? [],
        'video_url': videoUrl ?? '',
        'upload_photos': uploadPhotos,
        'upload_video': uploadVideo,
      };

      onStatus?.call("Broadcasting via server (0 MB mobile data used)...");

      final res = await http.post(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(minutes: 5));

      final jsonResp = json.decode(res.body);

      if (jsonResp['success'] == true || jsonResp['status'] == 'success') {
        final data = jsonResp['data'] ?? {};
        final photosCount = data['photos_uploaded'] ?? 0;
        final vidSuccess = data['video_uploaded'] == true;

        var msg = "Server broadcast completed!";
        if (photosCount > 0 && vidSuccess) {
          msg = "Uploaded $photosCount photos & native video via server!";
        } else if (photosCount > 0) {
          msg = "Uploaded $photosCount photos to channel!";
        } else if (vidSuccess) {
          msg = "Uploaded native video to channel!";
        }

        return {
          'success': true,
          'message': msg,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'message': jsonResp['message'] ?? 'Server broadcast failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Server error: $e. You can toggle to Client-Side mode if server is unreachable.',
      };
    }
  }

  /// Upload ALL selected photos as complete Telegram Albums (sendMediaGroup) - Client Side
  static Future<Map<String, dynamic>> uploadPhotosAlbum({
    required String botToken,
    required String channelId,
    required List<String> imageUrls,
    String? caption,
    Function(String status)? onStatus,
  }) async {
    if (imageUrls.isEmpty) return {'success': true, 'message': 'No images to upload.'};

    final cleanToken = botToken.trim();
    final cleanChannel = channelId.trim();

    onStatus?.call("Fetching ${imageUrls.length} photos...");

    // 1. Concurrently fetch all image bytes with anti-hotlink bypass headers
    final imageBytesList = <Uint8List>[];
    for (int i = 0; i < imageUrls.length; i++) {
      onStatus?.call("Downloading photo (${i + 1}/${imageUrls.length})...");
      final b = await TelegramCollageHelper.fetchImageBytes(imageUrls[i]);
      if (b != null && b.isNotEmpty) {
        imageBytesList.add(b);
      }
    }

    if (imageBytesList.isEmpty) {
      return {
        'success': false,
        'message': 'Could not download photos from image host.',
      };
    }

    // 2. Split into batches of up to 10 photos (Telegram API maximum per album)
    const int batchSize = 10;
    final batches = <List<Uint8List>>[];
    for (int i = 0; i < imageBytesList.length; i += batchSize) {
      batches.add(imageBytesList.sublist(i, i + batchSize > imageBytesList.length ? imageBytesList.length : i + batchSize));
    }

    onStatus?.call("Uploading ${imageBytesList.length} photo(s) in ${batches.length} album(s) to Telegram...");

    for (int bIdx = 0; bIdx < batches.length; bIdx++) {
      final currentBatch = batches[bIdx];
      final isFirstBatch = bIdx == 0;

      final uri = Uri.parse("https://api.telegram.org/bot$cleanToken/sendMediaGroup");
      final req = http.MultipartRequest('POST', uri)
        ..fields['chat_id'] = cleanChannel;

      final mediaGroup = <Map<String, dynamic>>[];

      for (int i = 0; i < currentBatch.length; i++) {
        final attachKey = 'photo_$i';
        final item = <String, dynamic>{
          'type': 'photo',
          'media': 'attach://$attachKey',
        };

        // Attach caption only to the first photo of the first album
        if (isFirstBatch && i == 0 && caption != null && caption.isNotEmpty) {
          item['caption'] = caption;
          item['parse_mode'] = 'HTML';
        }

        mediaGroup.add(item);

        req.files.add(
          http.MultipartFile.fromBytes(
            attachKey,
            currentBatch[i],
            filename: 'photo_${bIdx}_$i.jpg',
          ),
        );
      }

      req.fields['media'] = json.encode(mediaGroup);

      final streamed = await req.send().timeout(const Duration(seconds: 300));
      final res = await http.Response.fromStream(streamed);
      final body = json.decode(res.body);

      if (body['ok'] != true) {
        return {
          'success': false,
          'message': 'Telegram API error: ${body['description'] ?? res.body}',
        };
      }
    }

    return {
      'success': true,
      'message': 'Uploaded ${imageBytesList.length} photos in ${batches.length} album(s)!',
    };
  }

  /// Upload Native Playable Video to Telegram (sendVideo) - Client Side
  static Future<Map<String, dynamic>> uploadNativeVideo({
    required String botToken,
    required String channelId,
    required String rawVideoUrl,
    required String title,
    String? caption,
    String? posterUrl,
    Function(String status, double progress)? onProgress,
  }) async {
    final cleanToken = botToken.trim();
    final cleanChannel = channelId.trim();

    onProgress?.call("Resolving stream URL...", 0.05);

    // 1. Resolve direct stream link (handles Streamtape, Vidara, Merivo, LuluVdo, etc.)
    String? directStreamUrl;
    try {
      if (StreamtapeService.isStreamtapeFamily(rawVideoUrl)) {
        directStreamUrl = await StreamtapeService.getDirectStreamUrl(rawVideoUrl, forceRefresh: true);
      } else {
        directStreamUrl = await DropmmsService.resolveDirectStream(rawVideoUrl);
      }
    } catch (e) {
      debugPrint("Resolve direct stream error: $e");
    }

    if (directStreamUrl == null || directStreamUrl.isEmpty) {
      directStreamUrl = rawVideoUrl;
    }

    onProgress?.call("Preparing video download...", 0.10);

    File? tempVideoFile;
    try {
      final cleanUrl = directStreamUrl.split('#')[0];
      final headers = _getDomainHeaders(cleanUrl, originalUrl: rawVideoUrl);
      final tempDir = await getTemporaryDirectory();
      tempVideoFile = File('${tempDir.path}/tg_video_${DateTime.now().millisecondsSinceEpoch}.mp4');

      // 2. Determine if HLS (.m3u8) or Direct MP4 Stream
      if (cleanUrl.toLowerCase().contains('.m3u8')) {
        // --- HLS (.m3u8) Downloader & Concatenator ---
        onProgress?.call("Downloading HLS video playlist...", 0.15);
        final hlsSuccess = await _downloadHlsStream(
          m3u8Url: cleanUrl,
          headers: headers,
          outputFile: tempVideoFile,
          onProgress: onProgress,
        );

        if (!hlsSuccess) {
          return {
            'success': false,
            'message': 'Could not download HLS video segments from stream host.',
          };
        }
      } else {
        // --- Direct MP4 Stream Downloader ---
        onProgress?.call("Downloading video from stream host...", 0.15);
        final client = http.Client();
        final request = http.Request('GET', Uri.parse(cleanUrl));
        headers.forEach((k, v) => request.headers[k] = v);

        final streamed = await client.send(request).timeout(const Duration(seconds: 120));
        if (streamed.statusCode >= 400) {
          client.close();
          return {
            'success': false,
            'message': 'Stream host returned HTTP ${streamed.statusCode} while connecting.',
          };
        }

        final contentLength = streamed.contentLength ?? 0;
        final sink = tempVideoFile.openWrite();
        int downloaded = 0;
        final it = StreamIterator<List<int>>(streamed.stream);

        while (await it.moveNext()) {
          final chunk = it.current;
          sink.add(chunk);
          downloaded += chunk.length;

          if (contentLength > 0) {
            final p = (downloaded / contentLength) * 0.45 + 0.15;
            onProgress?.call("Downloading: ${(downloaded / (1024 * 1024)).toStringAsFixed(1)} MB / ${(contentLength / (1024 * 1024)).toStringAsFixed(1)} MB", p);
          } else {
            onProgress?.call("Downloading: ${(downloaded / (1024 * 1024)).toStringAsFixed(1)} MB", 0.35);
          }
        }

        await sink.flush();
        await sink.close();
        client.close();
      }

      if (!await tempVideoFile.exists() || await tempVideoFile.length() < 100 * 1024) {
        final len = await tempVideoFile.exists() ? await tempVideoFile.length() : 0;
        return {
          'success': false,
          'message': 'Downloaded file is too small (${(len / 1024).toStringAsFixed(1)} KB). Stream link may have expired.',
        };
      }

      final downloadedBytes = await tempVideoFile.length();
      final fileSizeMb = (downloadedBytes / (1024 * 1024)).toStringAsFixed(1);

      // Check Telegram Bot API 50 MB limit
      const maxBotBytes = 50 * 1024 * 1024;
      if (downloadedBytes > maxBotBytes) {
        return {
          'success': false,
          'isTooLarge': true,
          'fileSizeMb': fileSizeMb,
          'message': 'Video size is $fileSizeMb MB. Telegram Bot API allows up to 50 MB direct upload. Please tap the Share via Telegram App button to send the full 2GB+ video file.',
        };
      }

      onProgress?.call("Uploading $fileSizeMb MB video directly to Telegram...", 0.65);

      // 3. Upload genuine MP4 file to Telegram Bot API sendVideo
      final uri = Uri.parse("https://api.telegram.org/bot$cleanToken/sendVideo");
      final req = http.MultipartRequest('POST', uri)
        ..fields['chat_id'] = cleanChannel
        ..fields['caption'] = caption ?? title
        ..fields['parse_mode'] = 'HTML'
        ..fields['supports_streaming'] = 'true';

      req.files.add(
        await http.MultipartFile.fromPath(
          'video',
          tempVideoFile.path,
          filename: '${title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')}.mp4',
        ),
      );

      final streamedRes = await req.send().timeout(const Duration(minutes: 5));
      final res = await http.Response.fromStream(streamedRes);
      final body = json.decode(res.body);

      if (body['ok'] == true) {
        return {
          'success': true,
          'message': 'Native video uploaded and playable directly inside Telegram!',
        };
      } else {
        return {
          'success': false,
          'message': 'Telegram API error: ${body['description'] ?? res.body}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Video upload error: $e',
      };
    } finally {
      if (tempVideoFile != null && await tempVideoFile.exists()) {
        try {
          await tempVideoFile.delete();
        } catch (_) {}
      }
    }
  }

  /// Download and concatenate HLS (.m3u8) playlist segments into a single MP4 file
  static Future<bool> _downloadHlsStream({
    required String m3u8Url,
    required Map<String, String> headers,
    required File outputFile,
    Function(String status, double progress)? onProgress,
  }) async {
    try {
      final client = http.Client();
      final req = http.Request('GET', Uri.parse(m3u8Url));
      headers.forEach((k, v) => req.headers[k] = v);

      final res = await client.send(req).timeout(const Duration(seconds: 60));
      if (res.statusCode != 200) {
        client.close();
        return false;
      }

      final bodyText = await res.stream.bytesToString();
      client.close();

      String targetPlaylistUrl = m3u8Url;
      String playlistBody = bodyText;

      // Handle Master Playlist (#EXT-X-STREAM-INF)
      if (bodyText.contains('#EXT-X-STREAM-INF')) {
        final lines = bodyText.split(RegExp(r'\r?\n'));
        final baseUrl = Uri.parse(m3u8Url);
        String? variantUrl;

        for (int i = 0; i < lines.length; i++) {
          final l = lines[i].trim();
          if (l.startsWith('#EXT-X-STREAM-INF')) {
            for (int j = i + 1; j < lines.length; j++) {
              final nextLine = lines[j].trim();
              if (nextLine.isNotEmpty && !nextLine.startsWith('#')) {
                variantUrl = baseUrl.resolve(nextLine).toString();
                break;
              }
            }
            if (variantUrl != null) break;
          }
        }

        if (variantUrl != null) {
          targetPlaylistUrl = variantUrl;
          final vClient = http.Client();
          final vReq = http.Request('GET', Uri.parse(variantUrl));
          headers.forEach((k, v) => vReq.headers[k] = v);
          final vRes = await vClient.send(vReq).timeout(const Duration(seconds: 60));
          if (vRes.statusCode == 200) {
            playlistBody = await vRes.stream.bytesToString();
          }
          vClient.close();
        }
      }

      // Parse segment URLs
      final lines = playlistBody.split(RegExp(r'\r?\n'));
      final baseUrl = Uri.parse(targetPlaylistUrl);
      final segmentUrls = <String>[];

      for (final line in lines) {
        final l = line.trim();
        if (l.isNotEmpty && !l.startsWith('#')) {
          segmentUrls.add(baseUrl.resolve(l).toString());
        }
      }

      if (segmentUrls.isEmpty) return false;

      final sink = outputFile.openWrite();
      int totalDownloaded = 0;

      for (int i = 0; i < segmentUrls.length; i++) {
        final segUrl = segmentUrls[i];
        final segClient = http.Client();
        final segReq = http.Request('GET', Uri.parse(segUrl));
        headers.forEach((k, v) => segReq.headers[k] = v);

        final segRes = await segClient.send(segReq).timeout(const Duration(seconds: 120));
        if (segRes.statusCode == 200 || segRes.statusCode == 206) {
          await for (final chunk in segRes.stream) {
            sink.add(chunk);
            totalDownloaded += chunk.length;
          }
        }
        segClient.close();

        final p = (i / segmentUrls.length) * 0.45 + 0.15;
        final dlMb = (totalDownloaded / (1024 * 1024)).toStringAsFixed(1);
        onProgress?.call("Downloading HLS: $dlMb MB (${i + 1}/${segmentUrls.length} parts)...", p);
      }

      await sink.flush();
      await sink.close();

      return totalDownloaded > 100 * 1024;
    } catch (e) {
      debugPrint("HLS download error: $e");
      return false;
    }
  }

  static Map<String, String> _getDomainHeaders(String url, {String? originalUrl}) {
    final headers = <String, String>{
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      'Accept': '*/*',
      'Connection': 'keep-alive',
    };
    final combined = '$url ${originalUrl ?? ''}'.toLowerCase();

    if (combined.contains('strcloud')) {
      headers['Referer'] = 'https://strcloud.link/';
      headers['Origin'] = 'https://strcloud.link';
    } else if (combined.contains('streamta.pe')) {
      headers['Referer'] = 'https://streamta.pe/';
      headers['Origin'] = 'https://streamta.pe';
    } else if (combined.contains('stape.fun')) {
      headers['Referer'] = 'https://stape.fun/';
      headers['Origin'] = 'https://stape.fun';
    } else if (combined.contains('advtpe')) {
      headers['Referer'] = 'https://advtpe.com/';
      headers['Origin'] = 'https://advtpe.com';
    } else if (combined.contains('streamtape') || combined.contains('tapecontent') || combined.contains('radosgw')) {
      headers['Referer'] = 'https://streamtape.com/';
      headers['Origin'] = 'https://streamtape.com';
    } else if (combined.contains('luluvdo') || combined.contains('lulustream') || combined.contains('tnmr.org') || combined.contains('lulucdn')) {
      headers['Referer'] = 'https://luluvdo.com/';
      headers['Origin'] = 'https://luluvdo.com';
    } else if (combined.contains('merivo') || combined.contains('vidara')) {
      headers['Referer'] = 'https://merivo.fit/';
      headers['Origin'] = 'https://merivo.fit';
    } else if (combined.contains('playmate')) {
      headers['Referer'] = 'https://playmate.to/';
      headers['Origin'] = 'https://playmate.to';
    } else if (combined.contains('vibevdo')) {
      headers['Referer'] = 'https://vibevdo.xyz/';
      headers['Origin'] = 'https://vibevdo.xyz';
    } else if (combined.contains('vidsonic')) {
      headers['Referer'] = 'https://vidsonic.net/';
      headers['Origin'] = 'https://vidsonic.net';
    } else if (combined.contains('maal') || combined.contains('uffmaal') || combined.contains('azmaal') || combined.contains('bmaal') || combined.contains('pmaal') || combined.contains('hmaal')) {
      headers['Referer'] = 'https://uffmaal.com/';
      headers['Origin'] = 'https://uffmaal.com';
    } else {
      headers['Referer'] = 'https://dropmms.co/';
    }
    return headers;
  }
}
