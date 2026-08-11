import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/streamtape_service.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/hls_quality_parser.dart';

class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({
    super.key,
    required this.videoUrl,
    required this.videoTitle,
    this.movieId,
    this.resumeDirectly = false,
    this.contentId,
    this.contentType,
    this.qualities,
    this.initialQuality,
  });

  final String videoUrl;
  final String videoTitle;
  final String? movieId;
  final bool resumeDirectly;
  final int? contentId;
  final int? contentType;
  final Map<String, String>? qualities;
  final String? initialQuality;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _controller;

  bool _ready = false;
  bool _showControls = true;
  bool _playing = false;
  bool _buffering = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isSeeking = false;
  double? _dragValue;
  int _lastSavedMs = 0;
  Timer? _statsTimer;

  // Live Clock
  Timer? _clockTimer;
  String _timeString = '';
  Timer? _telemetryTimer;

  // Pinch Zoom & Pan Offset
  double _videoScale = 1.0;
  double _baseScale = 1.0;
  Offset _videoOffset = Offset.zero;
  Offset _baseOffset = Offset.zero;
  Offset? _dragStartPoint;
  double? _dragStartVolume;
  double? _dragStartBrightness;
  bool _isDraggingHUD = false;

  final List<double?> _aspectRatios = [null, 16 / 9, 21 / 9, 4 / 3];
  int _aspectRatioIndex = 0;

  // Gesture & Control Sliders
  double _brightness = 1.0; // 0.1 to 1.0
  double _volume = 80.0; // 0.0 to 100.0
  String? _hudType; // 'brightness', 'volume', 'seek'
  int? _seekOverlayValue; // +10 or -10
  Timer? _hudTimer;

  // Lock Controls & Playback Speed
  bool _controlsLocked = false;
  Timer? _hideControlsTimer;
  double _playbackSpeed = 1.0;

  // Multi-Quality Stream Support
  Map<String, String>? _qualities;
  String? _activeQuality;
  String _currentVideoUrl = '';

  @override
  void initState() {
    super.initState();
    _currentVideoUrl = widget.videoUrl;
    _qualities = widget.qualities;
    if (_qualities == null || _qualities!.isEmpty) {
      if (widget.videoUrl.contains('.m3u8')) {
        HlsQualityParser.parseQualities(widget.videoUrl).then((hlsQ) {
          if (mounted && hlsQ.isNotEmpty) {
            setState(() {
              _qualities = hlsQ;
              _activeQuality = hlsQ.keys.first;
            });
          }
        });
      }
    }
    _activeQuality = widget.initialQuality ?? (_qualities != null && _qualities!.isNotEmpty ? _qualities!.keys.first : 'HD');

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _updateClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());

    _open();

    _statsTimer = Timer.periodic(const Duration(seconds: 5), (_) => _saveProgress());

    // Setup periodic heartbeat tracking for video player (every 30s)
    _telemetryTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      try {
        final userId = AppSession.user?.id ?? 0;
        if (userId > 0 && widget.contentId != null && widget.contentId! > 0) {
          ApiService.sendHeartbeat(
            userId,
            'player',
            contentId: widget.contentId,
            contentType: widget.contentType ?? 1,
          );
        }
      } catch (_) {}
    });
  }

  void _updateClock() {
    final now = DateTime.now();
    int hour = now.hour;
    final amPm = hour < 12 ? 'AM' : 'PM';
    hour = hour % 12;
    if (hour == 0) hour = 12;
    final h = hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    if (mounted) setState(() => _timeString = '$h:$m $amPm');
  }

  Future<void> _open() async {
    try {
      String playUrl = _currentVideoUrl.isNotEmpty ? _currentVideoUrl : widget.videoUrl;

      // 1. If playUrl is an un-resolved Streamtape web page, resolve it first!
      if (StreamtapeService.isStreamtapeFamily(playUrl) &&
          !playUrl.contains('tapecontent.net') &&
          !playUrl.contains('get_video')) {
        final resolved = await StreamtapeService.getDirectStreamUrl(playUrl);
        if (resolved != null && resolved.isNotEmpty) {
          playUrl = resolved;
        }
      }

      // 2. Remove fragment #video.mp4 because fragments in HTTP URLs break ExoPlayer requests to tapecontent.net
      if (playUrl.contains('#')) {
        playUrl = playUrl.split('#')[0];
      }

      if (!playUrl.contains('stream=1') &&
          (StreamtapeService.isStreamtapeFamily(playUrl) || playUrl.contains('tapecontent'))) {
        playUrl += playUrl.contains('?') ? '&stream=1' : '?stream=1';
      }

      String referer = 'https://streamtape.com/';
      String? origin;
      if (playUrl.contains('ixifile') || playUrl.contains('uncutmasti')) {
        referer = 'https://uncutmasti.com/';
      } else if (playUrl.contains('tnmr.org') || playUrl.contains('luluvdo') || playUrl.contains('lulustream') || playUrl.contains('lulucdn')) {
        referer = 'https://lulucdn.com/';
        origin = 'https://lulucdn.com';
      } else if (playUrl.contains('xhamster') || playUrl.contains('xhvid') || playUrl.contains('xh.video') || playUrl.contains('xhcdn')) {
        referer = 'https://xhamster.com/';
        origin = 'https://xhamster.com';
      }

      final Map<String, String> playHeaders = {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Referer': referer,
        'Accept': '*/*',
        'Connection': 'keep-alive',
        'Accept-Encoding': 'gzip, deflate, br',
      };
      if (origin != null) {
        playHeaders['Origin'] = origin;
      }

      final isLocal = File(playUrl).existsSync() ||
          playUrl.startsWith('/') ||
          playUrl.startsWith('file://');

      if (isLocal) {
        final cleanPath = playUrl.startsWith('file://') ? playUrl.substring(7) : playUrl;
        _controller = VideoPlayerController.file(File(cleanPath));
      } else {
        _controller = VideoPlayerController.networkUrl(
          Uri.parse(playUrl),
          httpHeaders: playHeaders,
        );
      }

      _controller!.addListener(_onControllerUpdated);
      await _controller!.initialize();

      // Check saved progress
      int seekToMs = 0;
      final savedMs = await _getSavedProgress();
      if (savedMs > 10000) {
        if (widget.resumeDirectly) {
          seekToMs = savedMs;
        } else if (mounted) {
          final resume = await _showResumeDialog(savedMs);
          if (resume == true) {
            seekToMs = savedMs;
          } else {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setInt('progress_${widget.movieId}', 0);
          }
        }
      }

      if (seekToMs > 0) {
        await _controller!.seekTo(Duration(milliseconds: seekToMs));
      }

      await _controller!.play();

      if (mounted) {
        setState(() {
          _ready = true;
          _playing = true;
        });
        _armHideControls();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not play stream: $e')),
      );
    }
  }

  void _onControllerUpdated() {
    if (_controller == null || !mounted) return;
    final value = _controller!.value;
    setState(() {
      _position = value.position;
      _duration = value.duration;
      _playing = value.isPlaying;
      _buffering = value.isBuffering;
    });
  }

  void _showQualityDialog() {
    final qMap = _qualities ?? widget.qualities;
    if (qMap == null || qMap.isEmpty) return;
    _armHideControls();

    showDialog(
      context: context,
      builder: (ctx) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  width: 310,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161A26).withOpacity(0.94),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.6),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.hd_rounded, color: Colors.amberAccent, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                "Video Quality",
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: () => Navigator.of(ctx).pop(),
                            child: const Icon(Icons.close_rounded, color: Colors.white60, size: 20),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Divider(color: Colors.white12, height: 1),
                      const SizedBox(height: 8),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: qMap.entries.map((e) {
                              final qLabel = e.key;
                              final qUrl = e.value;
                              final isSelected = qLabel == _activeQuality;

                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 3),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF2E2614) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  border: isSelected ? Border.all(color: Colors.amberAccent, width: 1) : null,
                                ),
                                child: ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                  leading: Icon(
                                    isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                    color: isSelected ? Colors.amberAccent : Colors.white38,
                                    size: 18,
                                  ),
                                  title: Text(
                                    qLabel,
                                    style: TextStyle(
                                      color: isSelected ? Colors.amberAccent : Colors.white,
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    ),
                                  ),
                                  onTap: () async {
                                    Navigator.of(ctx).pop();
                                    if (!isSelected) {
                                      await _switchQuality(qLabel, qUrl);
                                    }
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _switchQuality(String qLabel, String qUrl) async {
    final currentPos = _controller?.value.position ?? Duration.zero;
    setState(() {
      _activeQuality = qLabel;
      _currentVideoUrl = qUrl;
      _buffering = true;
    });

    _controller?.removeListener(_onControllerUpdated);
    await _controller?.dispose();

    String referer = 'https://streamtape.com/';
    String? origin;
    if (qUrl.contains('ixifile') || qUrl.contains('uncutmasti')) {
      referer = 'https://uncutmasti.com/';
    } else if (qUrl.contains('tnmr.org') || qUrl.contains('luluvdo') || qUrl.contains('lulustream') || qUrl.contains('lulucdn')) {
      referer = 'https://lulucdn.com/';
      origin = 'https://lulucdn.com';
    } else if (qUrl.contains('xhamster') || qUrl.contains('xhvid') || qUrl.contains('xh.video') || qUrl.contains('xhcdn')) {
      referer = 'https://xhamster.com/';
      origin = 'https://xhamster.com';
    }

    final Map<String, String> playHeaders = {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Referer': referer,
      'Accept': '*/*',
      'Connection': 'keep-alive',
      'Accept-Encoding': 'gzip, deflate, br',
    };
    if (origin != null) {
      playHeaders['Origin'] = origin;
    }

    _controller = VideoPlayerController.networkUrl(
      Uri.parse(qUrl),
      httpHeaders: playHeaders,
    );

    await _controller!.initialize();
    await _controller!.seekTo(currentPos);
    _controller!.addListener(_onControllerUpdated);
    _controller!.play();

    setState(() {
      _buffering = false;
      _ready = true;
    });
  }

  Future<void> _saveProgress() async {
    if (widget.movieId == null || _controller == null || !_controller!.value.isInitialized) return;
    final posMs = _position.inMilliseconds;
    final durMs = _duration.inMilliseconds;
    if (posMs <= 0 || durMs <= 0 || posMs == _lastSavedMs) return;

    _lastSavedMs = posMs;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('progress_${widget.movieId}', posMs);
      await prefs.setInt('duration_${widget.movieId}', durMs);
    } catch (_) {}
  }

  Future<int> _getSavedProgress() async {
    if (widget.movieId == null) return 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('progress_${widget.movieId}') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<bool?> _showResumeDialog(int savedMs) async {
    final Duration d = Duration(milliseconds: savedMs);
    final String timestamp = _fmt(d);

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  color: Colors.black54,
                  padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'RESUME PLAYBACK?',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'You left off at $timestamp. Resume watching?',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE50914),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('Resume',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white30),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Restart'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _armHideControls() {
    _hideControlsTimer?.cancel();
    if (_controlsLocked) {
      _hideControlsTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _showControls = false);
      });
      return;
    }
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _playing) setState(() => _showControls = false);
    });
  }

  void _revealControls() {
    if (_showControls) {
      setState(() => _showControls = false);
      _hideControlsTimer?.cancel();
    } else {
      setState(() => _showControls = true);
      _armHideControls();
    }
  }

  void _togglePlay() {
    if (_controller == null) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
    _revealControls();
  }

  Future<void> _seekRelative(int seconds) async {
    if (_controller == null) return;
    final target = _position + Duration(seconds: seconds);
    final clamped = target < Duration.zero
        ? Duration.zero
        : (_duration > Duration.zero && target > _duration ? _duration : target);

    setState(() {
      _isSeeking = true;
      _buffering = true;
    });

    await _controller!.seekTo(clamped);

    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) {
      setState(() {
        _isSeeking = false;
        _buffering = _controller!.value.isBuffering;
      });
    }

    _showHud('seek', seconds);
    _revealControls();
  }

  void _showHud(String type, [int? value]) {
    _hudTimer?.cancel();
    setState(() {
      _hudType = type;
      if (type == 'seek' && value != null) _seekOverlayValue = value;
    });
    _hudTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() { _hudType = null; _seekOverlayValue = null; });
    });
  }

  // 2-Finger Pinch to Zoom & Gesture Sliders
  void _handleScaleStart(ScaleStartDetails details) {
    _baseScale = _videoScale;
    _baseOffset = _videoOffset;
    _dragStartPoint = details.localFocalPoint;
    if (details.pointerCount == 1) {
      _isDraggingHUD = true;
      _dragStartVolume = _volume;
      _dragStartBrightness = _brightness;
    } else {
      _isDraggingHUD = false;
    }
  }

  void _handleScaleUpdate(ScaleUpdateDetails details, double screenWidth) {
    if (_controlsLocked) return;

    if (details.pointerCount == 2) {
      setState(() {
        _videoScale = (_baseScale * details.scale).clamp(1.0, 4.0);
        if (_videoScale > 1.0) {
          _videoOffset = _baseOffset + details.focalPointDelta;
        } else {
          _videoOffset = Offset.zero;
        }
      });
      _armHideControls();
    } else if (details.pointerCount == 1 && _isDraggingHUD && _dragStartPoint != null) {
      final deltaY = details.localFocalPoint.dy - _dragStartPoint!.dy;
      final startX = _dragStartPoint!.dx;

      if (startX < screenWidth / 2) {
        setState(() {
          _hudType = 'brightness';
          if (_dragStartBrightness != null) {
            _brightness = (_dragStartBrightness! - deltaY / 150).clamp(0.1, 1.0);
          }
        });
      } else {
        setState(() {
          _hudType = 'volume';
          if (_dragStartVolume != null) {
            _volume = (_dragStartVolume! - deltaY / 2.5).clamp(0.0, 100.0);
            _controller?.setVolume(_volume / 100.0);
          }
        });
      }
    }
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    _isDraggingHUD = false;
    _dragStartVolume = null;
    _dragStartBrightness = null;
    _dragStartPoint = null;
    _hudTimer?.cancel();
    _hudTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() { _hudType = null; _seekOverlayValue = null; });
    });
  }

  void _seekTo(double fraction) {
    if (_duration <= Duration.zero || _controller == null) return;
    final target = Duration(milliseconds: (_duration.inMilliseconds * fraction).toInt());
    _seekToAbsolute(target);
  }

  Future<void> _seekToAbsolute(Duration position) async {
    if (_controller == null) return;
    setState(() { _isSeeking = true; _buffering = true; });
    await _controller!.seekTo(position);
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) {
      setState(() {
        _isSeeking = false;
        _buffering = _controller!.value.isBuffering;
      });
    }
  }

  void _enterPip() async {
    try {
      setState(() => _showControls = false);
      await const MethodChannel('com.red.app/pip').invokeMethod('enterPip');
    } catch (e) {
      debugPrint('PiP Error: $e');
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _statsTimer?.cancel();
    _hudTimer?.cancel();
    _hideControlsTimer?.cancel();
    _telemetryTimer?.cancel();
    _saveProgress();

    // Log play duration event
    try {
      final userId = AppSession.user?.id ?? 0;
      if (userId > 0 && widget.contentId != null && widget.contentId! > 0 && _duration.inSeconds > 0) {
        final pos = _position.inSeconds;
        final dur = _duration.inSeconds;
        final completed = (pos / dur) >= 0.85 ? 1 : 0;
        ApiService.logPlayEvent(
          userId,
          widget.contentId!,
          widget.contentType ?? 1,
          pos,
          completed,
        );
      }
    } catch (_) {}

    _controller?.removeListener(_onControllerUpdated);
    _controller?.dispose();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    super.dispose();
  }

  String _fmt(Duration d) {
    final hours = d.inHours;
    final mins = d.inMinutes.remainder(60);
    final secs = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _revealControls,
        onDoubleTapDown: (details) {
          final dx = details.globalPosition.dx;
          if (dx < size.width / 2) {
            _seekRelative(-10);
          } else {
            _seekRelative(10);
          }
        },
        onScaleStart: _handleScaleStart,
        onScaleUpdate: (d) => _handleScaleUpdate(d, size.width),
        onScaleEnd: _handleScaleEnd,
        child: Stack(
          children: [
            // 1. VIDEO LAYER WITH PINCH ZOOM & PAN GESTURES
            Positioned.fill(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Transform.translate(
                      offset: _videoOffset,
                      child: Transform.scale(
                        scale: _videoScale,
                        child: Center(
                          child: _controller != null && _controller!.value.isInitialized
                              ? (_aspectRatios[_aspectRatioIndex] != null
                                  ? AspectRatio(
                                      aspectRatio: _aspectRatios[_aspectRatioIndex]!,
                                      child: VideoPlayer(_controller!),
                                    )
                                  : AspectRatio(
                                      aspectRatio: _controller!.value.aspectRatio > 0
                                          ? _controller!.value.aspectRatio
                                          : 16 / 9,
                                      child: VideoPlayer(_controller!),
                                    ))
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),

                  // Brightness Dimmer Overlay
                  if (_brightness < 1.0)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          color: Colors.black.withOpacity(1.0 - _brightness),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // 2. GESTURE HUD OVERLAY (Volume, Brightness, Double-tap Seek)
            if (_hudType != null) _buildHudOverlay(),

            // 3. MAIN CONTROLS OVERLAY (WITH BRIGHTNESS/VOLUME SLIDERS & FAR TOP RIGHT BUTTONS)
            if (_showControls) _buildControlsLayout(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHudOverlay() {
    IconData icon;
    String label;
    double progress = 0.0;

    if (_hudType == 'seek') {
      final isForward = (_seekOverlayValue ?? 0) > 0;
      icon = isForward ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded;
      label = isForward ? '+ 10s' : '- 10s';
    } else if (_hudType == 'volume') {
      icon = _volume == 0
          ? Icons.volume_mute_rounded
          : (_volume < 50 ? Icons.volume_down_rounded : Icons.volume_up_rounded);
      label = '${_volume.round()}%';
      progress = _volume / 100.0;
    } else if (_hudType == 'brightness') {
      icon = Icons.brightness_6_rounded;
      label = '${(_brightness * 100).round()}%';
      progress = _brightness;
    } else {
      return const SizedBox.shrink();
    }

    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: Colors.black45,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 48),
                const SizedBox(height: 10),
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                if (_hudType != 'seek') ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: 100,
                    height: 4,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white24,
                        color: const Color(0xFFE50914),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBarIcon(Widget child, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlsLayout(BuildContext context) {
    final currentPos = _dragValue != null
        ? Duration(milliseconds: (_duration.inMilliseconds * _dragValue!).toInt())
        : _position;

    return Positioned.fill(
      child: Stack(
        children: [
          // Background Gradient Overlay
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black87,
                    Colors.transparent,
                    Colors.black87,
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          // 1. TOP HEADER BAR (BACK BUTTON, TITLE, LIVE CLOCK -> SPACER -> PIP, FIT ADJUST, SPEED, LOCK)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    // Back & Title Pill
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.of(context).pop(),
                              child: const Icon(Icons.arrow_back_rounded,
                                  color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                widget.videoTitle,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Live Clock Pill
                    if (_timeString.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.access_time_rounded,
                                color: Colors.white70, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              _timeString,
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // SPACER TO ALIGN ALL ACTION BUTTONS TO THE FAR TOP RIGHT!
                    const Spacer(),

                    // Top Right Action Buttons: PiP, Fit Adjust, Speed, Lock
                    if (!_controlsLocked) ...[
                      // PiP Button
                      _buildTopBarIcon(
                        const Icon(Icons.picture_in_picture_alt_rounded,
                            color: Colors.white, size: 18),
                        _enterPip,
                      ),

                      // Fit Adjust (Aspect Ratio Toggle) Button
                      _buildTopBarIcon(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.aspect_ratio_rounded,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 4),
                            Text(
                              _aspectRatioIndex == 0
                                  ? 'FIT'
                                  : (_aspectRatioIndex == 1
                                      ? '16:9'
                                      : (_aspectRatioIndex == 2 ? '21:9' : '4:3')),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        () {
                          setState(() {
                            _aspectRatioIndex =
                                (_aspectRatioIndex + 1) % _aspectRatios.length;
                          });
                        },
                      ),

                      // Quality Selector Button
                      if (_qualities != null && _qualities!.isNotEmpty)
                        _buildTopBarIcon(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.hd_rounded, color: Colors.amberAccent, size: 18),
                              const SizedBox(width: 4),
                              Text(
                                _activeQuality ?? '720p',
                                style: const TextStyle(
                                  color: Colors.amberAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          _showQualityDialog,
                        ),

                      // Speed Toggle Button
                      _buildTopBarIcon(
                        Text(
                          '${_playbackSpeed}x',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                        _showSpeedDialog,
                      ),
                    ],

                    // Lock Screen Button
                    _buildTopBarIcon(
                      Icon(
                        _controlsLocked
                            ? Icons.lock_rounded
                            : Icons.lock_open_rounded,
                        color: _controlsLocked ? Colors.redAccent : Colors.white,
                        size: 20,
                      ),
                      () {
                        setState(() {
                          _controlsLocked = !_controlsLocked;
                        });
                        _armHideControls();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 2. LEFT BRIGHTNESS SLIDER
          if (!_controlsLocked)
            Positioned(
              left: 20,
              top: 90,
              bottom: 90,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.brightness_6_rounded,
                          color: Colors.white70, size: 18),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 120,
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 4,
                              thumbShape:
                                  const RoundSliderThumbShape(enabledThumbRadius: 6),
                              overlayShape:
                                  const RoundSliderOverlayShape(overlayRadius: 12),
                              activeTrackColor: const Color(0xFFE50914),
                              inactiveTrackColor: Colors.white24,
                              thumbColor: Colors.white,
                            ),
                            child: Slider(
                              value: _brightness,
                              min: 0.1,
                              max: 1.0,
                              onChanged: (val) {
                                setState(() {
                                  _brightness = val;
                                });
                                _armHideControls();
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 3. RIGHT VOLUME SLIDER
          if (!_controlsLocked)
            Positioned(
              right: 20,
              top: 90,
              bottom: 90,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _volume == 0
                            ? Icons.volume_mute_rounded
                            : (_volume < 50
                                ? Icons.volume_down_rounded
                                : Icons.volume_up_rounded),
                        color: Colors.white70,
                        size: 18,
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 120,
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 4,
                              thumbShape:
                                  const RoundSliderThumbShape(enabledThumbRadius: 6),
                              overlayShape:
                                  const RoundSliderOverlayShape(overlayRadius: 12),
                              activeTrackColor: const Color(0xFFE50914),
                              inactiveTrackColor: Colors.white24,
                              thumbColor: Colors.white,
                            ),
                            child: Slider(
                              value: _volume,
                              min: 0.0,
                              max: 100.0,
                              onChanged: (val) {
                                setState(() {
                                  _volume = val;
                                  _controller?.setVolume(_volume / 100.0);
                                });
                                _armHideControls();
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 4. CENTER PLAY / REWIND / FORWARD CONTROLS WITH FRONT OVERLAY BUFFERING SPINNER
          if (!_controlsLocked)
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Rewind 10s
                  IconButton(
                    iconSize: 38,
                    icon: const Icon(Icons.replay_10_rounded, color: Colors.white),
                    onPressed: () => _seekRelative(-10),
                  ),
                  const SizedBox(width: 36),

                  // Center Stack: Play/Pause Glass Circle & FRONT OVERLAY BUFFERING SPINNER
                  SizedBox(
                    width: 76,
                    height: 76,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Play / Pause Circle
                        GestureDetector(
                          onTap: _togglePlay,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE50914).withOpacity(0.9),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFE50914).withOpacity(0.4),
                                  blurRadius: 18,
                                  spreadRadius: 2,
                                )
                              ],
                            ),
                            child: Icon(
                              _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),

                        // Large Buffering Spinner IN FRONT OF Play/Pause Button
                        if (_buffering || !_ready)
                          const Positioned.fill(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 4.5,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 36),

                  // Forward 10s
                  IconButton(
                    iconSize: 38,
                    icon: const Icon(Icons.forward_10_rounded, color: Colors.white),
                    onPressed: () => _seekRelative(10),
                  ),
                ],
              ),
            ),

          // 5. BOTTOM SLIDER & TIMESTAMP BAR
          if (!_controlsLocked)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Timestamp Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _fmt(currentPos),
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _fmt(_duration),
                            style: GoogleFonts.outfit(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Progress Slider
                      SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 4,
                          thumbShape:
                              const RoundSliderThumbShape(enabledThumbRadius: 7),
                          overlayShape:
                              const RoundSliderOverlayShape(overlayRadius: 14),
                          activeTrackColor: const Color(0xFFE50914),
                          inactiveTrackColor: Colors.white24,
                          thumbColor: const Color(0xFFE50914),
                        ),
                        child: Slider(
                          value: _duration.inMilliseconds > 0
                              ? (_dragValue ??
                                  (_position.inMilliseconds /
                                          _duration.inMilliseconds)
                                      .clamp(0.0, 1.0))
                              : 0.0,
                          onChanged: (val) {
                            setState(() {
                              _dragValue = val;
                            });
                          },
                          onChangeEnd: (val) {
                            _seekTo(val);
                            setState(() {
                              _dragValue = null;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showSpeedDialog() {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A2132),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Playback Speed',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: speeds.map((speed) {
              final isSelected = _playbackSpeed == speed;
              return ListTile(
                title: Text(
                  '${speed}x',
                  style: TextStyle(
                    color: isSelected ? const Color(0xFFE50914) : Colors.white,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_rounded, color: Color(0xFFE50914))
                    : null,
                onTap: () {
                  setState(() {
                    _playbackSpeed = speed;
                    _controller?.setPlaybackSpeed(speed);
                  });
                  Navigator.of(ctx).pop();
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
