import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_porject/configs/app_theme.dart';

/// Micro-interactions and Haptic Feedback Utilities
/// Features: Bounce, pulse, shake, ripple effects with haptic feedback

/// Bouncing Button with haptic feedback
class BounceButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Duration duration;
  final double scaleFactor;
  final bool enableHaptic;

  const BounceButton({
    super.key,
    required this.child,
    this.onPressed,
    this.duration = const Duration(milliseconds: 150),
    this.scaleFactor = 0.95,
    this.enableHaptic = true,
  });

  @override
  State<BounceButton> createState() => _BounceButtonState();
}

class _BounceButtonState extends State<BounceButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleFactor,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    if (widget.enableHaptic) {
      HapticFeedback.lightImpact();
    }
    widget.onPressed?.call();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}

/// Pulse Animation Widget
class PulseWidget extends StatefulWidget {
  final Widget child;
  final bool animate;
  final Duration duration;
  final double minScale;
  final double maxScale;

  const PulseWidget({
    super.key,
    required this.child,
    this.animate = true,
    this.duration = const Duration(milliseconds: 1000),
    this.minScale = 0.95,
    this.maxScale = 1.05,
  });

  @override
  State<PulseWidget> createState() => _PulseWidgetState();
}

class _PulseWidgetState extends State<PulseWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: widget.minScale,
      end: widget.maxScale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    
    if (widget.animate) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(PulseWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: widget.child,
    );
  }
}

/// Shake Animation Widget
class ShakeWidget extends StatefulWidget {
  final Widget child;
  final bool shake;
  final Duration duration;
  final double shakeOffset;
  final VoidCallback? onShakeComplete;

  const ShakeWidget({
    super.key,
    required this.child,
    this.shake = false,
    this.duration = const Duration(milliseconds: 500),
    this.shakeOffset = 10,
    this.onShakeComplete,
  });

  @override
  State<ShakeWidget> createState() => _ShakeWidgetState();
}

class _ShakeWidgetState extends State<ShakeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _offsetAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: widget.shakeOffset), weight: 1),
      TweenSequenceItem(tween: Tween(begin: widget.shakeOffset, end: -widget.shakeOffset), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -widget.shakeOffset, end: widget.shakeOffset), weight: 2),
      TweenSequenceItem(tween: Tween(begin: widget.shakeOffset, end: -widget.shakeOffset), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -widget.shakeOffset, end: 0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onShakeComplete?.call();
      }
    });
  }

  @override
  void didUpdateWidget(ShakeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shake && !oldWidget.shake) {
      HapticFeedback.heavyImpact();
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _offsetAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_offsetAnimation.value, 0),
          child: widget.child,
        );
      },
    );
  }
}

/// Ripple Effect Container
class RippleContainer extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadius? borderRadius;
  final Color? splashColor;
  final Color? highlightColor;

  const RippleContainer({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius,
    this.splashColor,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap?.call();
        },
        onLongPress: () {
          HapticFeedback.mediumImpact();
          onLongPress?.call();
        },
        borderRadius: borderRadius ?? BorderRadius.circular(12),
        splashColor: splashColor ?? AppTheme.accent.withValues(alpha: 0.1),
        highlightColor: highlightColor ?? AppTheme.accent.withValues(alpha: 0.05),
        child: child,
      ),
    );
  }
}

/// Animated Icon Button with multiple states
class AnimatedIconButton extends StatefulWidget {
  final IconData icon;
  final IconData? activeIcon;
  final bool isActive;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? activeColor;
  final double size;
  final bool enableHaptic;

  const AnimatedIconButton({
    super.key,
    required this.icon,
    this.activeIcon,
    this.isActive = false,
    this.onPressed,
    this.color,
    this.activeColor,
    this.size = 24,
    this.enableHaptic = true,
  });

  @override
  State<AnimatedIconButton> createState() => _AnimatedIconButtonState();
}

class _AnimatedIconButtonState extends State<AnimatedIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void didUpdateWidget(AnimatedIconButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (widget.enableHaptic) {
          HapticFeedback.lightImpact();
        }
        widget.onPressed?.call();
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) {
            return ScaleTransition(
              scale: animation,
              child: child,
            );
          },
          child: Icon(
            widget.isActive ? (widget.activeIcon ?? widget.icon) : widget.icon,
            key: ValueKey(widget.isActive),
            color: widget.isActive
                ? (widget.activeColor ?? AppTheme.accent)
                : (widget.color ?? AppTheme.gray400),
            size: widget.size,
          ),
        ),
      ),
    );
  }
}

