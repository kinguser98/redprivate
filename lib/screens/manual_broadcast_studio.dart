import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/telegram_extractor_service.dart';

/// 🎙️ Manual Broadcast Studio
/// Allows pasting any video URL (Streamtape, Vidara, direct MP4/M3U8) and/or
/// photo URLs and sending them to the Telegram group via server or client engine.
class ManualBroadcastStudio extends StatefulWidget {
  const ManualBroadcastStudio({Key? key}) : super(key: key);

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => const ManualBroadcastStudio(),
    );
  }

  @override
  State<ManualBroadcastStudio> createState() => _ManualBroadcastStudioState();
}

class _ManualBroadcastStudioState extends State<ManualBroadcastStudio>
    with SingleTickerProviderStateMixin {
  // Controllers
  final _videoUrlCtrl = TextEditingController();
  final _photoUrlsCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _captionCtrl = TextEditingController();
  final _botTokenCtrl = TextEditingController();
  final _channelCtrl = TextEditingController();

  // State
  bool _isLoadingSettings = true;
  bool _isBroadcasting = false;
  bool _useServer = true;
  bool _sendVideo = true;
  bool _sendPhotos = true;
  String _status = '';
  double _progress = 0.0;
  String? _error;
  String? _success;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
          ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.85, end: 1.0).animate(_pulseCtrl);
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final s = await TelegramExtractorService.loadSettings();
    if (!mounted) return;
    setState(() {
      _botTokenCtrl.text = s['botToken'] ?? '';
      _channelCtrl.text = s['channelId'] ?? '';
      _useServer = s['useServer'] ?? true;
      _isLoadingSettings = false;
    });
  }

  @override
  void dispose() {
    _videoUrlCtrl.dispose();
    _photoUrlsCtrl.dispose();
    _titleCtrl.dispose();
    _captionCtrl.dispose();
    _botTokenCtrl.dispose();
    _channelCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  List<String> get _photoList {
    return _photoUrlsCtrl.text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && e.startsWith('http'))
        .toList();
  }

  Future<void> _broadcast() async {
    final videoUrl = _videoUrlCtrl.text.trim();
    final title = _titleCtrl.text.trim().isEmpty ? 'Broadcast' : _titleCtrl.text.trim();
    final caption = _captionCtrl.text.trim();
    final botToken = _botTokenCtrl.text.trim();
    final channelId = _channelCtrl.text.trim();

    if (botToken.isEmpty || channelId.isEmpty) {
      setState(() => _error = 'Bot Token and Channel ID are required.');
      return;
    }

    final hasVideo = _sendVideo && videoUrl.isNotEmpty;
    final hasPhotos = _sendPhotos && _photoList.isNotEmpty;

    if (!hasVideo && !hasPhotos) {
      setState(() => _error = 'Paste at least one video URL or photo URL.');
      return;
    }

    setState(() {
      _isBroadcasting = true;
      _error = null;
      _success = null;
      _status = 'Starting broadcast...';
      _progress = 0.0;
    });

    // Save settings
    await TelegramExtractorService.saveSettings(
      botToken: botToken,
      channelId: channelId,
      useServer: _useServer,
    );

    try {
      Map<String, dynamic> result;

      if (_useServer) {
        // 🚀 Server-side (0 MB mobile data)
        setState(() => _status = 'Routing via server 10Gbps pipeline...');
        result = await TelegramExtractorService.uploadViaServer(
          botToken: botToken,
          channelId: channelId,
          title: title,
          caption: caption.isNotEmpty ? caption : null,
          imageUrls: hasPhotos ? _photoList : [],
          videoUrl: hasVideo ? videoUrl : '',
          uploadPhotos: hasPhotos,
          uploadVideo: hasVideo,
          onStatus: (s) {
            if (mounted) setState(() => _status = s);
          },
        );
      } else {
        // 📱 Client-side
        if (hasPhotos) {
          setState(() { _status = 'Uploading photos...'; _progress = 0.1; });
          final photoResult = await TelegramExtractorService.uploadPhotosAlbum(
            botToken: botToken,
            channelId: channelId,
            imageUrls: _photoList,
            caption: hasVideo ? null : (caption.isNotEmpty ? caption : null),
            onStatus: (s) {
              if (mounted) setState(() => _status = s);
            },
          );
          if (photoResult['success'] != true) {
            setState(() { _isBroadcasting = false; _error = photoResult['message']; });
            return;
          }
        }

        if (hasVideo) {
          setState(() { _status = 'Preparing video...'; _progress = 0.3; });
          result = await TelegramExtractorService.uploadNativeVideo(
            botToken: botToken,
            channelId: channelId,
            rawVideoUrl: videoUrl,
            title: title,
            caption: caption.isNotEmpty ? caption : null,
            onProgress: (s, p) {
              if (mounted) setState(() { _status = s; _progress = p; });
            },
          );
        } else {
          result = {'success': true, 'message': 'Photos sent!'};
        }
      }

      if (!mounted) return;
      if (result['success'] == true) {
        setState(() {
          _success = result['message'] ?? 'Broadcast complete!';
          _progress = 1.0;
          _status = '';
        });
      } else {
        setState(() => _error = result['message'] ?? 'Broadcast failed.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Error: $e');
    } finally {
      if (mounted) setState(() => _isBroadcasting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      height: mq.size.height * 0.93,
      decoration: const BoxDecoration(
        color: Color(0xFF0D0F1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C47FF), Color(0xFFE040FB)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.campaign_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Manual Broadcast Studio',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('Paste any link → Send to Telegram',
                          style: TextStyle(color: Colors.white54, fontSize: 11)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white12, height: 20),

          if (_isLoadingSettings)
            const Expanded(child: Center(child: CircularProgressIndicator(color: Color(0xFF6C47FF))))
          else
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Engine Toggle ──
                    _engineToggle(),
                    const SizedBox(height: 16),

                    // ── Video URL ──
                    _sectionLabel('🎬 Video URL', 'Streamtape, Vidara, direct MP4/M3U8'),
                    const SizedBox(height: 6),
                    _urlField(
                      controller: _videoUrlCtrl,
                      hint: 'https://streamtape.com/v/... or https://vidara.tv/...',
                      enabled: !_isBroadcasting,
                      leading: const Icon(Icons.play_circle_outline_rounded,
                          color: Color(0xFF6C47FF), size: 18),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _pill(
                          'Streamtape',
                          const Color(0xFF6C47FF),
                          () => _insertExample('https://streamtape.com/v/EXAMPLE/title.mp4'),
                        ),
                        const SizedBox(width: 6),
                        _pill(
                          'Vidara',
                          const Color(0xFF00BCD4),
                          () => _insertExample('https://vidara.tv/embed/EXAMPLE'),
                        ),
                        const SizedBox(width: 6),
                        _pill(
                          'Direct MP4',
                          const Color(0xFF4CAF50),
                          () => _insertExample('https://cdn.example.com/video.mp4'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // ── Photo URLs ──
                    _sectionLabel('🖼️ Photo URLs', 'One URL per line (optional)'),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF141722),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: TextField(
                        controller: _photoUrlsCtrl,
                        enabled: !_isBroadcasting,
                        maxLines: 4,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: const InputDecoration(
                          hintText: 'https://photo1.jpg\nhttps://photo2.jpg\n...',
                          hintStyle: TextStyle(color: Colors.white24, fontSize: 11),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── Title & Caption ──
                    _sectionLabel('✏️ Title & Caption', ''),
                    const SizedBox(height: 6),
                    _urlField(
                      controller: _titleCtrl,
                      hint: 'e.g. Rasakadali Episode 3',
                      enabled: !_isBroadcasting,
                      leading: const Icon(Icons.title_rounded, color: Colors.amberAccent, size: 18),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF141722),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: TextField(
                        controller: _captionCtrl,
                        enabled: !_isBroadcasting,
                        maxLines: 3,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: const InputDecoration(
                          hintText: 'Optional caption with HTML tags supported...',
                          hintStyle: TextStyle(color: Colors.white24, fontSize: 11),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── Bot Settings ──
                    _sectionLabel('⚙️ Telegram Settings', ''),
                    const SizedBox(height: 6),
                    _urlField(
                      controller: _botTokenCtrl,
                      hint: 'Bot Token (123456:ABC...)',
                      enabled: !_isBroadcasting,
                      leading: const Icon(Icons.key_rounded, color: Colors.cyanAccent, size: 18),
                      obscure: false,
                    ),
                    const SizedBox(height: 8),
                    _urlField(
                      controller: _channelCtrl,
                      hint: 'Channel/Group ID (-100...)',
                      enabled: !_isBroadcasting,
                      leading: const Icon(Icons.send_rounded, color: Colors.cyanAccent, size: 18),
                    ),

                    const SizedBox(height: 14),

                    // ── Send Toggles ──
                    Row(
                      children: [
                        _toggleChip('Send Video', _sendVideo && _videoUrlCtrl.text.isNotEmpty, Colors.purpleAccent,
                            () => setState(() => _sendVideo = !_sendVideo)),
                        const SizedBox(width: 8),
                        _toggleChip('Send Photos', _sendPhotos, Colors.orangeAccent,
                            () => setState(() => _sendPhotos = !_sendPhotos)),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ── Progress / Error / Success ──
                    if (_isBroadcasting) ...[
                      _progressSection(),
                      const SizedBox(height: 12),
                    ],
                    if (_error != null) ...[
                      _errorSection(_error!),
                      const SizedBox(height: 12),
                    ],
                    if (_success != null) ...[
                      _successSection(_success!),
                      const SizedBox(height: 12),
                    ],

                    // ── Broadcast Button ──
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _isBroadcasting ? null : _broadcast,
                        icon: _isBroadcasting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send_rounded, size: 20),
                        label: Text(
                          _isBroadcasting ? 'Broadcasting...' : '🚀  Broadcast Now',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C47FF),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFF3D2E7A),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    SizedBox(height: mq.viewInsets.bottom + 10),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // Helper Widgets
  // ──────────────────────────────────────────────────────────

  Widget _engineToggle() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _useServer
              ? [const Color(0xFF0A1628), const Color(0xFF0D1F3C)]
              : [const Color(0xFF1A0A28), const Color(0xFF2C0D3C)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _useServer ? Colors.cyanAccent.withOpacity(0.3) : Colors.purpleAccent.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _useServer ? Icons.cloud_done_rounded : Icons.phone_android_rounded,
            color: _useServer ? Colors.cyanAccent : Colors.purpleAccent,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _useServer ? '🚀 Server Engine (10Gbps · 0 MB mobile data)' : '📱 Client Engine (uses mobile data)',
                  style: TextStyle(
                    color: _useServer ? Colors.cyanAccent : Colors.purpleAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _useServer
                      ? 'Server downloads & uploads on your behalf. Fastest option.'
                      : 'Your phone downloads then uploads. Max 50 MB per Telegram Bot API.',
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ],
            ),
          ),
          Switch(
            value: _useServer,
            onChanged: _isBroadcasting ? null : (v) => setState(() => _useServer = v),
            activeColor: Colors.cyanAccent,
            inactiveThumbColor: Colors.purpleAccent,
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String title, String sub) {
    return Row(
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        if (sub.isNotEmpty) ...[
          const SizedBox(width: 6),
          Text(sub, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ],
      ],
    );
  }

  Widget _urlField({
    required TextEditingController controller,
    required String hint,
    required bool enabled,
    Widget? leading,
    bool obscure = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141722),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          if (leading != null) Padding(padding: const EdgeInsets.only(left: 12), child: leading),
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              obscureText: obscure,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: Colors.white24, fontSize: 11),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ),
          if (controller.text.isEmpty)
            IconButton(
              icon: const Icon(Icons.paste_rounded, color: Colors.white38, size: 18),
              onPressed: enabled
                  ? () async {
                      final data = await Clipboard.getData(Clipboard.kTextPlain);
                      if (data?.text != null) {
                        controller.text = data!.text!;
                        setState(() {});
                      }
                    }
                  : null,
            ),
        ],
      ),
    );
  }

  Widget _pill(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _toggleChip(String label, bool active, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: _isBroadcasting ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.2) : const Color(0xFF141722),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? color.withOpacity(0.5) : Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(active ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: active ? color : Colors.white38, size: 14),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: active ? color : Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _progressSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141722),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF6C47FF).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ScaleTransition(
                scale: _pulse,
                child: const Icon(Icons.fiber_manual_record_rounded, color: Color(0xFF6C47FF), size: 10),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_status, style: const TextStyle(color: Colors.white70, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _progress > 0 ? _progress : null,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6C47FF)),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorSection(String msg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(msg, style: const TextStyle(color: Colors.redAccent, fontSize: 11))),
        ],
      ),
    );
  }

  Widget _successSection(String msg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.greenAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(msg, style: const TextStyle(color: Colors.greenAccent, fontSize: 11))),
        ],
      ),
    );
  }

  void _insertExample(String url) {
    _videoUrlCtrl.text = url;
    setState(() {});
  }
}
