import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'streamtape_service.dart';

enum DownloadStatus { queued, downloading, paused, completed, error }

class DownloadTask {
  final String id;
  String url;
  String originalUrl;
  String title;
  String poster;
  final String filePath;
  int total;
  int downloaded;
  DownloadStatus status;
  String? error;

  // Runtime metrics (not persisted)
  DateTime? startedAt;
  Duration elapsedBefore = Duration.zero;
  int speedBytesPerSecond = 0;
  int _markBytes = 0;
  DateTime _markTime = DateTime.now();

  Duration get elapsed {
    final base = elapsedBefore;
    if (startedAt == null) return base;
    return base + DateTime.now().difference(startedAt!);
  }

  Duration? get eta {
    if (speedBytesPerSecond <= 0 || total <= 0) return null;
    final remaining = total - downloaded;
    if (remaining <= 0) return Duration.zero;
    return Duration(seconds: remaining ~/ speedBytesPerSecond);
  }

  DownloadTask({
    required this.id,
    required this.url,
    this.originalUrl = '',
    required this.title,
    this.poster = '',
    required this.filePath,
    this.total = 0,
    this.downloaded = 0,
    this.status = DownloadStatus.queued,
    this.error,
  }) {
    if (originalUrl.isEmpty) originalUrl = url;
  }

  double get progress {
    if (total <= 0) return downloaded > 0 ? 0.1 : 0;
    return (downloaded / total).clamp(0.0, 1.0);
  }

  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    final urlVal = json['url']?.toString() ?? '';
    final origVal = json['originalUrl']?.toString() ?? '';
    return DownloadTask(
      id: json['id']?.toString() ?? '',
      url: urlVal,
      originalUrl: origVal.isNotEmpty ? origVal : urlVal,
      title: json['title']?.toString() ?? '',
      poster: json['poster']?.toString() ?? '',
      filePath: json['filePath']?.toString() ?? '',
      total: json['total'] as int? ?? 0,
      downloaded: json['downloaded'] as int? ?? 0,
      status: DownloadStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => DownloadStatus.paused,
      ),
      error: json['error']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'originalUrl': originalUrl,
        'title': title,
        'poster': poster,
        'filePath': filePath,
        'total': total,
        'downloaded': downloaded,
        'status': status.name,
        'error': error,
      };
}

class DownloadManager {
  DownloadManager._();
  static final DownloadManager instance = DownloadManager._();

  static const String _prefsKey = 'download_tasks_v1';
  static const String _dirPrefsKey = 'download_directory';
  String? _customDirectory;

  final ValueNotifier<List<DownloadTask>> tasksNotifier = ValueNotifier([]);
  final Map<String, StreamSubscription<List<int>>> _subs = {};
  final Map<String, IOSink> _sinks = {};
  final Map<String, http.Client> _clients = {};

