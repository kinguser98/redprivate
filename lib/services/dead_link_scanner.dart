import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class DeadLinkScanner {
  // Scans a single Streamtape or MP4 stream link to check if it's dead
  static Future<bool> isLinkDead(String url) async {
    if (url.trim().isEmpty) return true;
    try {
      final uri = Uri.parse(url);

      // 1. Direct HTTP HEAD/GET request
      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode >= 400) {
        return true;
      }

      // 2. Streamtape signature check for deleted or removed videos
      final body = response.body.toLowerCase();
      if (body.contains("video deleted") ||
          body.contains("video not found") ||
          body.contains("file deleted") ||
          body.contains("file not found") ||
          body.contains("has been removed")) {
        return true;
      }

      return false;
    } catch (e) {
      print("Scanner link check exception for $url: $e");
      // Network failure or timeout treated as broken link
      return true;
    }
  }

  // Trigger backend scan and auto-park dead links
  static Future<Map<String, dynamic>> scanAndParkDeadLinks() async {
    try {
      final scanMovieRes = await http.post(
        Uri.parse(ApiConfig.adminUrl),
        body: json.encode({'action': 'scan_movie_links', 'offset': 0, 'limit': 50}),
        headers: {'Content-Type': 'application/json'},
      );

      final scanEpRes = await http.post(
        Uri.parse(ApiConfig.adminUrl),
        body: json.encode({'action': 'scan_episode_links', 'offset': 0, 'limit': 50}),
        headers: {'Content-Type': 'application/json'},
      );

      final parkRes = await http.post(
        Uri.parse(ApiConfig.adminUrl),
        body: json.encode({'action': 'park_dead_content'}),
        headers: {'Content-Type': 'application/json'},
      );

      return {
        'status': 'success',
        'movie_scan': json.decode(scanMovieRes.body),
        'ep_scan': json.decode(scanEpRes.body),
        'park_result': json.decode(parkRes.body),
      };
    } catch (e) {
      return {'status': 'error', 'message': '$e'};
    }
  }
}
