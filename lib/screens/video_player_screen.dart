import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/dns_proxy.dart';
import '../themes/theme_manager.dart';
import '../widgets/gradient_progress.dart';

class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({
    super.key,
    required this.videoUrl,
    required this.videoTitle,
    this.movieId,
    this.resumeDirectly = false,
  });

  final String videoUrl;
  final String videoTitle;
  final String? movieId;
  final bool resumeDirectly;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final Player _player;
  late final VideoController _controller;

  bool _ready = false;
  bool _showControls = true;
  bool _playing = false;
  bool _buffering = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isSeeking = false;
  double? _dragValue;

  // Clock
  Timer? _clockTimer;
  String _timeString = '';

  // Zoom & Pan
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

  // Gesture HUD
  double _brightness = 1.0;
  double _volume = 80.0;
  String? _hudType;
  int? _seekOverlayValue;
  Timer? _hudTimer;

  // Controls
  bool _controlsLocked = false;
  Timer? _hideControlsTimer;

  double _playbackSpeed = 1.0;
  bool _isFavorite = false;

  Timer? _statsTimer;
  int _lastSavedMs = 0;

  @override
  void initState() {
    super.initState();
    ProxyStats.reset();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _player = Player();
    _controller = VideoController(_player);
    _bindStreams();
    _open();

    _updateClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());

    // Auto-save progress every 10 seconds
    _statsTimer = Timer.periodic(const Duration(seconds: 10), (_) => _saveProgress());
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

  void _bindStreams() {
    _player.stream.playing.listen((v) {
      if (mounted) setState(() => _playing = v);
    });
    _player.stream.buffering.listen((v) {
      if (mounted) setState(() => _buffering = v);
    });
    _player.stream.position.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.stream.duration.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.stream.error.listen((e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Playback Error: $e'),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 8),
        ),
      );
    });
    _player.stream.completed.listen((done) {
      if (done && widget.movieId != null) {
        _saveProgress();
      }
    });
  }

  Future<void> _saveProgress() async {
    if (widget.movieId == null || _duration <= Duration.zero) return;
    final ms = _position.inMilliseconds;
    if (ms == _lastSavedMs) return;
    _lastSavedMs = ms;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('progress_${widget.movieId}', ms);
      await prefs.setInt('duration_${widget.movieId}', _duration.inMilliseconds);
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

  Future<void> _open() async {
    try {
      // Check saved progress
      int seekToMs = 0;
      final savedMs = await _getSavedProgress();
      if (savedMs > 10000) {
        if (widget.resumeDirectly) {
          seekToMs = savedMs;
        } else {
          final resume = await _showResumeDialog(savedMs);
          if (resume == true) {
            seekToMs = savedMs;
          } else {
            // Clear saved progress
            final prefs = await SharedPreferences.getInstance();
            await prefs.setInt('progress_${widget.movieId}', 0);
          }
        }
      }

      final Map<String, String> playHeaders = {};
      final isLocalStream = widget.videoUrl.contains('127.0.0.1') ||
          widget.videoUrl.contains('localhost') ||
          widget.videoUrl.contains('/f/');

      if (!isLocalStream && widget.videoUrl.startsWith('http')) {
        String referer = '';
        if (widget.videoUrl.contains('.m3u8') || widget.videoUrl.contains('/hls/')) {
          referer = 'https://streamimdb.ru/';
        } else if (widget.videoUrl.contains('streamtape') ||
            widget.videoUrl.contains('tapecontent') ||
            widget.videoUrl.contains('advtpe') ||
            widget.videoUrl.contains('tapepops') ||
            widget.videoUrl.contains('tpead') ||
            widget.videoUrl.contains('get_video')) {
          referer = 'https://streamtape.com/';
        }

        playHeaders.addAll({
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          if (referer.isNotEmpty) 'Referer': referer,
        });
      }

      if (_player.platform is NativePlayer) {
        final np = _player.platform as NativePlayer;

        await np.setProperty('tls-verify', 'no');
        if (!Platform.isIOS) {
          await np.setProperty('dns-lookup-family', 'ipv4');
        }

        if (!isLocalStream) {
          final userAgent = playHeaders['User-Agent'];
          if (userAgent != null) await np.setProperty('user-agent', userAgent);
          final referer = playHeaders['Referer'];
          if (referer != null) await np.setProperty('referrer', referer);
        }

        // Hardware decoding
        if (Platform.isAndroid) {
          await np.setProperty('hwdec', 'auto');
        } else if (Platform.isIOS || Platform.isMacOS) {
          await np.setProperty('hwdec', 'videotoolbox');
        } else {
          await np.setProperty('hwdec', 'auto');
        }

        if (isLocalStream) {
          await np.setProperty('network-timeout', '60');
          await np.setProperty('demuxer-max-bytes', '32MiB');
          await np.setProperty('demuxer-max-back-bytes', '8MiB');
          await np.setProperty('cache', 'yes');
        } else {
          await np.setProperty('network-timeout', '30');
          await np.setProperty('cache', 'yes');
          await np.setProperty('cache-on-disk', 'no');
          await np.setProperty('demuxer-max-bytes', '67108864');
          await np.setProperty('demuxer-max-back-bytes', '16777216');
          await np.setProperty('demuxer-readahead-secs', '15');
          await np.setProperty('cache-secs', '15');
          await np.setProperty('cache-pause-wait', '0');
          await np.setProperty('stream-live', 'no');
          await np.setProperty('demuxer-lavf-o', 'http_persistent=0');
        }

        await np.setProperty('force-seekable', 'yes');
        await np.setProperty('demuxer-lavf-buffersize', '1048576');
        if (Platform.isAndroid) {
          await np.setProperty('ao', 'audiotrack,opensles,');
        } else if (Platform.isIOS) {
          await np.setProperty('ao', 'audiounit,');
        }
      }

      String playUrl = widget.videoUrl;
      final lowerUrl = playUrl.toLowerCase();
      if (!lowerUrl.contains('.mp4') &&
          !lowerUrl.contains('.mkv') &&
          !lowerUrl.contains('.m3u8') &&
          !lowerUrl.contains('.webm') &&
          !lowerUrl.contains('.ts') &&
          !lowerUrl.contains('.mov')) {
        playUrl = '$playUrl#video.mp4';
      }

      await _player.open(Media(playUrl), play: true);

      if (seekToMs > 0) {
        _player.stream.duration.firstWhere((d) => d > Duration.zero).timeout(
          const Duration(seconds: 8),
          onTimeout: () => Duration.zero,
        ).then((d) async {
          if (d > Duration.zero && mounted) {
            await Future<void>.delayed(const Duration(milliseconds: 300));
            await _player.seek(Duration(milliseconds: seekToMs));
          }
        });
      }

      if (mounted) setState(() => _ready = true);
      _armHideControls();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not play stream: $e')),
      );
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
                        'You left off at $timestamp. Resume?',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
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
    _player.playOrPause();
    _revealControls();
  }

  Future<void> _seekRelative(int seconds) async {
    final target = _position + Duration(seconds: seconds);
    final clamped = target < Duration.zero
        ? Duration.zero
        : (_duration > Duration.zero && target > _duration ? _duration : target);

    setState(() {
      _isSeeking = true;
      _buffering = true;
    });

    await _player.seek(clamped);

    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() {
        _isSeeking = false;
        _buffering = _player.state.buffering;
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
      _revealControls();
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
            _player.setVolume(_volume);
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
    if (_duration <= Duration.zero) return;
    final target = Duration(milliseconds: (_duration.inMilliseconds * fraction).toInt());
    _seekToAbsolute(target);
  }

  Future<void> _seekToAbsolute(Duration position) async {
    setState(() { _isSeeking = true; _buffering = true; });
    await _player.seek(position);
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() {
        _isSeeking = false;
        _buffering = _player.state.buffering;
      });
    }
    _revealControls();
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  void dispose() {
    _saveProgress();
    _hideControlsTimer?.cancel();
    _hudTimer?.cancel();
    _clockTimer?.cancel();
    _statsTimer?.cancel();
    _player.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (!_ready) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: GradientCircularProgressIndicator(
            size: 80.0,
            colors: [AppColors.accentBright.withOpacity(0.05), AppColors.accentBright],
            strokeWidth: 4.0,
          ),
        ),
      );
    }

    final selectedAspectRatio = _aspectRatios[_aspectRatioIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Video
          Center(
            child: Transform.translate(
              offset: _videoOffset,
              child: Transform.scale(
                scale: _videoScale,
                child: AspectRatio(
                  aspectRatio: selectedAspectRatio ?? 16 / 9,
                  child: Video(
                    controller: _controller,
                    controls: NoVideoControls,
                    subtitleViewConfiguration:
                        const SubtitleViewConfiguration(visible: false),
                  ),
                ),
              ),
            ),
          ),

          // 2. Brightness scrim
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: Colors.black.withOpacity((1.0 - _brightness).clamp(0.0, 0.85)),
              ),
            ),
          ),

          // 3. Gesture layer
          Positioned.fill(
            child: GestureDetector(
              onScaleStart: _handleScaleStart,
              onScaleUpdate: (details) => _handleScaleUpdate(details, screenWidth),
              onScaleEnd: _handleScaleEnd,
              onTap: _revealControls,
              onDoubleTapDown: (details) {
                if (_controlsLocked) return;
                final x = details.localPosition.dx;
                if (x < screenWidth / 2) {
                  _seekRelative(-5);
                } else {
                  _seekRelative(5);
                }
              },
              behavior: HitTestBehavior.opaque,
            ),
          ),

          // 4. Buffering spinner (when controls hidden)
          if ((_buffering || _isSeeking) && !_showControls)
            Center(
              child: GradientCircularProgressIndicator(
                size: 80.0,
                colors: [AppColors.accentBright.withOpacity(0.05), AppColors.accentBright],
                strokeWidth: 4.0,
              ),
            ),

          // 5. HUD overlays
          if (_hudType != null) _buildHudOverlay(),

          // 6. Controls
          if (_showControls) _buildControlsLayout(),

          // 7. Side vertical sliders
          if (_showControls && !_controlsLocked) ...[
            Positioned(
              left: 48,
              top: 0,
              bottom: 0,
              child: Center(
                child: SizedBox(
                  width: 32,
                  height: 180,
                  child: _buildVerticalSlider(
                    value: _brightness,
                    icon: Icons.light_mode_rounded,
                    onChanged: (v) => setState(() => _brightness = v.clamp(0.1, 1.0)),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 48,
              top: 0,
              bottom: 0,
              child: Center(
                child: SizedBox(
                  width: 32,
                  height: 180,
                  child: _buildVerticalSlider(
                    value: _volume / 100.0,
                    icon: _volume == 0 ? Icons.volume_mute_rounded : Icons.volume_up_rounded,
                    onChanged: (v) {
                      setState(() { _volume = v * 100.0; });
                      _player.setVolume(_volume);
                    },
                  ),
                ),
              ),
            ),
          ],
        ],
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
      label = isForward ? '+ 5' : '- 5';
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
                        color: AppColors.accentBright,
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

  Widget _buildControlsLayout() {
    final theme = ThemeManager.currentTheme;

    return Positioned.fill(
      child: Stack(
        children: [
          // Main HUD: Top + Center + Bottom
          Column(
            children: [
              // TOP BAR
              Container(
                height: 80,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black54, Colors.transparent],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left: Back + Title
                    Flexible(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          color: Colors.black45,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () => Navigator.of(context).pop(),
                                child: const Icon(Icons.arrow_back_rounded,
                                    color: Colors.white, size: 22),
                              ),
                              const SizedBox(width: 14),
                              Flexible(
                                child: Text(
                                  widget.videoTitle,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Right: Data usage + actions
                    Row(
                      children: [
                        // Live data usage widget
                        ValueListenableBuilder<double>(
                          valueListenable: ProxyStats.speedNotifier,
                          builder: (context, speed, _) {
                            return ValueListenableBuilder<int>(
                              valueListenable: ProxyStats.totalDataNotifier,
                              builder: (context, totalBytes, _) {
                                final speedText = speed <= 0
                                    ? '0 KB/s'
                                    : (speed < 1024 * 1024
                                        ? '${(speed / 1024).toStringAsFixed(1)} KB/s'
                                        : '${(speed / (1024 * 1024)).toStringAsFixed(2)} MB/s');

                                final dataText = totalBytes < 1024 * 1024
                                    ? '${(totalBytes / 1024).toStringAsFixed(1)} KB'
                                    : (totalBytes < 1024 * 1024 * 1024
                                        ? '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB'
                                        : '${(totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB');

                                return Container(
                                  margin: const EdgeInsets.only(right: 12),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black38,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.flash_on_rounded,
                                          color: Colors.amber, size: 10),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$speedText | $dataText',
                                        style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),

                        // PiP button
                        _topBarIcon(
                          const Icon(Icons.picture_in_picture_alt_rounded,
                              color: Colors.white, size: 20),
                          () async {
                            setState(() => _showControls = false);
                            try {
                              await const MethodChannel('com.red.app/pip')
                                  .invokeMethod('enterPip');
                            } catch (e) {
                              debugPrint('PiP error: $e');
                            }
                          },
                        ),

                        // Subtitles
                        _topBarIcon(
                          const Icon(Icons.subtitles_rounded,
                              color: Colors.white, size: 20),
                          () => _showSettingsSheet(initialPane: 3),
                        ),

                        // Settings (quality, audio, aspect)
                        _topBarIcon(
                          const Icon(Icons.tune_rounded,
                              color: Colors.white, size: 20),
                          () => _showSettingsSheet(initialPane: 0),
                        ),

                        // Speed
                        _topBarIcon(
                          Text(
                            '${_playbackSpeed == _playbackSpeed.roundToDouble() ? _playbackSpeed.toInt() : _playbackSpeed}x',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                          () {
                            final speeds = [1.0, 1.25, 1.5, 1.75, 2.0];
                            final next =
                                speeds[(speeds.indexOf(_playbackSpeed) + 1) % speeds.length];
                            setState(() => _playbackSpeed = next);
                            _player.setRate(next);
                          },
                        ),

                        // Lock
                        _topBarIcon(
                          Icon(
                            _controlsLocked
                                ? Icons.lock_rounded
                                : Icons.lock_open_rounded,
                            color: _controlsLocked ? theme.accentBright : Colors.white,
                            size: 20,
                          ),
                          () {
                            setState(() => _controlsLocked = !_controlsLocked);
                            _revealControls();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // CENTER controls
              if (!_controlsLocked)
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.fast_rewind_rounded,
                            color: Colors.white, size: 56),
                        onPressed: () => _seekRelative(-5),
                      ),
                      const SizedBox(width: 60),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          if (_buffering || _isSeeking)
                            GradientCircularProgressIndicator(
                              size: 80.0,
                              colors: [
                                theme.accentBright.withOpacity(0.05),
                                theme.accentBright,
                              ],
                              strokeWidth: 4.0,
                            ),
                          IconButton(
                            icon: Icon(
                              _playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 64,
                            ),
                            onPressed: _togglePlay,
                          ),
                        ],
                      ),
                      const SizedBox(width: 60),
                      IconButton(
                        icon: const Icon(Icons.fast_forward_rounded,
                            color: Colors.white, size: 56),
                        onPressed: () => _seekRelative(5),
                      ),
                    ],
                  ),
                )
              else
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        color: Colors.black45,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_outline_rounded,
                                color: theme.accentBright, size: 18),
                            const SizedBox(width: 8),
                            const Text(
                              'Controls Locked. Tap lock icon to unlock.',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              const Spacer(),

              // BOTTOM BAR
              if (!_controlsLocked)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Seek bar
                      Row(
                        children: [
                          Text(
                            _fmt(_dragValue != null && _duration > Duration.zero
                                ? Duration(
                                    milliseconds:
                                        (_duration.inMilliseconds * _dragValue!).toInt())
                                : _position),
                            style: GoogleFonts.outfit(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 2.0,
                                thumbShape:
                                    const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                                activeTrackColor: Colors.white,
                                inactiveTrackColor: Colors.white24,
                                thumbColor: Colors.white,
                                overlayColor: Colors.white.withOpacity(0.15),
                                overlayShape:
                                    const RoundSliderOverlayShape(overlayRadius: 12.0),
                              ),
                              child: Slider(
                                value: _dragValue ??
                                    (_duration > Duration.zero
                                        ? (_position.inMilliseconds /
                                                _duration.inMilliseconds)
                                            .clamp(0.0, 1.0)
                                        : 0.0),
                                onChanged: (fraction) {
                                  setState(() => _dragValue = fraction);
                                },
                                onChangeEnd: (fraction) {
                                  setState(() => _dragValue = null);
                                  _seekTo(fraction);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _fmt(_duration),
                            style: GoogleFonts.outfit(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Bottom actions row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Speed button
                          _bottomAction(
                            icon: Icons.play_circle_outline_rounded,
                            label:
                                'Speed ${_playbackSpeed == 1.0 ? '1' : _playbackSpeed}x',
                            onTap: () {
                              final speeds = [1.0, 1.25, 1.5, 1.75, 2.0];
                              final next = speeds[
                                  (speeds.indexOf(_playbackSpeed) + 1) % speeds.length];
                              setState(() => _playbackSpeed = next);
                              _player.setRate(next);
                            },
                          ),

                          // Clock
                          Text(
                            _timeString,
                            style: GoogleFonts.outfit(
                              color: Colors.white54,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          // Favorite / Rate
                          _bottomAction(
                            icon: _isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            label: 'Rate',
                            onTap: () => setState(() => _isFavorite = !_isFavorite),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _topBarIcon(Widget child, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(left: 10),
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

  Widget _bottomAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: Colors.white.withOpacity(0.8),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerticalSlider({
    required double value,
    required IconData icon,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(height: 10),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final height = constraints.maxHeight;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (details) {
                  final localY = details.localPosition.dy;
                  onChanged((1.0 - (localY / height)).clamp(0.0, 1.0));
                },
                onTapDown: (details) {
                  final localY = details.localPosition.dy;
                  onChanged((1.0 - (localY / height)).clamp(0.0, 1.0));
                },
                child: Center(
                  child: Container(
                    width: 5,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        FractionallySizedBox(
                          heightFactor: value.clamp(0.0, 1.0),
                          child: Container(
                            width: 5,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(2.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showSettingsSheet({int initialPane = 0}) {
    _revealControls();
    showDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) {
        return _SettingsPopover(
          player: _player,
          aspectRatios: _aspectRatios,
          initialAspectRatioIndex: _aspectRatioIndex,
          initialPane: initialPane,
          onAspectRatioChanged: (index) {
            setState(() => _aspectRatioIndex = index);
          },
          getAspectRatioName: _getAspectRatioName,
        );
      },
    );
  }

  String _getAspectRatioName(int index) {
    const names = ['Auto', '16:9', '21:9', '4:3'];
    return index < names.length ? names[index] : 'Auto';
  }
}

// ---------------------------------------------------------------------------
// Settings Popover — 4 panes: Main, Aspect Ratio, Audio, Subtitles
// ---------------------------------------------------------------------------
class _SettingsPopover extends StatefulWidget {
  final Player player;
  final List<double?> aspectRatios;
  final int initialAspectRatioIndex;
  final int initialPane;
  final Function(int) onAspectRatioChanged;
  final String Function(int) getAspectRatioName;

  const _SettingsPopover({
    required this.player,
    required this.aspectRatios,
    required this.initialAspectRatioIndex,
    this.initialPane = 0,
    required this.onAspectRatioChanged,
    required this.getAspectRatioName,
  });

  @override
  State<_SettingsPopover> createState() => _SettingsPopoverState();
}

class _SettingsPopoverState extends State<_SettingsPopover> {
  late int _currentPane;
  late int _aspectRatioIndex;
  double _audioDelay = 0.0;
  double _subtitleDelay = 0.0;

  @override
  void initState() {
    super.initState();
    _currentPane = widget.initialPane;
    _aspectRatioIndex = widget.initialAspectRatioIndex;
  }

  @override
  Widget build(BuildContext context) {
    String title;
    Widget body;

    switch (_currentPane) {
      case 1:
        title = 'Aspect Ratio';
        body = _buildAspectRatioMenu();
        break;
      case 2:
        title = 'Audio';
        body = _buildAudioMenu();
        break;
      case 3:
        title = 'Subtitles';
        body = _buildSubtitleMenu();
        break;
      case 4:
        title = 'Quality';
        body = _buildQualityMenu();
        break;
      default:
        title = 'Settings';
        body = _buildMainMenu();
    }

    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 90, right: 24),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 260,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12, width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            if (_currentPane != 0)
                              GestureDetector(
                                onTap: () => setState(() => _currentPane = 0),
                                child: const Icon(Icons.arrow_back_ios_new_rounded,
                                    color: Colors.white, size: 16),
                              ),
                            if (_currentPane != 0) const SizedBox(width: 8),
                            Text(
                              title.toUpperCase(),
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(color: Colors.white10, height: 1),
                      Flexible(
                        child: SingleChildScrollView(child: body),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainMenu() {
    final currentAudio = widget.player.state.track.audio;
    final currentSub = widget.player.state.track.subtitle;
    final currentVideo = widget.player.state.track.video;

    String audioName = currentAudio.title ?? currentAudio.language ?? 'Track ${currentAudio.id}';
    if (currentAudio.id == 'auto') audioName = 'Auto';
    if (currentAudio.id == 'no') audioName = 'Off';

    String subName = currentSub.title ?? currentSub.language ?? 'Track ${currentSub.id}';
    if (currentSub.id == 'auto') subName = 'Auto';
    if (currentSub.id == 'no') subName = 'Off';

    String videoName = currentVideo.title ?? '';
    if (videoName.isEmpty) {
      videoName = currentVideo.h != null ? '${currentVideo.h}p' : 'Track ${currentVideo.id}';
    }
    if (currentVideo.id == 'auto') videoName = 'Auto';
    if (currentVideo.id == 'no') videoName = 'Off';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _menuTile(Icons.aspect_ratio_rounded, 'Aspect Ratio',
            widget.getAspectRatioName(_aspectRatioIndex), () => setState(() => _currentPane = 1)),
        _menuTile(Icons.video_settings_rounded, 'Quality', videoName,
            () => setState(() => _currentPane = 4)),
        _menuTile(Icons.audiotrack_rounded, 'Audio Track', audioName,
            () => setState(() => _currentPane = 2)),
        _menuTile(Icons.subtitles_rounded, 'Subtitles', subName,
            () => setState(() => _currentPane = 3)),
      ],
    );
  }

  Widget _menuTile(IconData icon, String label, String value, VoidCallback onTap) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: Icon(icon, color: Colors.white70, size: 18),
      title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value.toUpperCase(),
              style: TextStyle(
                  color: AppColors.accentBright,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, color: Colors.white30, size: 16),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _buildAspectRatioMenu() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(widget.aspectRatios.length, (index) {
        final isSelected = index == _aspectRatioIndex;
        final name = widget.getAspectRatioName(index);
        return ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          title: Text(
            name.toUpperCase(),
            style: TextStyle(
              color: isSelected ? AppColors.accentBright : Colors.white,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
          trailing: isSelected
              ? Icon(Icons.check_rounded, color: AppColors.accentBright, size: 16)
              : null,
          onTap: () {
            widget.onAspectRatioChanged(index);
            setState(() => _aspectRatioIndex = index);
            Navigator.of(context).pop();
          },
        );
      }),
    );
  }

  Widget _buildAudioMenu() {
    final tracks = widget.player.state.tracks.audio;
    final current = widget.player.state.track.audio;

    final delayText = _audioDelay == 0.0
        ? '0 ms'
        : (_audioDelay > 0.0
            ? '+${(_audioDelay * 1000).round()} ms'
            : '${(_audioDelay * 1000).round()} ms');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Audio sync delay
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('SYNC DELAY',
                  style: TextStyle(color: Colors.white, fontSize: 13)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline_rounded,
                        color: Colors.white, size: 20),
                    onPressed: () async {
                      final delay = double.parse(
                          (_audioDelay - 0.1).toStringAsFixed(3));
                      setState(() => _audioDelay = delay);
                      if (widget.player.platform is NativePlayer) {
                        await (widget.player.platform as NativePlayer)
                            .setProperty('audio-delay', delay.toString());
                      }
                    },
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  Text(delayText,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded,
                        color: Colors.white, size: 20),
                    onPressed: () async {
                      final delay = double.parse(
                          (_audioDelay + 0.1).toStringAsFixed(3));
                      setState(() => _audioDelay = delay);
                      if (widget.player.platform is NativePlayer) {
                        await (widget.player.platform as NativePlayer)
                            .setProperty('audio-delay', delay.toString());
                      }
                    },
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(color: Colors.white10, height: 1),
        ...List.generate(tracks.length, (index) {
          final track = tracks[index];
          final isSelected = track.id == current.id;
          String name = track.title ?? track.language ?? 'Track ${track.id}';
          if (track.id == 'auto') name = 'Auto';
          if (track.id == 'no') name = 'Off';
          return ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            title: Text(
              name.toUpperCase(),
              style: TextStyle(
                color: isSelected ? AppColors.accentBright : Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
            trailing: isSelected
                ? Icon(Icons.check_rounded, color: AppColors.accentBright, size: 16)
                : null,
            onTap: () {
              widget.player.setAudioTrack(track);
              Navigator.of(context).pop();
            },
          );
        }),
      ],
    );
  }

  Widget _buildSubtitleMenu() {
    final tracks = widget.player.state.tracks.subtitle;
    final current = widget.player.state.track.subtitle;

    final delayText = _subtitleDelay == 0.0
        ? '0 ms'
        : (_subtitleDelay > 0.0
            ? '+${(_subtitleDelay * 1000).round()} ms'
            : '${(_subtitleDelay * 1000).round()} ms');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Subtitle sync delay
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('SYNC DELAY',
                  style: TextStyle(color: Colors.white, fontSize: 13)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline_rounded,
                        color: Colors.white, size: 20),
                    onPressed: () async {
                      final delay = double.parse(
                          (_subtitleDelay - 0.1).toStringAsFixed(3));
                      setState(() => _subtitleDelay = delay);
                      if (widget.player.platform is NativePlayer) {
                        await (widget.player.platform as NativePlayer)
                            .setProperty('sub-delay', delay.toString());
                      }
                    },
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  Text(delayText,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded,
                        color: Colors.white, size: 20),
                    onPressed: () async {
                      final delay = double.parse(
                          (_subtitleDelay + 0.1).toStringAsFixed(3));
                      setState(() => _subtitleDelay = delay);
                      if (widget.player.platform is NativePlayer) {
                        await (widget.player.platform as NativePlayer)
                            .setProperty('sub-delay', delay.toString());
                      }
                    },
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(color: Colors.white10, height: 1),
        ...List.generate(tracks.length, (index) {
          final track = tracks[index];
          final isSelected = track.id == current.id;
          String name = track.title ?? track.language ?? 'Track ${track.id}';
          if (track.id == 'auto') name = 'Auto';
          if (track.id == 'no') name = 'Off';
          return ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            title: Text(
              name.toUpperCase(),
              style: TextStyle(
                color: isSelected ? AppColors.accentBright : Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
            trailing: isSelected
                ? Icon(Icons.check_rounded, color: AppColors.accentBright, size: 16)
                : null,
            onTap: () {
              widget.player.setSubtitleTrack(track);
              Navigator.of(context).pop();
            },
          );
        }),
      ],
    );
  }

  Widget _buildQualityMenu() {
    final tracks = widget.player.state.tracks.video;
    final current = widget.player.state.track.video;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(tracks.length, (index) {
        final track = tracks[index];
        final isSelected = track.id == current.id;
        String name = track.h != null ? '${track.h}p' : 'Track ${track.id}';
        if (track.id == 'auto') name = 'Auto';
        if (track.id == 'no') name = 'Off';
        return ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          title: Text(
            name.toUpperCase(),
            style: TextStyle(
              color: isSelected ? AppColors.accentBright : Colors.white,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
          trailing: isSelected
              ? Icon(Icons.check_rounded, color: AppColors.accentBright, size: 16)
              : null,
          onTap: () {
            widget.player.setVideoTrack(track);
            Navigator.of(context).pop();
          },
        );
      }),
    );
  }
}
