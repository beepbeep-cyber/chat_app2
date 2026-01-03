import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:my_porject/configs/app_theme.dart';

/// Animated Avatar Widget with Online Status Ring
/// Features: Pulse animation for online, gradient border, hero animation support
class AnimatedAvatar extends StatefulWidget {
  final String? imageUrl;
  final String name;
  final double size;
  final bool isOnline;
  final bool showStatus;
  final bool enableHero;
  final String? heroTag;
  final VoidCallback? onTap;

  const AnimatedAvatar({
    super.key,
    this.imageUrl,
    required this.name,
    this.size = 56,
    this.isOnline = false,
    this.showStatus = true,
    this.enableHero = false,
    this.heroTag,
    this.onTap,
  });

  @override
  State<AnimatedAvatar> createState() => _AnimatedAvatarState();
}

class _AnimatedAvatarState extends State<AnimatedAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (widget.isOnline) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AnimatedAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOnline && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isOnline && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _getInitials() {
    final parts = widget.name.trim().split(' ');
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  Widget _buildAvatar() {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: widget.isOnline && widget.showStatus
            ? const LinearGradient(
                colors: [AppTheme.accent, AppTheme.accentLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        border: widget.isOnline && widget.showStatus
            ? null
            : Border.all(
                color: AppTheme.gray200,
                width: 2,
              ),
        boxShadow: [
          BoxShadow(
            color: widget.isOnline && widget.showStatus
                ? AppTheme.accent.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.1),
            blurRadius: widget.isOnline ? 12 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(2.5),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        padding: const EdgeInsets.all(2),
        child: ClipOval(
          child: widget.imageUrl != null && widget.imageUrl!.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: widget.imageUrl!,
                  fit: BoxFit.cover,
                  memCacheWidth: (widget.size * 2).toInt(),
                  memCacheHeight: (widget.size * 2).toInt(),
                  placeholder: (context, url) => _buildPlaceholder(),
                  errorWidget: (context, url, error) => _buildPlaceholder(),
                )
              : _buildPlaceholder(),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppTheme.gray100,
      child: Center(
        child: Text(
          _getInitials(),
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: widget.size * 0.35,
            fontWeight: FontWeight.w600,
            color: AppTheme.gray600,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    if (!widget.showStatus) return const SizedBox.shrink();
    
    final indicatorSize = widget.size * 0.25;
    return Positioned(
      right: 0,
      bottom: 0,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: widget.isOnline ? _pulseAnimation.value : 1.0,
            child: Container(
              width: indicatorSize,
              height: indicatorSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isOnline ? AppTheme.online : AppTheme.offline,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
                boxShadow: widget.isOnline
                    ? [
                        BoxShadow(
                          color: AppTheme.online.withValues(alpha: 0.5),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget avatar = Stack(
      clipBehavior: Clip.none,
      children: [
        _buildAvatar(),
        _buildStatusIndicator(),
      ],
    );

    if (widget.enableHero && widget.heroTag != null) {
      avatar = Hero(
        tag: widget.heroTag!,
        child: avatar,
      );
    }

    if (widget.onTap != null) {
      avatar = GestureDetector(
        onTap: widget.onTap,
        child: avatar,
      );
    }

    return avatar;
  }
}

/// Group Avatar Widget for group chats - Modern gradient circle with group icon
class GroupAvatar extends StatelessWidget {
  final String? imageUrl;
  final String groupName;
  final double size;
  final int memberCount;

  const GroupAvatar({
    super.key,
    this.imageUrl,
    required this.groupName,
    this.size = 56,
    this.memberCount = 0,
  });

  String _getInitials() {
    final parts = groupName.trim().split(' ');
    if (parts.isEmpty || parts[0].isEmpty) return 'G';
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: imageUrl != null && imageUrl!.isNotEmpty && imageUrl!.startsWith('http')
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                memCacheWidth: (size * 2).toInt(),
                memCacheHeight: (size * 2).toInt(),
                placeholder: (context, url) => _buildDefaultGroupIcon(),
                errorWidget: (context, url, error) => _buildDefaultGroupIcon(),
              ),
            )
          : _buildDefaultGroupIcon(),
    );
  }

  Widget _buildDefaultGroupIcon() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Group icon or initials
          Center(
            child: memberCount > 0
                ? Icon(
                    Icons.group_rounded,
                    color: Colors.white,
                    size: size * 0.5,
                  )
                : Text(
                    _getInitials(),
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: size * 0.35,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
          ),
          // Member count badge
          if (memberCount > 0)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: size * 0.35,
                height: size * 0.35,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.success,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.success.withValues(alpha: 0.4),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    memberCount > 99 ? '99+' : memberCount.toString(),
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: size * 0.15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
