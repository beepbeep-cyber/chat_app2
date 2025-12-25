import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_porject/configs/app_theme.dart';

/// Animated List Item with slide, fade, and scale effects
/// Features: Staggered animation, swipe actions, press feedback
class AnimatedListItem extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration delay;
  final Duration duration;
  final Curve curve;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? leadingSwipeAction;
  final Widget? trailingSwipeAction;
  final VoidCallback? onLeadingSwipe;
  final VoidCallback? onTrailingSwipe;
  final bool enableSwipe;

  const AnimatedListItem({
    super.key,
    required this.child,
    this.index = 0,
    this.delay = const Duration(milliseconds: 50),
    this.duration = const Duration(milliseconds: 400),
    this.curve = Curves.easeOutCubic,
    this.onTap,
    this.onLongPress,
    this.leadingSwipeAction,
    this.trailingSwipeAction,
    this.onLeadingSwipe,
    this.onTrailingSwipe,
    this.enableSwipe = false,
  });

  @override
  State<AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<AnimatedListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));

    // Start animation with delay based on index
    Future.delayed(widget.delay * widget.index, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildContent() {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      onLongPress: () {
        HapticFeedback.mediumImpact();
        widget.onLongPress?.call();
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.enableSwipe) {
      return Dismissible(
        key: ValueKey('item_${widget.index}'),
        direction: DismissDirection.horizontal,
        background: widget.leadingSwipeAction ?? _buildDefaultSwipeAction(true),
        secondaryBackground: widget.trailingSwipeAction ?? _buildDefaultSwipeAction(false),
        confirmDismiss: (direction) async {
          HapticFeedback.mediumImpact();
          if (direction == DismissDirection.startToEnd) {
            widget.onLeadingSwipe?.call();
          } else {
            widget.onTrailingSwipe?.call();
          }
          return false; // Don't actually dismiss
        },
        child: _buildContent(),
      );
    }

    return _buildContent();
  }

  Widget _buildDefaultSwipeAction(bool isLeading) {
    return Container(
      color: isLeading ? AppTheme.accent : AppTheme.error,
      alignment: isLeading ? Alignment.centerLeft : Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Icon(
        isLeading ? Icons.archive_outlined : Icons.delete_outline,
        color: Colors.white,
        size: 28,
      ),
    );
  }
}

/// Chat List Item Widget with premium design
class PremiumChatListItem extends StatelessWidget {
  final Widget avatar;
  final String name;
  final String lastMessage;
  final String time;
  final bool isOnline;
  final bool hasUnread;
  final int unreadCount;
  final bool isTyping;
  final bool isPinned;
  final bool isMuted;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const PremiumChatListItem({
    super.key,
    required this.avatar,
    required this.name,
    required this.lastMessage,
    required this.time,
    this.isOnline = false,
    this.hasUnread = false,
    this.unreadCount = 0,
    this.isTyping = false,
    this.isPinned = false,
    this.isMuted = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: hasUnread ? AppTheme.accent.withValues(alpha: 0.05) : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: AppTheme.gray100,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            // Avatar
            avatar,
            const SizedBox(width: 12),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name and time row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            if (isPinned) ...[
                              Icon(
                                Icons.push_pin,
                                size: 14,
                                color: AppTheme.accent,
                              ),
                              const SizedBox(width: 4),
                            ],
                            Flexible(
                              child: Text(
                                name,
                                style: AppTheme.chatName.copyWith(
                                  fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isMuted) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.notifications_off_outlined,
                                size: 14,
                                color: AppTheme.gray400,
                              ),
                            ],
                          ],
                        ),
                      ),
                      Text(
                        time,
                        style: AppTheme.chatTime.copyWith(
                          color: hasUnread ? AppTheme.accent : AppTheme.textHint,
                          fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  
                  // Message and unread badge row
                  Row(
                    children: [
                      Expanded(
                        child: isTyping
                            ? Row(
                                children: [
                                  _TypingDots(),
                                  const SizedBox(width: 8),
                                  Text(
                                    'typing...',
                                    style: AppTheme.chatMessage.copyWith(
                                      color: AppTheme.accent,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                lastMessage,
                                style: AppTheme.chatMessage.copyWith(
                                  fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w400,
                                  color: hasUnread ? AppTheme.textPrimary : AppTheme.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                      if (hasUnread && unreadCount > 0)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: unreadCount > 99 ? 6 : 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            gradient: AppTheme.greenGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
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
      ),
    );
  }
}

/// Typing dots animation
class _TypingDots extends StatefulWidget {
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 400),
        vsync: this,
      ),
    );
    _animations = _controllers.map((controller) {
      return Tween<double>(begin: 0, end: -4).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      );
    }).toList();

    _startAnimation();
  }

  void _startAnimation() async {
    for (int i = 0; i < 3; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) {
        _controllers[i].repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _animations[index],
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _animations[index].value),
              child: Container(
                width: 5,
                height: 5,
                margin: EdgeInsets.only(right: index < 2 ? 2 : 0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accent,
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

/// Shimmer Loading Effect for Chat List
class ChatListShimmer extends StatefulWidget {
  final int itemCount;

  const ChatListShimmer({
    super.key,
    this.itemCount = 8,
  });

  @override
  State<ChatListShimmer> createState() => _ChatListShimmerState();
}

class _ChatListShimmerState extends State<ChatListShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: widget.itemCount,
      padding: EdgeInsets.zero,
      itemBuilder: (context, index) {
        return AnimatedBuilder(
          animation: _shimmerController,
          builder: (context, child) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Avatar shimmer
                  _buildShimmerBox(
                    width: 56,
                    height: 56,
                    borderRadius: 28,
                  ),
                  const SizedBox(width: 12),
                  
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildShimmerBox(width: 120, height: 16),
                            _buildShimmerBox(width: 40, height: 12),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildShimmerBox(width: double.infinity, height: 14),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildShimmerBox({
    required double height,
    double? width,
    double borderRadius = 8,
  }) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                AppTheme.gray100,
                AppTheme.gray50,
                AppTheme.gray100,
              ],
              stops: [
                0.0,
                _shimmerController.value,
                1.0,
              ],
            ),
          ),
        );
      },
    );
  }
}