  bool _loaded = false;
  DateTime _lastNotify = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final tasks = decoded
              .map((e) => DownloadTask.fromJson(e as Map<String, dynamic>))
              .toList();
          tasksNotifier.value = tasks;
        }
      }
    } catch (_) {}

    // Auto-resume downloads that were interrupted by an app kill
    final toResume = tasksNotifier.value
        .where((t) =>
            t.status == DownloadStatus.downloading ||
            t.status == DownloadStatus.queued)
        .toList();
    for (final t in toResume) {
      if (t.status == DownloadStatus.downloading) t.status = DownloadStatus.paused;
      resume(t.id);
    }
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(
          tasksNotifier.value.map((t) => t.toJson()).toList());
      await prefs.setString(_prefsKey, encoded);
    } catch (_) {}
  }

  Future<String> _resolveDownloadDirectory() async {
    if (_customDirectory == null) {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_dirPrefsKey);
      if (saved != null && saved.isNotEmpty) _customDirectory = saved;
    }
    if (_customDirectory != null && _customDirectory!.isNotEmpty) {
      try {
        final d = Directory(_customDirectory!);
        if (!d.existsSync()) d.createSync(recursive: true);
        return _customDirectory!;
      } catch (_) {
        // fall through to default
      }
    }
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/downloads');
    if (!folder.existsSync()) folder.createSync(recursive: true);
    return folder.path;
  }

  Future<void> setDownloadDirectory(String path) async {
    _customDirectory = path;
    try {
      final d = Directory(path);
      if (!d.existsSync()) d.createSync(recursive: true);
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dirPrefsKey, path);
  }

  Future<void> resetDownloadDirectory() async {
    _customDirectory = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_dirPrefsKey);
  }

  Future<String?> getDownloadDirectory() async {
    if (_customDirectory == null) {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_dirPrefsKey);
      if (saved != null && saved.isNotEmpty) _customDirectory = saved;
    }
    return _customDirectory;
  }

  Future<DownloadTask?> start(String url, String title,
      {String poster = '', String originalUrl = ''}) async {
    await ensureLoaded();
    if (url.isEmpty) return null;

    final orig = originalUrl.isNotEmpty ? originalUrl : url;

    // Skip if an identical URL is already downloading/queued/paused
    final dup = tasksNotifier.value.firstWhere(
      (t) => (t.url == url || t.originalUrl == orig) && t.status != DownloadStatus.completed,
      orElse: () => DownloadTask(
          id: '', url: '', title: '', filePath: '', status: DownloadStatus.completed),
    );
    if (dup.url.isNotEmpty) {
      resume(dup.id);
      return dup;
    }

    final folder = Directory(await _resolveDownloadDirectory());
    if (!folder.existsSync()) folder.createSync(recursive: true);

    final safe = title
        .replaceAll(RegExp(r'[^\w\s.\-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = '${folder.path}/${safe.isEmpty ? 'download' : safe}_$stamp.mp4';

    final task = DownloadTask(
      id: stamp.toString(),
      url: url,
      originalUrl: orig,
      title: title,
      poster: poster,
      filePath: filePath,
      status: DownloadStatus.queued,
    );
    tasksNotifier.value = [...tasksNotifier.value, task];
    await _persist();
    resume(task.id);
    return task;
  }

  Future<void> resume(String id) async {
    final task = _find(id);
    if (task == null) return;
    if (task.status == DownloadStatus.completed) return;
    task.status = DownloadStatus.downloading;
    task.error = null;
    _notify();
    await _run(task);
  }

  void pause(String id) {
    final task = _find(id);
    if (task == null) return;
    task.status = DownloadStatus.paused;
    _subs.remove(id)?.cancel();
    _cleanup(id);
    _notify();
    _persist();
  }

  void remove(String id) {
    final task = _find(id);
    if (task == null) return;
    _subs.remove(id)?.cancel();
    _cleanup(id);
    tasksNotifier.value = tasksNotifier.value.where((t) => t.id != id).toList();
    try {
      File(task.filePath).deleteSync();
    } catch (_) {}
    _notify();
    _persist();
  }

  Future<void> _run(DownloadTask task) async {
    for (int attempt = 1; attempt <= 3; attempt++) {
      if (task.status != DownloadStatus.downloading) return;
      final result = await _attempt(task);
      if (result == 'completed' || result == 'paused' || result == 'error') {
        return;
      }
      // 'retry' — transient connection failure (e.g. CDN closing early)
      if (task.status != DownloadStatus.downloading) return;
      _notify();
      await Future.delayed(const Duration(milliseconds: 1500));
    }
    if (task.status == DownloadStatus.downloading) {
      task.status = DownloadStatus.error;
      task.error = 'Download failed after retries';
      _notify();
      _persist();
    }
  }

  Future<String> _attempt(DownloadTask task) async {
    final lowerUrl = task.url.toLowerCase();
    final lowerOrig = task.originalUrl.toLowerCase();

    final isStreamtape = lowerUrl.contains('tapecontent') ||
        lowerUrl.contains('streamtape') ||
        lowerUrl.contains('strcloud') ||
        lowerUrl.contains('tapepops') ||
        lowerUrl.contains('tpead') ||
        lowerUrl.contains('advtpe') ||
        lowerOrig.contains('streamtape') ||
        lowerOrig.contains('advtpe');

    if (StreamtapeService.isStreamtapeFamily(task.url) || !task.url.startsWith('http')) {
      final resolved = await StreamtapeService.getDirectStreamUrl(
          task.originalUrl.isNotEmpty ? task.originalUrl : task.url);
      if (resolved != null && resolved.isNotEmpty && resolved.startsWith('http')) {
        task.url = resolved;
      }
    }

    if (task.url.contains('#')) {
      task.url = task.url.split('#')[0];
    }

    // Direct (non-proxy, non-Streamtape) downloads can use parallel segments for high speed.
    // Streamtape (tapecontent.net) requires single-threaded direct streaming.
    if (!isStreamtape &&
        !task.url.contains('download_proxy.php') &&
        (task.total == 0 || task.downloaded < task.total)) {
      try {
        final probeClient = http.Client();
        final req = http.Request('GET', Uri.parse(task.url));
        req.headers['Range'] = 'bytes=0-0';
        _applyHeaders(req);
        final res = await probeClient.send(req).timeout(const Duration(seconds: 20));
        if (res.statusCode == 206) {
          int total = 0;
          final cr = res.headers['content-range'];
          if (cr != null && cr.contains('/')) {
            total = int.tryParse(cr.split('/').last.trim()) ?? 0;
          }
          res.stream.listen((_) {}).cancel();
          probeClient.close();
          if (total > 1024 * 1024) {
            task.total = total;
            _notify();
            return _downloadSegments(task, total);
          }
        } else {
          res.stream.listen((_) {}).cancel();
        }
        probeClient.close();
      } catch (_) {}
    }

    final result = await _downloadSingle(task);

    if (result == 'retry' && isStreamtape && task.originalUrl.isNotEmpty) {
      final fresh = await StreamtapeService.getDirectStreamUrl(task.originalUrl, forceRefresh: true);
      if (fresh != null && fresh.isNotEmpty && fresh.startsWith('http')) {
        debugPrint("Re-resolved fresh Streamtape ticket for download: $fresh");
        task.url = fresh;
        return _downloadSingle(task);
      }
    }

    return result;
  }

  Future<String> _downloadSegments(DownloadTask task, int total) async {
    const threadCount = 4;
    final chunkSize = total ~/ threadCount;
    final errors = <String>[];
    task.startedAt ??= DateTime.now();

    final futures = <Future<void>>[];
    for (int i = 0; i < threadCount; i++) {
      final seg = i;
      final start = seg * chunkSize;
      final end = (seg == threadCount - 1) ? total - 1 : (seg + 1) * chunkSize - 1;
      futures.add(_downloadSegment(task, seg, start, end, errors));
    }
    await Future.wait(futures);

    if (task.status != DownloadStatus.downloading) {
      _accumulateElapsed(task);
      return 'paused';
    }
    if (errors.isNotEmpty) {
      _accumulateElapsed(task);
      return 'retry'; // partial parts are kept; retry resumes them
    }
    // Merge all parts into the final file
    try {
      final finalFile = File(task.filePath);
      final sink = finalFile.openWrite(mode: FileMode.write);
      try {
        for (int i = 0; i < threadCount; i++) {
          final part = File('${task.filePath}.part$i');
          if (await part.exists()) {
            await sink.addStream(part.openRead());
            await part.delete();
          }
        }
      } finally {
        await sink.close();
      }
    } catch (_) {
      return 'retry';
    }
    task.status = DownloadStatus.completed;
    task.downloaded = total;
    _notify();
    _persist();
    return 'completed';
  }

  Future<void> _downloadSegment(
      DownloadTask task, int seg, int start, int end, List<String> errors) async {
    try {
      final partFile = File('${task.filePath}.part$seg');
      int partLen = 0;
      if (await partFile.exists()) partLen = await partFile.length();
      final from = start + partLen;
      if (from > end) return;

      final client = http.Client();
      final req = http.Request('GET', Uri.parse(task.url));
      req.headers['Range'] = 'bytes=$from-$end';
      _applyHeaders(req);
      final res = await client.send(req).timeout(const Duration(seconds: 30));
      if (res.statusCode != 200 && res.statusCode != 206) {
        client.close();
        throw Exception('Segment $seg HTTP ${res.statusCode}');
      }
      final sink = partFile.openWrite(mode: FileMode.append);
      try {
        final it = StreamIterator<List<int>>(res.stream);
        while (await it.moveNext().timeout(const Duration(seconds: 30))) {
          if (task.status != DownloadStatus.downloading) break;
          final chunk = it.current!;
          sink.add(chunk);
          task.downloaded += chunk.length;
          _updateMetrics(task, chunk.length);
          _notifyThrottled();
        }
      } finally {
        await sink.close();
      }
      client.close();
    } catch (e) {
      errors.add('$e');
    }
  }

  void _applyHeaders(http.Request request) {
    request.headers['User-Agent'] =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36';
    request.headers['Referer'] = 'https://streamtape.com/';
    request.headers['Accept'] = '*/*';
  }

  Future<String> _downloadSingle(DownloadTask task) async {
    IOSink? sink;
    try {
      sink = File(task.filePath).openWrite(mode: FileMode.append);
      _sinks[task.id] = sink;

      // Dynamic Burst Chunking (15MB blocks): Requesting finite 15MB Range blocks ensures
      // Streamtape's CDN server delivers every chunk at initial maximum unthrottled burst speed (~10-15 MB/s).
      const chunkSize = 15 * 1024 * 1024;

      while (task.status == DownloadStatus.downloading) {
        final client = http.Client();
        _clients[task.id] = client;

        final rangeStart = task.downloaded;
        final rangeEnd = rangeStart + chunkSize - 1;

        final cleanUrl = task.url.split('#')[0];
        final request = http.Request('GET', Uri.parse(cleanUrl));
        request.headers['Range'] = 'bytes=$rangeStart-$rangeEnd';
        request.headers['User-Agent'] =
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36';
        request.headers['Referer'] = 'https://streamtape.com/';
        request.headers['Accept'] = '*/*';

        final streamed =
            await client.send(request).timeout(const Duration(seconds: 25));

        final contentType = streamed.headers['content-type'] ?? '';
        if (streamed.statusCode >= 400) {
          client.close();
          if (task.downloaded > 0) return 'retry';
          return 'retry';
        }
        if (task.downloaded == 0 &&
            contentType.toLowerCase().contains('text/html')) {
          client.close();
          return 'retry';
        }

        final cr = streamed.headers['content-range'];
        if (cr != null && cr.contains('/')) {
          final totalStr = cr.split('/').last.trim();
          final parsedTotal = int.tryParse(totalStr);
          if (parsedTotal != null && parsedTotal > 0) {
            task.total = parsedTotal;
          }
        } else {
          final xSize = streamed.headers['x-file-size'];
          if (xSize != null && int.tryParse(xSize) != null) {
            task.total = int.parse(xSize);
          } else if (task.total == 0 && streamed.contentLength != null) {
            task.total = task.downloaded + streamed.contentLength!;
          }
        }
        _notify();

        final it = StreamIterator<List<int>>(streamed.stream);
        bool first = true;
        int bytesInChunk = 0;

        while (await it.moveNext()) {
          final chunk = it.current;
          if (task.status == DownloadStatus.paused) {
            client.close();
            try {
              await sink.flush();
              await sink.close();
            } catch (_) {}
            _cleanup(task.id);
            _accumulateElapsed(task);
            return 'paused';
          }
          if (first) {
            first = false;
            if (chunk.length < 4096 && _isTextLike(chunk)) {
              client.close();
              try {
                await sink.flush();
                await sink.close();
              } catch (_) {}
              _cleanup(task.id);
              return 'retry';
            }
          }
          bytesInChunk += chunk.length;
          task.downloaded += chunk.length;
          sink.add(chunk);
          _updateMetrics(task, chunk.length);
          _notifyThrottled();
        }

        client.close();

        // If server returned 200 (full file) or chunk received 0 bytes or we reached total, finish!
        if (streamed.statusCode == 200 ||
            bytesInChunk == 0 ||
            (task.total > 0 && task.downloaded >= task.total)) {
          break;
        }
      }

      try {
        await sink.flush();
        await sink.close();
      } catch (_) {}

      if (task.status == DownloadStatus.downloading) {
        task.status = DownloadStatus.completed;
      }
      _notify();
      _cleanup(task.id);
      _persist();
      return 'completed';
    } catch (e, stack) {
      debugPrint("Download exception for task ${task.id}: $e\n$stack");
      task.error = '$e';
      try {
        await sink?.flush();
        await sink?.close();
      } catch (_) {}
      _cleanup(task.id);
      _accumulateElapsed(task);
      if (task.status == DownloadStatus.paused) return 'paused';
      return 'retry';
    }
  }

  bool _isTextLike(List<int> chunk) {
    final n = chunk.length < 32 ? chunk.length : 32;
    int printable = 0;
    for (int i = 0; i < n; i++) {
      final b = chunk[i];
      if (b == 9 || b == 10 || b == 13 || (b >= 32 && b < 127)) printable++;
    }
    return printable >= n - 1;
  }

  void _updateMetrics(DownloadTask task, int bytes) {
    if (task.startedAt == null) task.startedAt = DateTime.now();
    final now = DateTime.now();
    if (now.difference(task._markTime) >= const Duration(seconds: 1)) {
      final dtMs = now.difference(task._markTime).inMilliseconds;
      final delta = task.downloaded - task._markBytes;
      if (dtMs > 0 && delta >= 0) {
        task.speedBytesPerSecond = (delta * 1000 ~/ dtMs);
      }
      task._markBytes = task.downloaded;
      task._markTime = now;
    }
  }

  void _accumulateElapsed(DownloadTask task) {
    if (task.startedAt != null) {
      task.elapsedBefore += DateTime.now().difference(task.startedAt!);
      task.startedAt = null;
    }
  }

  void _cleanup(String id) {
    _subs.remove(id)?.cancel();
    _sinks.remove(id);
    _clients.remove(id)?.close();
  }

  DownloadTask? _find(String id) {
    for (final t in tasksNotifier.value) {
      if (t.id == id) return t;
    }
    return null;
  }

  void _notify() {
    tasksNotifier.value = [...tasksNotifier.value];
    _lastNotify = DateTime.now();
  }

  void _notifyThrottled() {
    final now = DateTime.now();
    if (now.difference(_lastNotify).inMilliseconds >= 250) {
      _lastNotify = now;
      tasksNotifier.value = [...tasksNotifier.value];
    }
  }
}
