import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/download_service.dart';
import '../services/media_store_saver.dart';
import 'video_player_screen.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({Key? key}) : super(key: key);

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  String _searchQuery = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    DownloadManager.instance.ensureLoaded();
  }

  Future<void> _saveToDownloads(DownloadTask task) async {
    final file = File(task.filePath);
    if (!file.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Download file missing on device.")),
      );
      return;
    }
    setState(() => _saving = true);

    bool isTs = false;
    try {
      final raf = await file.open(mode: FileMode.read);
      final header = await raf.read(16);
      await raf.close();
      if (header.isNotEmpty && header[0] == 0x47) {
        isTs = true;
      }
    } catch (_) {}

    final ext = isTs ? '.ts' : '.mp4';
    final mime = isTs ? 'video/mp2t' : 'video/mp4';
    final name = '${task.title}$ext'.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final ok = await MediaStoreSaver.saveToDownloads(task.filePath, name, mime: mime);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? "Saved to your Downloads folder ($ext)"
            : "Could not save. Try granting storage permission in Settings."),
        backgroundColor: ok ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14141C),
        elevation: 0,
        title: const Text(
          "Downloads Manager",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: Column(
        children: [
          _buildLocationCard(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Search downloads...",
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Colors.cyanAccent),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, color: Colors.white38),
                        onPressed: () => setState(() => _searchQuery = ''))
                    : null,
                filled: true,
                fillColor: const Color(0xFF141722),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<List<DownloadTask>>(
              valueListenable: DownloadManager.instance.tasksNotifier,
              builder: (context, tasks, _) {
                final q = _searchQuery.trim().toLowerCase();
                final filtered = q.isEmpty
                    ? tasks
                    : tasks
                        .where((t) => t.title.toLowerCase().contains(q))
                        .toList();
                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.download_rounded, color: Colors.white24, size: 64),
                        const SizedBox(height: 12),
                        Text(
                          q.isEmpty
                              ? "No downloads yet.\nUse the Download button on any content."
                              : "No matching downloads.",
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white38, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) => _buildTaskCard(filtered[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFF232A3C).withOpacity(0.9), const Color(0xFF161B28).withOpacity(0.9)],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.cyanAccent.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.cyanAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.save_alt_rounded, color: Colors.cyanAccent, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Downloads",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  SizedBox(height: 3),
                  Text(
                    "Videos are saved to app storage. Use SAVE TO DOWNLOADS on a finished video to keep it in your phone's Downloads folder.",
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(DownloadTask task) {
    final status = task.status;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF232A3C).withOpacity(0.9), const Color(0xFF161B28).withOpacity(0.9)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: task.poster.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: task.poster, width: 52, height: 70, fit: BoxFit.cover,
                        errorWidget: (c, u, e) => Container(width: 52, height: 70, color: const Color(0xFF2A3145), child: Icon(_statusIcon(status), color: _statusColor(status), size: 24)))
                    : Container(width: 52, height: 70, color: const Color(0xFF2A3145), child: Icon(_statusIcon(status), color: _statusColor(status), size: 24)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(_statusLabel(task), style: TextStyle(color: _statusColor(status), fontSize: 12)),
                  ],
                ),
              ),
              _taskActions(task),
            ],
          ),
          if (status == DownloadStatus.downloading || status == DownloadStatus.paused) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: task.total > 0 ? task.progress : null,
                minHeight: 6,
                backgroundColor: Colors.white10,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8E2DE2)),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              task.total > 0
                  ? '${_formatBytes(task.downloaded)} / ${_formatBytes(task.total)}   |   ${(task.progress * 100).toStringAsFixed(0)}%'
                  : '${_formatBytes(task.downloaded)}   |   ${_formatBytes(task.speedBytesPerSecond)}/s',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
            const SizedBox(height: 4),
            Text(
              'Size: ${task.total > 0 ? _formatBytes(task.total) : 'Unknown'}   |   Speed: ${_formatBytes(task.speedBytesPerSecond)}/s   |   Elapsed: ${_formatDuration(task.elapsed)}'
              '${task.eta != null ? '   |   ETA: ${_formatDuration(task.eta!)}' : ''}',
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }

  Widget _taskActions(DownloadTask task) {
    final actions = <Widget>[];
    switch (task.status) {
      case DownloadStatus.downloading:
        actions.add(_iconBtn(Icons.pause_rounded, Colors.orangeAccent, () => DownloadManager.instance.pause(task.id)));
        actions.add(_iconBtn(Icons.delete_outline_rounded, Colors.redAccent, () => DownloadManager.instance.remove(task.id)));
        break;
      case DownloadStatus.paused:
        actions.add(_iconBtn(Icons.play_arrow_rounded, Colors.greenAccent, () => DownloadManager.instance.resume(task.id)));
        actions.add(_iconBtn(Icons.delete_outline_rounded, Colors.redAccent, () => DownloadManager.instance.remove(task.id)));
        break;
      case DownloadStatus.completed:
        actions.add(_iconBtn(Icons.play_circle_fill_rounded, Colors.cyanAccent, () => _playDownload(task)));
        actions.add(_iconBtn(Icons.save_alt_rounded, Colors.greenAccent, _saving ? null : () => _saveToDownloads(task)));
        actions.add(_iconBtn(Icons.delete_outline_rounded, Colors.redAccent, () => DownloadManager.instance.remove(task.id)));
        break;
      case DownloadStatus.error:
        actions.add(_iconBtn(Icons.refresh_rounded, Colors.orangeAccent, () => DownloadManager.instance.resume(task.id)));
        actions.add(_iconBtn(Icons.delete_outline_rounded, Colors.redAccent, () => DownloadManager.instance.remove(task.id)));
        break;
      case DownloadStatus.queued:
        actions.add(_iconBtn(Icons.delete_outline_rounded, Colors.redAccent, () => DownloadManager.instance.remove(task.id)));
        break;
    }
    return Row(mainAxisSize: MainAxisSize.min, children: actions);
  }

  void _playDownload(DownloadTask task) {
    if (!File(task.filePath).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Download file missing on device.")),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(videoUrl: task.filePath, videoTitle: task.title),
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback? onTap) {
    return IconButton(
      icon: Icon(icon, color: color, size: 22),
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
    );
  }

  Color _statusColor(DownloadStatus s) {
    switch (s) {
      case DownloadStatus.completed:
        return Colors.greenAccent;
      case DownloadStatus.downloading:
        return const Color(0xFF8E2DE2);
      case DownloadStatus.paused:
        return Colors.orangeAccent;
      case DownloadStatus.error:
        return Colors.redAccent;
      case DownloadStatus.queued:
        return Colors.white54;
    }
  }

  IconData _statusIcon(DownloadStatus s) {
    switch (s) {
      case DownloadStatus.completed:
        return Icons.download_done_rounded;
      case DownloadStatus.downloading:
        return Icons.download_rounded;
      case DownloadStatus.paused:
        return Icons.pause_circle_rounded;
      case DownloadStatus.error:
        return Icons.error_outline_rounded;
      case DownloadStatus.queued:
        return Icons.hourglass_bottom_rounded;
    }
  }

  String _statusLabel(DownloadTask task) {
    switch (task.status) {
      case DownloadStatus.completed:
        final size = task.total > 0 ? task.total : task.downloaded;
        return 'Completed  |  ${_formatBytes(size)}';
      case DownloadStatus.downloading:
        return 'Downloading...';
      case DownloadStatus.paused:
        return 'Paused - tap play to resume';
      case DownloadStatus.error:
        return 'Error: ${task.error ?? 'Unknown'}';
      case DownloadStatus.queued:
        return 'Queued...';
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}
