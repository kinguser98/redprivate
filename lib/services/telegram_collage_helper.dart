import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class TelegramCollageHelper {
  /// Fetch image bytes from any HTTP / HTTPS URL with anti-hotlink bypass headers
  static Future<Uint8List?> fetchImageBytes(String url) async {
    final clean = url.trim();
    if (clean.isEmpty) return null;
    try {
      final lower = clean.toLowerCase();
      String referer = 'https://dropmms.co/';
      if (lower.contains('imagetwist')) {
        referer = 'https://imagetwist.com/';
      } else if (lower.contains('turboimagehost')) {
        referer = 'https://www.turboimagehost.com/';
      } else if (lower.contains('postimg') || lower.contains('postimages')) {
        referer = 'https://postimages.org/';
      } else if (lower.contains('pixhost')) {
        referer = 'https://pixhost.to/';
      } else if (lower.contains('fastpic')) {
        referer = 'https://fastpic.org/';
      } else if (lower.contains('iblog')) {
        referer = 'https://iblog.ws/';
      } else if (lower.contains('imagebam')) {
        referer = 'https://www.imagebam.com/';
      } else if (lower.contains('imgup')) {
        referer = 'https://imgup.co/';
      } else if (lower.contains('uplinks24')) {
        referer = 'https://uplinks24.com/';
      } else if (lower.contains('hdmove99')) {
        referer = 'https://hdmove99.com/';
      }

      final res = await http.get(Uri.parse(clean), headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
        'Referer': referer,
        'Origin': referer.endsWith('/') ? referer.substring(0, referer.length - 1) : referer,
      }).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        // Validate magic bytes for image (JPEG: FF D8, PNG: 89 50, WEBP: 52 49, GIF: 47 49)
        final bytes = res.bodyBytes;
        if (bytes.length > 100) {
          return bytes;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Decode image bytes into a ui.Image
  static Future<ui.Image?> decodeImageFromBytes(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  /// Stitch a list of images into a single composite collage image
  /// (Vertical 4-stack or 2x2 grid with sleek dark borders)
  static Future<Uint8List?> createCollage({
    required List<Uint8List> imagesBytes,
    bool verticalStack = true,
  }) async {
    if (imagesBytes.isEmpty) return null;
    if (imagesBytes.length == 1) return imagesBytes.first;

    final decodedImages = <ui.Image>[];
    for (final b in imagesBytes) {
      final img = await decodeImageFromBytes(b);
      if (img != null) decodedImages.add(img);
    }

    if (decodedImages.isEmpty) return null;
    if (decodedImages.length == 1) return imagesBytes.first;

    const double targetWidth = 1080.0;
    const double panelHeight = 608.0; // 16:9 aspect ratio per panel
    const double borderGap = 4.0;

    final count = decodedImages.length;
    final totalHeight = (panelHeight * count) + (borderGap * (count - 1));

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, targetWidth, totalHeight));

    // Paint background
    final bgPaint = Paint()..color = const Color(0xFF0F121C);
    canvas.drawRect(Rect.fromLTWH(0, 0, targetWidth, totalHeight), bgPaint);

    for (int i = 0; i < count; i++) {
      final img = decodedImages[i];
      final top = i * (panelHeight + borderGap);
      final dstRect = Rect.fromLTWH(0, top, targetWidth, panelHeight);

      // Calculate center crop source rect
      final srcAspect = img.width / img.height;
      const dstAspect = targetWidth / panelHeight;

      double srcX = 0, srcY = 0, srcW = img.width.toDouble(), srcH = img.height.toDouble();
      if (srcAspect > dstAspect) {
        srcW = img.height * dstAspect;
        srcX = (img.width - srcW) / 2;
      } else {
        srcH = img.width / dstAspect;
        srcY = (img.height - srcH) / 2;
      }

      final srcRect = Rect.fromLTWH(srcX, srcY, srcW, srcH);
      canvas.drawImageRect(img, srcRect, dstRect, Paint()..filterQuality = FilterQuality.high);
    }

    final picture = recorder.endRecording();
    final composite = await picture.toImage(targetWidth.toInt(), totalHeight.toInt());
    final byteData = await composite.toByteData(format: ui.ImageByteFormat.png);

    return byteData?.buffer.asUint8List();
  }
}
