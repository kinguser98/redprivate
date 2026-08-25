import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/dropmms_service.dart';
import '../services/telegram_extractor_service.dart';

class ExtractorTelegramDialog extends StatefulWidget {
  final String title;
  final String category;
  final String topicUrl;
  final List<String> initialImages;
  final List<DropmmsMediaLink> videoLinks;
  final List<DropmmsMediaLink> downloadLinks;
  final DropmmsMediaLink? defaultSelectedLink;

  const ExtractorTelegramDialog({
    Key? key,
    required this.title,
    required this.category,
    required this.topicUrl,
    required this.initialImages,
    required this.videoLinks,
    required this.downloadLinks,
    this.defaultSelectedLink,
  }) : super(key: key);

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String category,
    required String topicUrl,
    required List<String> initialImages,
    required List<DropmmsMediaLink> videoLinks,
    required List<DropmmsMediaLink> downloadLinks,
    DropmmsMediaLink? defaultSelectedLink,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ExtractorTelegramDialog(
        title: title,
        category: category,
        topicUrl: topicUrl,
        initialImages: initialImages,
        videoLinks: videoLinks,
        downloadLinks: downloadLinks,
        defaultSelectedLink: defaultSelectedLink,
      ),
    );
  }

  @override
  State<ExtractorTelegramDialog> createState() => _ExtractorTelegramDialogState();
}

class _ExtractorTelegramDialogState extends State<ExtractorTelegramDialog> {
  late List<String> _images;
  late TextEditingController _captionCtrl;
  late TextEditingController _channelCtrl;
  late TextEditingController _botTokenCtrl;

  bool _isLoadingSettings = true;
  bool _isBroadcasting = false;
  String _uploadStatus = "";
  double _uploadProgress = 0.0;
  String? _errorMessage;

  bool _uploadPhotos = true;
  bool _uploadVideo = true;
  bool _useServerEngine = false; // Toggle between Server & Client engines
  bool _showSettings = false;
  DropmmsMediaLink? _selectedVideoLink;

  @override
  void initState() {
    super.initState();
    _images = List<String>.from(widget.initialImages);
    _selectedVideoLink = widget.defaultSelectedLink ??
        (widget.videoLinks.isNotEmpty ? widget.videoLinks.first : null);
    _uploadVideo = _selectedVideoLink != null;

    _channelCtrl = TextEditingController();
    _botTokenCtrl = TextEditingController();

    _initCaption();
    _loadSettings();
  }

  void _initCaption() {
    final buffer = StringBuffer();
    buffer.writeln("🔥 <b>${widget.title.trim()}</b>");
    if (widget.category.isNotEmpty) {
      buffer.writeln("📁 <i>#${widget.category.replaceAll(' ', '_')}</i>");
    }
    buffer.writeln("");
    if (_selectedVideoLink != null) {
      buffer.writeln("🎬 <b>Video Stream:</b> ${_selectedVideoLink!.host.toUpperCase()}");
    }
    buffer.writeln("🍿 <i>Enjoy Ad-Free on Red App!</i>");

    _captionCtrl = TextEditingController(text: buffer.toString());
  }

  Future<void> _loadSettings() async {
    final s = await TelegramExtractorService.loadSettings();
    setState(() {
      _botTokenCtrl.text = s['botToken'] ?? '';
      _channelCtrl.text = s['channelId'] ?? '';
      _useServerEngine = s['useServer'] == true;
      _isLoadingSettings = false;
      if (_botTokenCtrl.text.isEmpty || _channelCtrl.text.isEmpty) {
        _showSettings = true;
      }
    });
  }

  Future<void> _saveSettings() async {
    await TelegramExtractorService.saveSettings(
      botToken: _botTokenCtrl.text.trim(),
      channelId: _channelCtrl.text.trim(),
      useServer: _useServerEngine,
    );
  }

  void _removeImageAt(int index) {
    if (index >= 0 && index < _images.length) {
      setState(() {
        _images.removeAt(index);
      });
    }
  }

  void _restoreAllImages() {
    setState(() {
      _images = List<String>.from(widget.initialImages);
    });
  }

