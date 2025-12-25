import 'package:my_porject/configs/app_theme.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Ultra Modern Voice Message Player Widget 
/// Features: Animated waveform, playback speed, swipe to seek, haptic feedback
class VoiceMessagePlayer extends StatefulWidget {
  final String audioUrl;
  final bool isMe;
  final String? senderAvatar;
  final DateTime? timestamp;

  const VoiceMessagePlayer({
    super.key,
    required this.audioUrl,
    required this.isMe,
    this.senderAvatar,
    this.timestamp,
  });

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer>
    with TickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = true;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  
  // Playback speed options
  final List<double> _speedOptions = [1.0, 1.5, 2.0];
  int _currentSpeedIndex = 0;
  
  // Animation controllers
  late AnimationController _waveAnimationController;
  late AnimationController _pulseAnimationController;
  late Animation<double> _pulseAnimation;
  
  // Waveform data
  final List<double> _waveformHeights = [];
  final Random _random = Random();
  
  // Interaction state
  bool _isSeeking = false;
  double _seekPosition = 0.0;

  @override
  void initState() {
    super.initState();
    _generateWaveformData();
    _initAnimationControllers();
    _initAudioPlayer();
  }

  void _generateWaveformData() {
    // Generate 35 bars for smoother waveform visualization
    for (int i = 0; i < 35; i++) {
      // Create more natural waveform pattern
      double baseHeight = 0.3 + _random.nextDouble() * 0.7;
      // Add some pattern variation for more realistic look
      if (i % 3 == 0) {
        baseHeight *= 0.8;
      } else if (i % 5 == 0) {
        baseHeight *= 1.1;
      }
      _waveformHeights.add(baseHeight.clamp(0.2, 1.0));
    }
  }

