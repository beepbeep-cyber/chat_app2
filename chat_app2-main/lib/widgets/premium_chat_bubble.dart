import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_porject/configs/app_theme.dart';

/// Premium Chat Bubble Widget
/// Features: Gradient backgrounds, smooth animations, read receipts, reactions
class PremiumChatBubble extends StatefulWidget {
  final String message;
  final bool isMe;
  final String time;
  final bool isRead;
  final bool showTail;
  final VoidCallback? onLongPress;
  final VoidCallback? onDoubleTap;
  final Widget? replyWidget;
  final String? senderName;
  final bool showSenderName;

  const PremiumChatBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.time,
    this.isRead = false,
    this.showTail = true,
    this.onLongPress,
    this.onDoubleTap,
    this.replyWidget,
    this.senderName,
    this.showSenderName = false,
  });

  @override
  State<PremiumChatBubble> createState() => _PremiumChatBubbleState();
}

class _PremiumChatBubbleState extends State<PremiumChatBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _scaleController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _scaleController.reverse();
  }

  void _onTapCancel() {
    _scaleController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(
          left: widget.isMe ? 60 : 8,
          right: widget.isMe ? 8 : 60,
          top: 2,
          bottom: 2,
        ),
        child: GestureDetector(
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          onLongPress: () {
            HapticFeedback.mediumImpact();
            widget.onLongPress?.call();
          },
          onDoubleTap: () {
            HapticFeedback.lightImpact();
            widget.onDoubleTap?.call();
          },
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              decoration: BoxDecoration(
                gradient: widget.isMe
                    ? const LinearGradient(
                        colors: [
                          Color(0xFF10B981),
                          Color(0xFF059669),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: widget.isMe ? null : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(widget.isMe || !widget.showTail ? 20 : 4),
                  bottomRight: Radius.circular(!widget.isMe || !widget.showTail ? 20 : 4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.isMe
                        ? AppTheme.accent.withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(widget.isMe || !widget.showTail ? 20 : 4),
                  bottomRight: Radius.circular(!widget.isMe || !widget.showTail ? 20 : 4),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Sender name for group chats
                      if (widget.showSenderName && widget.senderName != null && !widget.isMe)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            widget.senderName!,
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.accent,
                            ),
                          ),
                        ),
                      
                      // Reply preview
                      if (widget.replyWidget != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: widget.isMe
                                ? Colors.white.withValues(alpha: 0.15)
                                : AppTheme.gray100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border(
                              left: BorderSide(
                                color: widget.isMe ? Colors.white : AppTheme.accent,
                                width: 3,
                              ),
                            ),
                          ),
                          child: widget.replyWidget!,
                        ),
                      
                      // Message text
                      Text(
                        widget.message,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: widget.isMe ? Colors.white : AppTheme.textPrimary,
                          height: 1.4,
                        ),
                      ),
                      
                      const SizedBox(height: 4),
                      
                      // Time and read status
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            widget.time,
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: widget.isMe
                                  ? Colors.white.withValues(alpha: 0.7)
                                  : AppTheme.textHint,
                            ),
                          ),
                          if (widget.isMe) ...[
                            const SizedBox(width: 4),
                            Icon(
                              widget.isRead ? Icons.done_all : Icons.done,
                              size: 14,
                              color: widget.isRead
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.7),
                            ),
                          ],
                        ],
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
}

/// Image Message Bubble
class ImageMessageBubble extends StatelessWidget {
  final String imageUrl;
  final bool isMe;
  final String time;
  final bool isRead;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const ImageMessageBubble({
    super.key,
    required this.imageUrl,
    required this.isMe,
    required this.time,
    this.isRead = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(
          left: isMe ? 60 : 8,
          right: isMe ? 8 : 60,
          top: 2,
          bottom: 2,
        ),
        child: GestureDetector(
          onTap: onTap,
          onLongPress: () {
            HapticFeedback.mediumImpact();
            onLongPress?.call();
          },
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.65,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        width: 200,
                        height: 200,
                        color: AppTheme.gray100,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: progress.expectedTotalBytes != null
                                ? progress.cumulativeBytesLoaded /
                                    progress.expectedTotalBytes!
                                : null,
                            strokeWidth: 2,
                            color: AppTheme.accent,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 200,
                        height: 200,
                        color: AppTheme.gray100,
                        child: const Icon(
                          Icons.broken_image_outlined,
                          color: AppTheme.gray400,
                          size: 48,
                        ),
                      );
                    },
                  ),
                ),
                // Time overlay
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          time,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 11,
                            color: Colors.white,
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          Icon(
                            isRead ? Icons.done_all : Icons.done,
                            size: 14,
                            color: isRead ? Colors.white : Colors.white70,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Typing Indicator Widget
class TypingIndicator extends StatefulWidget {
  final bool showIndicator;

  const TypingIndicator({
    super.key,
    this.showIndicator = true,
  });

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
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
      return Tween<double>(begin: 0, end: -8).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      );
    }).toList();

    _startAnimation();
  }

  void _startAnimation() async {
    for (int i = 0; i < 3; i++) {
      await Future.delayed(const Duration(milliseconds: 150));
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
    if (!widget.showIndicator) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(left: 8, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            return AnimatedBuilder(
              animation: _animations[index],
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _animations[index].value),
                  child: Container(
                    width: 8,
                    height: 8,
                    margin: EdgeInsets.only(right: index < 2 ? 4 : 0),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.gray400,
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ),
    );
  }
}
