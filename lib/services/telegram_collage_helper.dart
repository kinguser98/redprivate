import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class TelegramCollageHelper {
  /// Fetch image bytes from any HTTP / HTTPS URL
  static Future<Uint8List?> fetchImageBytes(String url) async {
    final clean = url.trim();
    if (clean.isEmpty) return null;
    try {
      final res = await http.get(Uri.parse(clean), headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': 'image/webp,image/apng,image/*,*/*;q=0.8',
      }).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        return res.bodyBytes;
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
