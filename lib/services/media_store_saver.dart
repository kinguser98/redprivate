import 'package:flutter/services.dart';

/// Saves a downloaded file to the phone's public Downloads / Movies folders
/// via the native MediaStore API (no storage permission needed on Android 10+).
class MediaStoreSaver {
  static const MethodChannel _channel = MethodChannel('com.red.app/save');

  static Future<bool> saveToDownloads(String path, String name) async {
    return _invoke('saveToDownloads', path, name, 'video/mp4');
  }

  static Future<bool> saveToMovies(String path, String name) async {
    return _invoke('saveToMovies', path, name, 'video/mp4');
  }

  static Future<bool> _invoke(
      String method, String path, String name, String mime) async {
    try {
      final ok = await _channel.invokeMethod<bool>(method, {
        'path': path,
        'name': name,
        'mime': mime,
      });
      return ok == true;
    } catch (e) {
      print('MediaStoreSaver.$method error: $e');
      return false;
    }
  }
}