  Future<void> _sendBroadcast() async {
    final botToken = _botTokenCtrl.text.trim();
    final channelId = _channelCtrl.text.trim();

    if (botToken.isEmpty || channelId.isEmpty) {
      setState(() {
        _showSettings = true;
        _errorMessage = "Please enter both Telegram Bot Token and Channel ID in settings above.";
      });
      return;
    }

    if (!_uploadPhotos && !_uploadVideo) {
      setState(() {
        _errorMessage = "Please check at least Photos or Video to upload.";
      });
      return;
    }

    await _saveSettings();

    setState(() {
      _isBroadcasting = true;
      _errorMessage = null;
      _uploadStatus = _useServerEngine ? "Connecting to 10Gbps server pipeline..." : "Connecting to Telegram...";
      _uploadProgress = 0.05;
    });

    final cleanCaption = _captionCtrl.text.trim();

    // --- MODE 1: SERVER-SIDE ENGINE (0 MB Phone Data) ---
    if (_useServerEngine) {
      final sRes = await TelegramExtractorService.uploadViaServer(
        botToken: botToken,
        channelId: channelId,
        title: widget.title,
        caption: cleanCaption,
        imageUrls: _images,
        videoUrl: _selectedVideoLink?.url,
        uploadPhotos: _uploadPhotos,
        uploadVideo: _uploadVideo,
        onStatus: (st) => setState(() => _uploadStatus = st),
      );

      if (sRes['success'] != true) {
        setState(() {
          _isBroadcasting = false;
          _errorMessage = sRes['message'] ?? "Server upload failed.";
        });
        return;
      }
    } else {
      // --- MODE 2: CLIENT-SIDE ENGINE (Direct From Phone) ---
      // 1. Upload Photos Album (If enabled)
      if (_uploadPhotos && _images.isNotEmpty) {
        setState(() {
          _uploadStatus = "Downloading & preparing ${_images.length} photos...";
          _uploadProgress = 0.15;
        });

        final photoRes = await TelegramExtractorService.uploadPhotosAlbum(
          botToken: botToken,
          channelId: channelId,
          imageUrls: _images,
          caption: !_uploadVideo ? cleanCaption : null,
          onStatus: (st) => setState(() => _uploadStatus = st),
        );

        if (photoRes['success'] != true) {
          if (!_uploadVideo) {
            setState(() {
              _isBroadcasting = false;
              _errorMessage = "Photos upload failed: ${photoRes['message']}";
            });
            return;
          } else {
            debugPrint("Photos upload warning: ${photoRes['message']}");
          }
        }
      }

      // 2. Upload Native Playable Video (If enabled)
      if (_uploadVideo && _selectedVideoLink != null) {
        setState(() {
          _uploadStatus = "Resolving & streaming video (${_selectedVideoLink!.host.toUpperCase()})...";
          _uploadProgress = 0.35;
        });

        final videoRes = await TelegramExtractorService.uploadNativeVideo(
          botToken: botToken,
          channelId: channelId,
          rawVideoUrl: _selectedVideoLink!.url,
          title: widget.title,
          caption: cleanCaption,
          posterUrl: _images.isNotEmpty ? _images.first : null,
          onProgress: (st, pr) {
            setState(() {
              _uploadStatus = st;
              _uploadProgress = pr;
            });
          },
        );

        if (videoRes['success'] != true) {
          setState(() {
            _isBroadcasting = false;
            _errorMessage = videoRes['message'] ?? "Video upload failed.";
          });
          return;
        }
      }
    }

    setState(() => _isBroadcasting = false);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.cyanAccent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _useServerEngine
                      ? "🚀 Broadcast Sent via Server (0 MB Phone Data Used)!"
                      : "🚀 Successfully Uploaded Directly to Telegram Channel!",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF101624),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _shareViaTelegramApp() {
    final buffer = StringBuffer();
    buffer.writeln("🔥 ${widget.title.trim()}");
    if (widget.category.isNotEmpty) {
      buffer.writeln("📁 #${widget.category.replaceAll(' ', '_')}");
    }
    buffer.writeln("");
    if (_selectedVideoLink != null) {
      buffer.writeln("🎬 Watch / Stream (${_selectedVideoLink!.host.toUpperCase()}):");
      buffer.writeln(_selectedVideoLink!.url);
      buffer.writeln("");
    }
    if (widget.downloadLinks.isNotEmpty) {
      buffer.writeln("⚡ Download Servers:");
      for (final dl in widget.downloadLinks) {
        buffer.writeln("• ${dl.name} (${dl.host}): ${dl.url}");
      }
      buffer.writeln("");
    }
    buffer.writeln("🍿 Enjoy Ad-Free on Red App!");

    final encoded = Uri.encodeComponent(buffer.toString());
    final tgUrl = "tg://msg?text=$encoded";
    final webUrl = "https://t.me/share/url?url=&text=$encoded";

    launchUrl(Uri.parse(tgUrl), mode: LaunchMode.externalApplication).catchError((_) {
      return launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF121622),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Color(0xFF229ED9), width: 1.5)),
      ),
      child: Column(
        children: [
          // 1. Drag Handle & Header
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF229ED9).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.send_rounded, color: Color(0xFF229ED9), size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "✈️ Telegram Extractor Studio",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        "Uploads native playable videos & full photo albums",
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _showSettings ? Icons.close_rounded : Icons.settings_outlined,
                    color: _showSettings ? Colors.redAccent : Colors.white70,
                    size: 20,
                  ),
                  tooltip: "Configure Channel & Bot",
                  onPressed: () => setState(() => _showSettings = !_showSettings),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),

          // 2. Scrollable Body
          Expanded(
            child: _isLoadingSettings
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF229ED9)))
                : ListView(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 16),
                    children: [
                      // Error Banner (If any)
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.6)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: Colors.white, fontSize: 11.5, height: 1.4),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.white54, size: 16),
                                onPressed: () => setState(() => _errorMessage = null),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Engine Selector Toggle (Server vs Client)
                      _buildEngineSelectorCard(),
                      const SizedBox(height: 14),

                      // Config Settings Panel (Collapsible)
                      if (_showSettings) ...[
                        _buildSettingsCard(),
                        const SizedBox(height: 14),
                      ],

                      // Target Channel ID Banner
                      _buildChannelSelectorBanner(),
                      const SizedBox(height: 14),

                      // Upload Modes Selection (Photos Album / Native Video)
                      _buildUploadModesCard(),
                      const SizedBox(height: 14),

                      // Photos & Screenshots Gallery (With ❌ Remove button)
                      if (_uploadPhotos) ...[
                        _buildPhotosSection(),
                        const SizedBox(height: 14),
                      ],

                      // Video Stream Selector (For Native Telegram Video)
                      if (_uploadVideo && widget.videoLinks.isNotEmpty) ...[
                        _buildVideoStreamSelector(),
                        const SizedBox(height: 14),
                      ],

                      // Live Telegram Message Simulator Preview
                      _buildTelegramMessageSimulator(),
                      const SizedBox(height: 14),

                      // Editable Caption Area
                      _buildEditableCaptionBox(),
                    ],
                  ),
          ),

          // 3. Bottom Action Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF141724),
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isBroadcasting) ...[
                  LinearProgressIndicator(
                    value: _uploadProgress > 0 ? _uploadProgress : null,
                    backgroundColor: const Color(0xFF1E2638),
                    color: _useServerEngine ? const Color(0xFF00E676) : const Color(0xFF229ED9),
                    minHeight: 4,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _uploadStatus,
                    style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    // Share via Telegram App Button
                    Expanded(
                      flex: 2,
                      child: OutlinedButton.icon(
                        onPressed: _isBroadcasting ? null : _shareViaTelegramApp,
                        icon: const Icon(Icons.share_rounded, size: 16),
                        label: const Text(
                          "SHARE VIA APP",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF229ED9),
                          side: const BorderSide(color: Color(0xFF229ED9), width: 1.2),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Direct Upload to Channel Button
                    Expanded(
                      flex: 3,
                      child: ElevatedButton.icon(
                        onPressed: _isBroadcasting ? null : _sendBroadcast,
                        icon: _isBroadcasting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              )
                            : Icon(_useServerEngine ? Icons.bolt_rounded : Icons.cloud_upload_rounded, size: 18),
                        label: Text(
                          _isBroadcasting
                              ? "BROADCASTING..."
                              : (_useServerEngine
                                  ? "SERVER UPLOAD (0 MB DATA)"
                                  : (_uploadPhotos && _uploadVideo
                                      ? "UPLOAD PHOTOS + VIDEO"
                                      : (_uploadPhotos ? "UPLOAD PHOTOS" : "UPLOAD VIDEO"))),
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _useServerEngine ? const Color(0xFF00E676) : const Color(0xFF229ED9),
                          foregroundColor: Colors.black,
                          disabledBackgroundColor: Colors.white12,
                          disabledForegroundColor: Colors.white24,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 6,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEngineSelectorCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141926),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _useServerEngine ? const Color(0xFF00E676).withValues(alpha: 0.4) : const Color(0xFF229ED9).withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _useServerEngine ? Icons.cloud_done_rounded : Icons.smartphone_rounded,
                color: _useServerEngine ? const Color(0xFF00E676) : const Color(0xFF229ED9),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                "UPLOAD ENGINE",
                style: TextStyle(
                  color: _useServerEngine ? const Color(0xFF00E676) : const Color(0xFF229ED9),
                  fontWeight: FontWeight.bold,
                  fontSize: 11.5,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Server Engine Button
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _useServerEngine = true);
                    _saveSettings();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    decoration: BoxDecoration(
                      color: _useServerEngine ? const Color(0xFF00E676).withValues(alpha: 0.15) : const Color(0xFF1B2232),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _useServerEngine ? const Color(0xFF00E676) : Colors.white10,
                        width: _useServerEngine ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bolt_rounded, size: 14, color: _useServerEngine ? const Color(0xFF00E676) : Colors.white60),
                            const SizedBox(width: 4),
                            Text(
                              "Server (10Gbps)",
                              style: TextStyle(
                                color: _useServerEngine ? const Color(0xFF00E676) : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          "0 MB Phone Data",
                          style: TextStyle(
                            color: _useServerEngine ? Colors.greenAccent : Colors.white38,
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Client Engine Button
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _useServerEngine = false);
                    _saveSettings();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    decoration: BoxDecoration(
                      color: !_useServerEngine ? const Color(0xFF229ED9).withValues(alpha: 0.15) : const Color(0xFF1B2232),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: !_useServerEngine ? const Color(0xFF229ED9) : Colors.white10,
                        width: !_useServerEngine ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.phone_android_rounded, size: 14, color: !_useServerEngine ? const Color(0xFF229ED9) : Colors.white60),
                            const SizedBox(width: 4),
                            Text(
                              "Client (Device)",
                              style: TextStyle(
                                color: !_useServerEngine ? const Color(0xFF229ED9) : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          "Direct From Phone",
                          style: TextStyle(
                            color: !_useServerEngine ? Colors.cyanAccent : Colors.white38,
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B26),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF229ED9).withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.tune_rounded, color: Color(0xFF229ED9), size: 18),
              SizedBox(width: 8),
              Text(
                "TELEGRAM CHANNEL & BOT SETTINGS",
                style: TextStyle(color: Color(0xFF229ED9), fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _botTokenCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: InputDecoration(
              labelText: "Telegram Bot Token",
              labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
              hintText: "123456789:ABCdefGhIJKlmNoPQRsTUVwxyZ",
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 11),
              filled: true,
              fillColor: const Color(0xFF0F121C),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _channelCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: InputDecoration(
              labelText: "Target Channel ID or @Username",
              labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
              hintText: "-1001234567890 or @MyChannel",
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 11),
              filled: true,
              fillColor: const Color(0xFF0F121C),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: () async {
                await _saveSettings();
                setState(() => _showSettings = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Telegram Settings Saved!"), backgroundColor: Colors.green),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF229ED9),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text("Save Settings", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelSelectorBanner() {
    final chan = _channelCtrl.text.trim();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161B26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          const Icon(Icons.campaign_rounded, color: Color(0xFF229ED9), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("BROADCAST DESTINATION", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                Text(
                  chan.isNotEmpty ? chan : "Not Set (Tap Settings ⚙️)",
                  style: TextStyle(
                    color: chan.isNotEmpty ? Colors.white : Colors.amberAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _showSettings = !_showSettings),
            child: Text(
              _showSettings ? "HIDE" : "EDIT",
              style: const TextStyle(color: Color(0xFF229ED9), fontWeight: FontWeight.bold, fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadModesCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B26),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("UPLOAD CONTENT", style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    "Photos Album (${_images.length})",
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  value: _uploadPhotos,
                  activeColor: const Color(0xFF229ED9),
                  onChanged: (val) => setState(() => _uploadPhotos = val ?? false),
                ),
              ),
              Expanded(
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text(
                    "Native Video File",
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  value: _uploadVideo,
                  activeColor: const Color(0xFF229ED9),
                  onChanged: (val) => setState(() => _uploadVideo = val ?? false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhotosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.photo_library_rounded, color: Colors.cyanAccent, size: 16),
            const SizedBox(width: 8),
            Text(
              "PHOTOS & SCREENSHOTS (${_images.length})",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const Spacer(),
            if (_images.length < widget.initialImages.length)
              TextButton.icon(
                onPressed: _restoreAllImages,
                icon: const Icon(Icons.restore_rounded, size: 14, color: Colors.cyanAccent),
                label: const Text("Restore All", style: TextStyle(color: Colors.cyanAccent, fontSize: 11)),
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _images.length,
            itemBuilder: (ctx, idx) {
              final imgUrl = _images[idx];
              return Container(
                width: 90,
                margin: const EdgeInsets.only(right: 8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CachedNetworkImage(
                        imageUrl: imgUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          color: const Color(0xFF1E2433),
                          child: const Icon(Icons.broken_image, color: Colors.white24),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _removeImageAt(idx),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.black87,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 14),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          "#${idx + 1}",
                          style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVideoStreamSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.video_library_rounded, color: Color(0xFF00E676), size: 16),
            SizedBox(width: 8),
            Text("SELECT VIDEO STREAM TO UPLOAD", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 8),
        ...widget.videoLinks.map((vl) {
          final isSelected = _selectedVideoLink?.url == vl.url;
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF00E676).withValues(alpha: 0.12) : const Color(0xFF161B26),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? const Color(0xFF00E676) : Colors.white12,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: RadioListTile<DropmmsMediaLink>(
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              dense: true,
              value: vl,
              groupValue: _selectedVideoLink,
              activeColor: const Color(0xFF00E676),
              title: Text(
                vl.name,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              subtitle: Text(
                vl.host.toUpperCase(),
                style: const TextStyle(color: Colors.white38, fontSize: 10.5),
              ),
              onChanged: (val) {
                setState(() {
                  _selectedVideoLink = val;
                  _initCaption();
                });
              },
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTelegramMessageSimulator() {
    final chan = _channelCtrl.text.trim();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F141E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF229ED9).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.visibility_rounded, color: Color(0xFF229ED9), size: 16),
              const SizedBox(width: 8),
              const Text("LIVE TELEGRAM PREVIEW", style: TextStyle(color: Color(0xFF229ED9), fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5)),
              const Spacer(),
              Text(
                chan.isNotEmpty ? chan : "@channel",
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_images.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 120,
                width: double.infinity,
                child: CachedNetworkImage(
                  imageUrl: _images.first,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          const SizedBox(height: 10),
          Text(
            _captionCtrl.text.replaceAll(RegExp(r'<[^>]*>'), ''),
            style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableCaptionBox() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.edit_note_rounded, color: Colors.white70, size: 16),
            SizedBox(width: 8),
            Text("EDIT TELEGRAM CAPTION (HTML)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _captionCtrl,
          maxLines: 4,
          style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.4),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF161B26),
            contentPadding: const EdgeInsets.all(12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }
}
