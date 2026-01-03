import 'dart:core';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:my_porject/screens/chat_screen.dart';
import 'package:my_porject/resources/methods.dart';
import 'package:my_porject/screens/group/group_chat_room.dart';
import 'package:my_porject/services/private_chat_service.dart';
import 'package:my_porject/services/cache_service.dart';
import 'package:my_porject/configs/app_theme.dart';
import 'package:my_porject/widgets/animated_avatar.dart';
import 'package:my_porject/widgets/page_transitions.dart';

class ConversationList extends StatefulWidget {
  final User user;
  final Map<String, dynamic> chatHistory;
  final bool isDeviceConnected;
  
  const ConversationList({
    super.key, 
    required this.chatHistory,
    required this.user, 
    required this.isDeviceConnected,
  });

  @override
  State<ConversationList> createState() => _ConversationListState();
}

class _ConversationListState extends State<ConversationList> 
    with SingleTickerProviderStateMixin {
  late Map<String, dynamic> userMap;
  bool? isDeviceConnected;
  final CacheService _cacheService = CacheService();
  
  // Animation
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
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

  void _navigateToChat() async {
    final cachedUser = await _cacheService.getUser(widget.chatHistory['uid']);
    
    if (cachedUser != null) {
      userMap = cachedUser;
    } else {
      final firestore = FirebaseFirestore.instance;
      final value = await firestore.collection('users')
          .where("uid", isEqualTo: widget.chatHistory['uid']).get();
      if (value.docs.isNotEmpty) {
        userMap = value.docs[0].data();
      }
    }
    
    final deviceConnected = await InternetConnection().hasInternetAccess;
    final roomId = ChatRoomId().chatRoomId(
      widget.user.displayName, 
      widget.chatHistory['name'],
    );

    if (mounted) {
      setState(() => isDeviceConnected = deviceConnected);
      Navigator.push(
        context,
        SlideRightRoute(
          page: ChatScreen(
            chatRoomId: roomId,
            userMap: userMap,
            user: widget.user,
            isDeviceConnected: isDeviceConnected!,
          ),
        ),
      );
    }
  }

  void _navigateToGroupChat() async {
    final deviceConnected = await InternetConnection().hasInternetAccess;
    if (mounted) {
      setState(() => isDeviceConnected = deviceConnected);
      Navigator.push(
        context,
        SlideRightRoute(
          page: GroupChatRoom(
            groupChatId: widget.chatHistory['uid'], 
            groupName: widget.chatHistory['name'], 
            user: widget.user, 
            isDeviceConnected: isDeviceConnected!,
          ),
        ),
      );
    }
  }

  void _showOptionsMenu() {
    HapticFeedback.mediumImpact();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.gray300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              // Chat info header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    widget.chatHistory['datatype'] == 'group'
                        ? GroupAvatar(
                            imageUrl: widget.chatHistory['avatar'],
                            groupName: widget.chatHistory['name'] ?? 'Group',
                            size: 48,
                            memberCount: 0,
                          )
                        : AnimatedAvatar(
                            imageUrl: widget.chatHistory['avatar'],
                            name: widget.chatHistory['name'] ?? 'Unknown',
                            size: 48,
                            isOnline: widget.chatHistory['status'] == 'Online',
                            showStatus: false,
                          ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.chatHistory['name'] ?? 'Unknown',
                            style: AppTheme.titleMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.chatHistory['datatype'] == 'group' 
                                ? 'Group' 
                                : 'Private Chat',
                            style: AppTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Divider(height: 1),
              // Move to Private option
              _buildOptionTile(
                icon: Icons.lock_outline,
                iconColor: AppTheme.accent,
                title: 'Move to Private',
                subtitle: 'Protect this chat with password',
                onTap: () async {
                  Navigator.pop(context);
                  await _moveToPrivate();
                },
              ),
              // Delete chat option
              _buildOptionTile(
                icon: Icons.delete_outline,
                iconColor: AppTheme.error,
                title: 'Delete Chat',
                subtitle: 'Remove from your chat list',
                isDestructive: true,
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete();
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: AppTheme.titleMedium.copyWith(
          color: isDestructive ? AppTheme.error : AppTheme.textPrimary,
        ),
      ),
      subtitle: Text(subtitle, style: AppTheme.bodySmall),
      onTap: onTap,
    );
  }

  Future<void> _moveToPrivate() async {
    final chatRoomId = widget.chatHistory['datatype'] == 'group'
        ? widget.chatHistory['uid']
        : ChatRoomId().chatRoomId(widget.user.displayName, widget.chatHistory['name']);
    
    final success = await PrivateChatService.addToPrivate(
      chatRoomId: chatRoomId,
      chatName: widget.chatHistory['name'] ?? 'Unknown',
      chatAvatar: widget.chatHistory['avatar'] ?? '',
      chatType: widget.chatHistory['datatype'] ?? 'p2p',
    );
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.lock, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Text('Chat moved to Private'),
            ],
          ),
          backgroundColor: AppTheme.accent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.delete_outline, color: AppTheme.error, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Delete Chat'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this chat with ${widget.chatHistory['name']}?',
          style: AppTheme.bodyLarge,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteChat();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteChat() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final auth = FirebaseAuth.instance;
      
      await firestore
          .collection('users')
          .doc(auth.currentUser!.uid)
          .collection('chatHistory')
          .doc(widget.chatHistory['uid'])
          .delete();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Chat deleted'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUnread = widget.chatHistory['isRead'] == false;
    final isOnline = widget.chatHistory['status'] == 'Online';
    
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: () {
        if (widget.chatHistory['datatype'] == 'group') {
          _navigateToGroupChat();
        } else {
          _navigateToChat();
        }
      },
      onLongPress: _showOptionsMenu,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isUnread 
                ? AppTheme.accent.withValues(alpha: 0.05) 
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar - use GroupAvatar for groups, AnimatedAvatar for users
              widget.chatHistory['datatype'] == 'group'
                  ? GroupAvatar(
                      imageUrl: widget.chatHistory['avatar'],
                      groupName: widget.chatHistory['name'] ?? 'Group',
                      size: 56,
                      memberCount: 0,
                    )
                  : AnimatedAvatar(
                      imageUrl: widget.chatHistory['avatar'],
                      name: widget.chatHistory['name'] ?? 'Unknown',
                      size: 56,
                      isOnline: isOnline,
                      showStatus: true,
                    ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name row
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.chatHistory['name'] ?? 'Unknown',
                            style: AppTheme.chatName.copyWith(
                              fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          extractTimeSafe(widget.chatHistory['time']?.toString()),
                          style: AppTheme.chatTime.copyWith(
                            color: isUnread ? AppTheme.accent : AppTheme.textHint,
                            fontWeight: isUnread ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Message row
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.chatHistory['lastMessage'] ?? '',
                            style: AppTheme.chatMessage.copyWith(
                              fontWeight: isUnread ? FontWeight.w500 : FontWeight.w400,
                              color: isUnread 
                                  ? AppTheme.textPrimary 
                                  : AppTheme.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isUnread)
                          Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.only(left: 8),
                            decoration: BoxDecoration(
                              gradient: AppTheme.greenGradient,
                              shape: BoxShape.circle,
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
      ),
    );
  }
}