  void _initAnimationControllers() {
    // Waveform wave animation
    _waveAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    // Pulse animation for play button
    _pulseAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _pulseAnimationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  void _initAudioPlayer() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
        if (_isPlaying) {
          _pulseAnimationController.repeat(reverse: true);
        } else {
          _pulseAnimationController.stop();
          _pulseAnimationController.reset();
        }
      }
    });

    _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() {
          _duration = duration;
          _isLoading = false;
        });
      }
    });

    _audioPlayer.onPositionChanged.listen((position) {
      if (mounted && !_isSeeking) {
        setState(() {
          _position = position;
        });
      }
    });

    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });

    _preloadAudio();
  }

  Future<void> _preloadAudio() async {
    try {
      await _audioPlayer.setSourceUrl(widget.audioUrl);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _togglePlayPause() async {
    // Haptic feedback
    HapticFeedback.lightImpact();
    
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        if (_position == Duration.zero) {
          await _audioPlayer.play(UrlSource(widget.audioUrl));
        } else {
          await _audioPlayer.resume();
        }
      }
    } catch (e) {
      debugPrint('Error playing audio: $e');
    }
  }

  void _changeSpeed() {
    HapticFeedback.selectionClick();
    setState(() {
      _currentSpeedIndex = (_currentSpeedIndex + 1) % _speedOptions.length;
    });
    _audioPlayer.setPlaybackRate(_speedOptions[_currentSpeedIndex]);
  }

  void _onSeekStart(DragStartDetails details) {
    setState(() => _isSeeking = true);
    HapticFeedback.selectionClick();
  }

  void _onSeekUpdate(DragUpdateDetails details, double maxWidth) {
    final position = (details.localPosition.dx / maxWidth).clamp(0.0, 1.0);
    setState(() => _seekPosition = position);
  }

  void _onSeekEnd(DragEndDetails details) {
    final newPosition = Duration(
      milliseconds: (_seekPosition * _duration.inMilliseconds).toInt(),
    );
    _audioPlayer.seek(newPosition);
    setState(() {
      _isSeeking = false;
      _position = newPosition;
    });
    HapticFeedback.lightImpact();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _waveAnimationController.dispose();
    _pulseAnimationController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.audioUrl.isEmpty) {
      return _buildErrorState();
    }

    final progress = _isSeeking
        ? _seekPosition
        : (_duration.inMilliseconds > 0
            ? _position.inMilliseconds / _duration.inMilliseconds
            : 0.0);

    return Container(
      constraints: const BoxConstraints(maxWidth: 280, minWidth: 220),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: widget.isMe
              ? [
                  const Color(0xFF6366F1), // Indigo
                  const Color(0xFF8B5CF6), // Purple
                  const Color(0xFFA855F7), // Fuchsia
                ]
              : [
                  Colors.white,
                  const Color(0xFFF8FAFC),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(widget.isMe ? 20 : 4),
          bottomRight: Radius.circular(widget.isMe ? 4 : 20),
        ),
        boxShadow: [
          BoxShadow(
            color: widget.isMe
                ? const Color(0xFF6366F1).withValues(alpha: 0.35)
                : Colors.grey.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 6),
            spreadRadius: 0,
          ),
        ],
        border: widget.isMe
            ? null
            : Border.all(
                color: Colors.grey.withValues(alpha: 0.12),
                width: 1,
              ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(widget.isMe ? 20 : 4),
          bottomRight: Radius.circular(widget.isMe ? 4 : 20),
        ),
        child: Stack(
          children: [
            // Animated background gradient (only when playing)
            if (_isPlaying)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _waveAnimationController,
                  builder: (context, child) {
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: widget.isMe
                              ? [
                                  const Color(0xFF6366F1).withValues(alpha: 0.9),
                                  const Color(0xFF8B5CF6).withValues(alpha: 0.95),
                                  const Color(0xFFA855F7),
                                ]
                              : [
                                  Colors.white,
                                  Colors.white,
                                ],
                          begin: Alignment(
                            -1 + _waveAnimationController.value * 0.5,
                            -1,
                          ),
                          end: Alignment(
                            1 - _waveAnimationController.value * 0.5,
                            1,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            
            // Main content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      // Play/Pause Button
                      _buildPlayButton(),
                      
                      const SizedBox(width: 12),
                      
                      // Waveform and controls
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Interactive Waveform
                            _buildInteractiveWaveform(progress),
                            
                            const SizedBox(height: 8),
                            
                            // Time and Speed controls
                            _buildControls(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayButton() {
    return GestureDetector(
      onTap: _togglePlayPause,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _isPlaying ? _pulseAnimation.value : 1.0,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: widget.isMe
                    ? LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.25),
                          Colors.white.withValues(alpha: 0.15),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : const LinearGradient(
                        colors: [
                          Color(0xFF6366F1),
                          Color(0xFF8B5CF6),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.isMe
                        ? Colors.black.withValues(alpha: 0.1)
                        : const Color(0xFF6366F1).withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: _isLoading
                  ? Padding(
                      padding: const EdgeInsets.all(14),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          widget.isMe ? Colors.white : Colors.white,
                        ),
                      ),
                    )
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, animation) {
                        return RotationTransition(
                          turns: Tween(begin: 0.5, end: 1.0).animate(animation),
                          child: ScaleTransition(scale: animation, child: child),
                        );
                      },
                      child: Icon(
                        _isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        key: ValueKey(_isPlaying),
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInteractiveWaveform(double progress) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onHorizontalDragStart: _onSeekStart,
          onHorizontalDragUpdate: (details) => 
              _onSeekUpdate(details, constraints.maxWidth),
          onHorizontalDragEnd: _onSeekEnd,
          onTapDown: (details) {
            final position = (details.localPosition.dx / constraints.maxWidth)
                .clamp(0.0, 1.0);
            final newPosition = Duration(
              milliseconds: (position * _duration.inMilliseconds).toInt(),
            );
            _audioPlayer.seek(newPosition);
            HapticFeedback.selectionClick();
          },
          child: SizedBox(
            height: 36,
            child: AnimatedBuilder(
              animation: _waveAnimationController,
              builder: (context, child) {
                return CustomPaint(
                  size: Size(constraints.maxWidth, 36),
                  painter: _WaveformPainter(
                    waveformHeights: _waveformHeights,
                    progress: progress,
                    isPlaying: _isPlaying,
                    isMe: widget.isMe,
                    animationValue: _waveAnimationController.value,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildControls() {
    final displayPosition = _isSeeking
        ? Duration(milliseconds: (_seekPosition * _duration.inMilliseconds).toInt())
        : _position;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Time display
        Row(
          children: [
            Text(
              _isLoading
                  ? '--:--'
                  : _formatDuration(displayPosition),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: widget.isMe
                    ? Colors.white.withValues(alpha: 0.95)
                    : AppTheme.gray700,
              ),
            ),
            Text(
              _isLoading ? '' : ' / ${_formatDuration(_duration)}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: widget.isMe
                    ? Colors.white.withValues(alpha: 0.6)
                    : AppTheme.gray400,
              ),
            ),
          ],
        ),
        
        // Speed control and mic icon
        Row(
          children: [
            // Playback speed button
            GestureDetector(
              onTap: _changeSpeed,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.isMe
                      ? Colors.white.withValues(alpha: 0.2)
                      : const Color(0xFF6366F1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_speedOptions[_currentSpeedIndex]}x',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: widget.isMe
                        ? Colors.white
                        : const Color(0xFF6366F1),
                  ),
                ),
              ),
            ),
            
            const SizedBox(width: 6),
            
            // Voice indicator with animation
            AnimatedBuilder(
              animation: _waveAnimationController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _isPlaying 
                      ? 0.9 + (_waveAnimationController.value * 0.2) 
                      : 1.0,
                  child: Icon(
                    Icons.mic_rounded,
                    size: 16,
                    color: widget.isMe
                        ? Colors.white.withValues(alpha: 0.8)
                        : AppTheme.gray500,
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.red.withValues(alpha: 0.08),
            Colors.red.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.red.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.mic_off_rounded,
              color: Colors.red[400],
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Voice unavailable',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Tap to retry',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.red[400],
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Custom painter for smooth waveform rendering
class _WaveformPainter extends CustomPainter {
  final List<double> waveformHeights;
  final double progress;
  final bool isPlaying;
  final bool isMe;
  final double animationValue;

  _WaveformPainter({
    required this.waveformHeights,
    required this.progress,
    required this.isPlaying,
    required this.isMe,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final barWidth = size.width / waveformHeights.length - 2;
    final maxHeight = size.height - 4;
    
    for (int i = 0; i < waveformHeights.length; i++) {
      final barProgress = i / waveformHeights.length;
      final isPast = barProgress < progress;
      final isCurrentBar = (barProgress - progress).abs() < 0.03;
      
      // Calculate animated height
      double barHeight = waveformHeights[i];
      if (isPlaying) {
        // Add wave animation
        barHeight *= (0.6 + 0.4 * sin(animationValue * pi * 2 + i * 0.25));
      }
      
      final height = 4 + (barHeight * (maxHeight - 4));
      final x = i * (barWidth + 2) + 1;
      final y = (size.height - height) / 2;
      
      // Determine colors
      Color barColor;
      if (isPast || isCurrentBar) {
        barColor = isMe 
            ? Colors.white 
            : const Color(0xFF6366F1);
      } else {
        barColor = isMe 
            ? Colors.white.withValues(alpha: 0.35) 
            : Colors.grey.withValues(alpha: 0.35);
      }
      
      // Create gradient for active bars
      final paint = Paint()
        ..style = PaintingStyle.fill;
      
      if (isPast || isCurrentBar) {
        paint.shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isMe
              ? [Colors.white, Colors.white.withValues(alpha: 0.9)]
              : [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
        ).createShader(Rect.fromLTWH(x, y, barWidth, height));
      } else {
        paint.color = barColor;
      }
      
      // Draw rounded bar
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, height),
        const Radius.circular(2),
      );
      
      canvas.drawRRect(rect, paint);
      
      // Add glow effect for current position
      if (isCurrentBar && isPlaying) {
        final glowPaint = Paint()
          ..color = (isMe ? Colors.white : const Color(0xFF6366F1))
              .withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawRRect(rect, glowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.animationValue != animationValue;
  }
}