/// Like/Heart Animation Button
class LikeButton extends StatefulWidget {
  final bool isLiked;
  final ValueChanged<bool>? onChanged;
  final double size;
  final Color? color;
  final Color? likedColor;

  const LikeButton({
    super.key,
    this.isLiked = false,
    this.onChanged,
    this.size = 28,
    this.color,
    this.likedColor,
  });

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _particleController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _particleAnimation;
  bool _isLiked = false;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.isLiked;
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _particleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.8), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.8, end: 1.2), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));
    
    _particleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _particleController, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(LikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLiked != oldWidget.isLiked) {
      _isLiked = widget.isLiked;
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  void _toggleLike() {
    setState(() {
      _isLiked = !_isLiked;
    });
    
    HapticFeedback.mediumImpact();
    _scaleController.forward(from: 0);
    
    if (_isLiked) {
      _particleController.forward(from: 0);
    }
    
    widget.onChanged?.call(_isLiked);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleLike,
      child: SizedBox(
        width: widget.size * 1.5,
        height: widget.size * 1.5,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Particles
            AnimatedBuilder(
              animation: _particleAnimation,
              builder: (context, child) {
                if (!_isLiked) return const SizedBox.shrink();
                return CustomPaint(
                  size: Size(widget.size * 1.5, widget.size * 1.5),
                  painter: _ParticlePainter(
                    progress: _particleAnimation.value,
                    color: widget.likedColor ?? AppTheme.error,
                  ),
                );
              },
            ),
            // Heart icon
            ScaleTransition(
              scale: _scaleAnimation,
              child: Icon(
                _isLiked ? Icons.favorite : Icons.favorite_border,
                color: _isLiked
                    ? (widget.likedColor ?? AppTheme.error)
                    : (widget.color ?? AppTheme.gray400),
                size: widget.size,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final double progress;
  final Color color;

  _ParticlePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = color.withValues(alpha: 1.0 - progress)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 8; i++) {
      final angle = (i * 45) * 3.14159 / 180;
      final distance = progress * size.width * 0.5;
      final offset = Offset(
        center.dx + distance * (i.isEven ? 1.2 : 1) * (i % 3 == 0 ? 1 : 0.8) * (angle < 3.14159 ? 1 : -1),
        center.dy + distance * (i.isOdd ? 1.2 : 1) * (i % 2 == 0 ? -1 : 1),
      );
      canvas.drawCircle(offset, 3 * (1 - progress), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) {
    return progress != oldDelegate.progress;
  }
}

/// Floating Action Button with animations
class AnimatedFAB extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool mini;
  final String? tooltip;
  final bool extended;
  final String? label;

  const AnimatedFAB({
    super.key,
    required this.icon,
    this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.mini = false,
    this.tooltip,
    this.extended = false,
    this.label,
  });

  @override
  State<AnimatedFAB> createState() => _AnimatedFABState();
}

class _AnimatedFABState extends State<AnimatedFAB>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _rotationAnimation = Tween<double>(begin: 0, end: 0.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        HapticFeedback.mediumImpact();
        widget.onPressed?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Transform.rotate(
              angle: _rotationAnimation.value,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.extended ? 20 : 16,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  gradient: AppTheme.greenGradient,
                  borderRadius: BorderRadius.circular(widget.extended ? 28 : 16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accent.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.icon,
                      color: widget.foregroundColor ?? Colors.white,
                      size: widget.mini ? 20 : 24,
                    ),
                    if (widget.extended && widget.label != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        widget.label!,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          color: widget.foregroundColor ?? Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Pull to Refresh with custom animation
class PullToRefreshIndicator extends StatefulWidget {
  final bool isRefreshing;
  final double pullProgress;
  
  const PullToRefreshIndicator({
    super.key,
    this.isRefreshing = false,
    this.pullProgress = 0,
  });

  @override
  State<PullToRefreshIndicator> createState() => _PullToRefreshIndicatorState();
}

class _PullToRefreshIndicatorState extends State<PullToRefreshIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(PullToRefreshIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRefreshing && !_spinController.isAnimating) {
      _spinController.repeat();
    } else if (!widget.isRefreshing && _spinController.isAnimating) {
      _spinController.stop();
    }
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: widget.pullProgress.clamp(0.0, 1.0),
      duration: const Duration(milliseconds: 200),
      child: RotationTransition(
        turns: widget.isRefreshing
            ? _spinController
            : AlwaysStoppedAnimation(widget.pullProgress * 0.5),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Icon(
              Icons.refresh,
              color: AppTheme.accent,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
