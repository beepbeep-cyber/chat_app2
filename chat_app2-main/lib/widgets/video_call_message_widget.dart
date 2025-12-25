import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:my_porject/configs/app_theme.dart';

/// Premium Video Call Message Widget
/// Hiển thị tin nhắn video call với UI đẹp và hiệu ứng
class VideoCallMessageWidget extends StatelessWidget {
  final Map<String, dynamic> messageData;
  final Map<String, dynamic> userMap;
  final String currentUserName;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;

  const VideoCallMessageWidget({
    super.key,
    required this.messageData,
    required this.userMap,
    required this.currentUserName,
    this.onLongPress,
    this.onTap,
  });

  bool get isMe => messageData['sendBy'] == currentUserName;
  bool get isMissedCall => messageData['callStatus'] == 'missed';
  bool get isIncomingCall => messageData['callDirection'] == 'incoming';
  
  String get callDuration {
    final timeSpend = messageData['timeSpend'];
    if (timeSpend == null || timeSpend <= 0) return '';
    final int secs = timeSpend is int ? timeSpend : int.tryParse(timeSpend.toString()) ?? 0;
    if (secs < 60) return '${secs}s';
    final int mins = secs ~/ 60;
    final int remainingSecs = secs % 60;
    if (mins < 60) return '${mins}m ${remainingSecs}s';
    final int hours = mins ~/ 60;
    final int remainingMins = mins % 60;
    return '${hours}h ${remainingMins}m';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar (only for received messages)
          if (!isMe) ...[
            _buildAvatar(),
            const SizedBox(width: 8),
          ],
          
          // Call message card
          GestureDetector(
            onLongPress: isMe ? onLongPress : null,
            onTap: onTap,
            child: _buildCallCard(context),
          ),
          
          // Spacer for sent messages
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final hasAvatar = userMap['avatar'] != null && 
                      userMap['avatar'].toString().isNotEmpty;
    
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppTheme.gray200,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: CircleAvatar(
        radius: 16,
        backgroundColor: AppTheme.gray100,
        backgroundImage: hasAvatar
            ? CachedNetworkImageProvider(
                userMap['avatar'],
                maxWidth: 72,
                maxHeight: 72,
              )
            : null,
        child: !hasAvatar
            ? Icon(Icons.person, size: 18, color: AppTheme.gray400)
            : null,
      ),
    );
  }

  Widget _buildCallCard(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.65,
      ),
      decoration: BoxDecoration(
        gradient: isMissedCall
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFFFEBEE),
                  const Color(0xFFFFCDD2),
                ],
              )
            : isMe
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.accent,
                      AppTheme.accentDark,
                    ],
                  )
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      AppTheme.gray50,
                    ],
                  ),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(6),
          bottomRight: isMe ? const Radius.circular(6) : const Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: isMissedCall
                ? AppTheme.error.withValues(alpha: 0.2)
                : isMe
                    ? AppTheme.accent.withValues(alpha: 0.3)
                    : Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Call icon with animation
            _buildCallIcon(),
            const SizedBox(width: 12),
            
            // Call info
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Call type
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isMissedCall
                            ? Icons.call_missed
                            : Icons.videocam_rounded,
                        size: 16,
                        color: _getTextColor(),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _getCallTitle(),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: _getTextColor(),
                            letterSpacing: 0.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // Call duration or status
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isMissedCall ? Icons.error_outline : Icons.timer_outlined,
                        size: 13,
                        color: _getSubtextColor(),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isMissedCall
                            ? 'Tap to call back'
                            : callDuration.isNotEmpty
                                ? callDuration
                                : 'Ended',
                        style: TextStyle(
                          fontSize: 12,
                          color: _getSubtextColor(),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Call back button for missed calls
            if (isMissedCall) ...[
              const SizedBox(width: 10),
              _buildCallBackButton(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCallIcon() {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isMissedCall
            ? LinearGradient(
                colors: [
                  AppTheme.error.withValues(alpha: 0.8),
                  AppTheme.error,
                ],
              )
            : isMe
                ? LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.3),
                      Colors.white.withValues(alpha: 0.1),
                    ],
                  )
                : LinearGradient(
                    colors: [
                      AppTheme.accent.withValues(alpha: 0.15),
                      AppTheme.accent.withValues(alpha: 0.05),
                    ],
                  ),
        border: Border.all(
          color: isMissedCall
              ? AppTheme.error.withValues(alpha: 0.3)
              : isMe
                  ? Colors.white.withValues(alpha: 0.4)
                  : AppTheme.accent.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: isMissedCall
                ? AppTheme.error.withValues(alpha: 0.3)
                : AppTheme.accent.withValues(alpha: 0.2),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Icon(
        isMissedCall ? Icons.call_missed_rounded : Icons.videocam_rounded,
        color: isMissedCall
            ? Colors.white
            : isMe
                ? Colors.white
                : AppTheme.accent,
        size: 22,
      ),
    );
  }

  Widget _buildCallBackButton() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.accent,
        boxShadow: [
          BoxShadow(
            color: AppTheme.accent.withValues(alpha: 0.4),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: const Icon(
        Icons.videocam_rounded,
        color: Colors.white,
        size: 18,
      ),
    );
  }

  String _getCallTitle() {
    if (isMissedCall) {
      return 'Missed Video Call';
    }
    return 'Video Call';
  }

  Color _getTextColor() {
    if (isMissedCall) return AppTheme.error;
    if (isMe) return Colors.white;
    return AppTheme.textPrimary;
  }

  Color _getSubtextColor() {
    if (isMissedCall) return AppTheme.error.withValues(alpha: 0.7);
    if (isMe) return Colors.white.withValues(alpha: 0.8);
    return AppTheme.textSecondary;
  }
}

/// Compact Video Call Message (for list view)
class CompactVideoCallMessage extends StatelessWidget {
  final bool isMissed;
  final String duration;
  final bool isOutgoing;
  final String time;

  const CompactVideoCallMessage({
    super.key,
    required this.isMissed,
    required this.duration,
    required this.isOutgoing,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isMissed
              ? Icons.call_missed
              : isOutgoing
                  ? Icons.call_made
                  : Icons.call_received,
          size: 14,
          color: isMissed ? AppTheme.error : AppTheme.accent,
        ),
        const SizedBox(width: 6),
        Text(
          isMissed
              ? 'Missed call'
              : 'Video call ${duration.isNotEmpty ? "($duration)" : ""}',
          style: TextStyle(
            fontSize: 13,
            color: isMissed ? AppTheme.error : AppTheme.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          time,
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.textHint,
          ),
        ),
      ],
    );
  }
}
