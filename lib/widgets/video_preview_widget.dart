import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class VideoPreviewWidget extends StatefulWidget {
  final String path;
  final Widget Function(BuildContext context, Object error)? onError;

  const VideoPreviewWidget({super.key, required this.path, this.onError});

  @override
  State<VideoPreviewWidget> createState() => _VideoPreviewWidgetState();
}

class _VideoPreviewWidgetState extends State<VideoPreviewWidget> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _error = false;
  Object? _errorDetails;
  final FocusNode _focusNode = FocusNode();
  Timer? _spaceHoldTimer;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  @override
  void didUpdateWidget(covariant VideoPreviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _initController();
    }
  }

  Future<void> _initController() async {
    _disposeController();
    setState(() {
      _initialized = false;
      _error = false;
      _errorDetails = null;
    });

    try {
      final controller = VideoPlayerController.file(File(widget.path));
      _controller = controller;
      await controller.initialize();
      // Auto-loop or just play once? Let's just pause at start.
      // await controller.setLooping(true);
      if (mounted) {
        setState(() {
          _initialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = true;
          _errorDetails = e;
        });
      }
    }
  }

  void _disposeController() {
    _controller?.dispose();
    _controller = null;
  }

  @override
  void dispose() {
    _disposeController();
    _focusNode.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final controller = _controller;
    if (controller != null && _initialized) {
      setState(() {
        if (controller.value.isPlaying) {
          controller.pause();
        } else {
          controller.play();
        }
      });
      // Click to focus so keys work
      FocusScope.of(context).requestFocus(_focusNode);
    }
  }

  Future<void> _seekRelative(Duration delta) async {
    final controller = _controller;
    if (controller != null && _initialized) {
      final newPos = controller.value.position + delta;
      final maxPos = controller.value.duration;
      final target = newPos < Duration.zero
          ? Duration.zero
          : (newPos > maxPos ? maxPos : newPos);

      await controller.seekTo(target);
    }
  }

  Timer? _volumeDisplayTimer;
  bool _showVolume = false;

  void _changeVolume(double delta) {
    if (!_initialized || _controller == null) return;
    final current = _controller!.value.volume;
    final newVol = (current + delta).clamp(0.0, 1.0);
    _controller!.setVolume(newVol);

    // Show overlay
    if (mounted) {
      setState(() {
        _showVolume = true;
      });
      _volumeDisplayTimer?.cancel();
      _volumeDisplayTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _showVolume = false;
          });
        }
      });
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!_initialized || _controller == null) return KeyEventResult.ignored;

    // Space hold for 2x
    // Hybrid Space: Tap to Toggle, Hold for 2x
    if (event.logicalKey == LogicalKeyboardKey.space) {
      if (event is KeyDownEvent) {
        if (_spaceHoldTimer != null ||
            _controller!.value.playbackSpeed == 2.0) {
          // Already holding or processing
          return KeyEventResult.handled;
        }
        // Start hold timer
        _spaceHoldTimer = Timer(const Duration(milliseconds: 200), () {
          _controller!.setPlaybackSpeed(2.0);
          _spaceHoldTimer = null; // Timer handled
        });
      } else if (event is KeyUpEvent) {
        if (_spaceHoldTimer != null && _spaceHoldTimer!.isActive) {
          // Timer pending: It was a short press (Tap)
          _spaceHoldTimer!.cancel();
          _spaceHoldTimer = null;
          _togglePlay();
        } else {
          // Timer fired: It was a long press (Hold) - Restore speed
          _controller!.setPlaybackSpeed(1.0);
        }
      }
      return KeyEventResult.handled;
    }

    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _seekRelative(const Duration(seconds: 5));
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _seekRelative(const Duration(seconds: -5));
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _changeVolume(0.1);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _changeVolume(-0.1);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return widget.onError?.call(context, _errorDetails ?? 'Unknown error') ??
          const Center(child: Icon(Icons.error));
    }

    if (!_initialized || _controller == null) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Listener(
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            final delta = event.scrollDelta.dy;
            if (delta < 0) {
              _changeVolume(0.1);
            } else {
              _changeVolume(-0.1);
            }
          }
        },
        child: GestureDetector(
          onTap: _togglePlay,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
              if (!_controller!.value.isPlaying && !_showVolume)
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(8),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              // Volume Overlay
              if (_showVolume)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _controller!.value.volume == 0
                            ? Icons.volume_off
                            : Icons.volume_up,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(_controller!.value.volume * 100).toInt()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: VideoProgressIndicator(
                  _controller!,
                  allowScrubbing: true,
                  colors: VideoProgressColors(
                    playedColor: Theme.of(context).primaryColor,
                    bufferedColor: Colors.white24,
                    backgroundColor: Colors.white10,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
