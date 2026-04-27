import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:path/path.dart' as p;

class PlayerScreen extends StatefulWidget {
  final List<String> videoPaths;
  final int startIndex;

  const PlayerScreen({
    super.key,
    required this.videoPaths,
    required this.startIndex,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with SingleTickerProviderStateMixin {
  late VideoPlayerController _controller;
  int _currentIndex = 0;
  bool _showOverlay = false;
  Timer? _overlayTimer;
  late AnimationController _fadeAnim;
  late Animation<double> _fadeAnimation;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.startIndex;

    _fadeAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeAnim, curve: Curves.easeOut);

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable();
    _initPlayer();
  }

  Future<void> _initPlayer({bool autoPlay = true}) async {
    setState(() {
      _isInitialized = false;
      _hasError = false;
    });

    final path = widget.videoPaths[_currentIndex];
    _controller = VideoPlayerController.file(File(path));

    try {
      await _controller.initialize();
      _controller.setLooping(widget.videoPaths.length == 1);
      _controller.addListener(_onVideoEvent);

      if (mounted) {
        setState(() => _isInitialized = true);
        if (autoPlay) _controller.play();
      }
    } catch (e) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  void _onVideoEvent() {
    if (!mounted) return;
    // When multi-video playlist ends, go to next
    if (widget.videoPaths.length > 1) {
      final pos = _controller.value.position;
      final dur = _controller.value.duration;
      if (dur.inMilliseconds > 0 &&
          pos.inMilliseconds >= dur.inMilliseconds - 100) {
        _nextVideo();
      }
    }
    setState(() {}); // refresh UI for position changes
  }

  void _nextVideo() {
    if (widget.videoPaths.length <= 1) return;
    final next = (_currentIndex + 1) % widget.videoPaths.length;
    _switchTo(next);
  }

  void _prevVideo() {
    if (widget.videoPaths.length <= 1) return;
    final prev =
        (_currentIndex - 1 + widget.videoPaths.length) % widget.videoPaths.length;
    _switchTo(prev);
  }

  Future<void> _switchTo(int index) async {
    _controller.removeListener(_onVideoEvent);
    await _controller.dispose();
    _currentIndex = index;
    await _initPlayer();
  }

  void _toggleOverlay() {
    if (_showOverlay) {
      _hideOverlay();
    } else {
      _showOverlayTemporarily();
    }
  }

  void _showOverlayTemporarily() {
    _overlayTimer?.cancel();
    setState(() => _showOverlay = true);
    _fadeAnim.forward();
    _overlayTimer = Timer(const Duration(seconds: 3), _hideOverlay);
  }

  void _hideOverlay() {
    _fadeAnim.reverse().then((_) {
      if (mounted) setState(() => _showOverlay = false);
    });
    _overlayTimer?.cancel();
  }

  void _togglePlay() {
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
    _showOverlayTemporarily();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  String _fileName(String path) => p.basenameWithoutExtension(path);

  @override
  void dispose() {
    _overlayTimer?.cancel();
    _controller.removeListener(_onVideoEvent);
    _controller.dispose();
    _fadeAnim.dispose();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleOverlay,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video
            Center(child: _buildVideo()),

            // Overlay
            if (_showOverlay)
              FadeTransition(
                opacity: _fadeAnimation,
                child: _buildOverlay(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideo() {
    if (_hasError) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: Colors.white30, size: 48),
          SizedBox(height: 12),
          Text(
            'Could not play this file',
            style: TextStyle(color: Colors.white38, fontSize: 14),
          ),
        ],
      );
    }

    if (!_isInitialized) {
      return const SizedBox(
        width: 32,
        height: 32,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.white30,
        ),
      );
    }

    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: VideoPlayer(_controller),
    );
  }

  Widget _buildOverlay() {
    final value = _controller.value;
    final position = value.position;
    final duration = value.duration;
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;
    final isPlaying = value.isPlaying;
    final hasMultiple = widget.videoPaths.length > 1;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xCC000000),
            Colors.transparent,
            Colors.transparent,
            Color(0xCC000000),
          ],
          stops: [0.0, 0.25, 0.75, 1.0],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: Colors.white, size: 28),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black26,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _fileName(widget.videoPaths[_currentIndex]),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (hasMultiple)
                          Text(
                            '${_currentIndex + 1} / ${widget.videoPaths.length}  •  LOOPING',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                              letterSpacing: 0.5,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Center play controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (hasMultiple)
                  _ControlButton(
                    icon: Icons.skip_previous_rounded,
                    size: 32,
                    onTap: () {
                      _prevVideo();
                      _showOverlayTemporarily();
                    },
                  ),
                const SizedBox(width: 24),
                _ControlButton(
                  icon: isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 52,
                  filled: true,
                  onTap: _togglePlay,
                ),
                const SizedBox(width: 24),
                if (hasMultiple)
                  _ControlButton(
                    icon: Icons.skip_next_rounded,
                    size: 32,
                    onTap: () {
                      _nextVideo();
                      _showOverlayTemporarily();
                    },
                  ),
              ],
            ),

            const Spacer(),

            // Progress bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: [
                  // Scrubber
                  SliderTheme(
                    data: SliderThemeData(
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 14),
                      trackHeight: 2,
                      thumbColor: Colors.white,
                      activeTrackColor: Colors.white,
                      inactiveTrackColor: Colors.white24,
                      overlayColor: Colors.white24,
                    ),
                    child: Slider(
                      value: progress.clamp(0.0, 1.0),
                      onChanged: (v) {
                        final target = Duration(
                          milliseconds:
                              (v * duration.inMilliseconds).toInt(),
                        );
                        _controller.seekTo(target);
                        _showOverlayTemporarily();
                      },
                    ),
                  ),
                  // Time labels
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(position),
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        Text(
                          _formatDuration(duration),
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final bool filled;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.size,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size + 24,
        height: size + 24,
        decoration: BoxDecoration(
          color: filled ? Colors.white : Colors.black38,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: size,
          color: filled ? Colors.black : Colors.white,
        ),
      ),
    );
  }
}
