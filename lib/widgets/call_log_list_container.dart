import 'package:my_porject/configs/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:my_porject/db/log_repository.dart';
import 'package:my_porject/resources/methods.dart';
import 'package:my_porject/screens/video_call_screen.dart';
import 'package:my_porject/widgets/page_transitions.dart';

import '../models/log_model.dart';

class CallLogListContainer extends StatefulWidget {
  const CallLogListContainer({Key? key}) : super(key: key);

  @override
  State<CallLogListContainer> createState() => _CallLogListContainerState();
}

class _CallLogListContainerState extends State<CallLogListContainer> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  /// Make a video call to a user from call log
  Future<void> _makeVideoCall(Log log, bool hasDialled) async {
    // Show loading
    HapticFeedback.mediumImpact();
    
    // Check internet connection
    final isConnected = await InternetConnection().hasInternetAccess;
    if (!isConnected) {
      if (mounted) {
        _showNoConnectionDialog();
      }
      return;
    }
    
    // Get the name of the person to call
    // If hasDialled (outgoing call), we want to call the receiver
    // If not hasDialled (incoming call), we want to call the caller
    final String targetName = hasDialled ? log.receiverName! : log.callerName!;
    final String targetAvatar = hasDialled ? (log.receiverPic ?? '') : (log.callerPic ?? '');
    
    try {
      // Find user by name in Firestore
      final querySnapshot = await _firestore
          .collection('users')
          .where('name', isEqualTo: targetName)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('User "$targetName" not found'),
              backgroundColor: AppTheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      
      final userData = querySnapshot.docs.first.data();
      final String targetUid = userData['uid'] ?? querySnapshot.docs.first.id;
      final String? actualAvatar = userData['avatar'] ?? targetAvatar;
      
      // Get current user info
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please login to make calls'),
              backgroundColor: AppTheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      
      // Generate unique channel name for this call
      final channelName = ChatRoomId().chatRoomId(currentUser.displayName, targetName);
      final callChannelName = '${channelName}_${DateTime.now().millisecondsSinceEpoch}';
      
      if (mounted) {
        Navigator.push(
          context,
          SlideRightRoute(
            page: VideoCallScreen(
              channelName: callChannelName,
              userName: currentUser.displayName ?? 'You',
              userAvatar: currentUser.photoURL,
              calleeName: targetName,
              calleeAvatar: actualAvatar,
              chatRoomId: channelName,
              calleeUid: targetUid,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ CallLog: Error making call: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to make call: $e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
  
  void _showNoConnectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.wifi_off, color: AppTheme.gray700, size: 28),
            const SizedBox(width: 12),
            const Text('No Connection'),
          ],
        ),
        content: const Text('Please check your internet connection and try again.'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.gray800,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  void _showCallLogOptions(Log log, int index, bool hasDialled) {
    final String targetName = hasDialled ? log.receiverName! : log.callerName!;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
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
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.videocam, color: AppTheme.accent, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            targetName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            formatTimestampSafe(log.timeStamp),
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.gray600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              // Video Call option
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.videocam, color: AppTheme.success, size: 22),
                ),
                title: const Text(
                  'Video Call',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  'Start a video call with $targetName',
                  style: TextStyle(color: AppTheme.gray600, fontSize: 13),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _makeVideoCall(log, hasDialled);
                },
              ),
              // Delete option
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.delete_outline, color: AppTheme.error, size: 22),
                ),
                title: Text(
                  'Delete',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppTheme.error,
                  ),
                ),
                subtitle: Text(
                  'Remove this call from history',
                  style: TextStyle(color: AppTheme.gray600, fontSize: 13),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await LogRepository.deleteLogs(index);
                  if (mounted) {
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Call log deleted'),
                        backgroundColor: AppTheme.success,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
  
  // Helper to safely get avatar image
  ImageProvider? _getAvatarImage(bool hasDialled, Log log) {
    try {
      final String? avatarUrl = hasDialled ? log.receiverPic : log.callerPic;
      if (avatarUrl != null && avatarUrl.isNotEmpty && avatarUrl.startsWith('http')) {
        return CachedNetworkImageProvider(avatarUrl);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  getIcon(String? callStatus) {
    Icon _icon;
    double _iconSize = 18;
    
    // Normalize callStatus to lowercase for comparison
    final status = callStatus?.toLowerCase() ?? '';

    switch (status) {
      case 'dialled':
      case 'completed': // Legacy support
        _icon = Icon(
          Icons.call_made,
          size: _iconSize,
          color: AppTheme.success,
        );
        break;

      case 'missed':
        _icon = Icon(
          Icons.call_missed,
          color: AppTheme.error,
          size: _iconSize,
        );
        break;

      case 'received':
        _icon = Icon(
          Icons.call_received,
          size: _iconSize,
          color: AppTheme.accent,
        );
        break;

      default:
        _icon = Icon(
          Icons.call_received,
          size: _iconSize,
          color: Colors.grey,
        );
        break;
    }

    return Container(
      margin: const EdgeInsets.only(right: 5),
      child: _icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SingleChildScrollView(
        child: FutureBuilder<dynamic>(
          future: LogRepository.getLogs(),
          builder: (context, AsyncSnapshot snapshot) {
            if(snapshot.connectionState == ConnectionState.waiting){
              return const Center(
                child: CircularProgressIndicator(),
              );
            }
            if(snapshot.hasData) {
              // List<dynamic> list = snapshot.data;
              List<dynamic> logList = snapshot.data;
              if(logList.isNotEmpty) {
                return ListView.builder(
                  padding: const EdgeInsets.all(0),
                  shrinkWrap: true,
                  reverse: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: logList.length,
                    itemBuilder: (context, i) {
                      Log _log = logList[i];
                      // Check if current user made the call (dialled/completed = outgoing)
                      final status = _log.callStatus?.toLowerCase() ?? '';
                      bool hasDialled = status == "dialled" || status == "completed";
                      return GestureDetector(
                        onTap: () => _makeVideoCall(_log, hasDialled),
                        onLongPress: () {
                          HapticFeedback.mediumImpact();
                          _showCallLogOptions(_log, i, hasDialled);
                        },
                        child: Container(
                          margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            leading: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.grey.shade300,
                                  width: 2,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 24,
                                backgroundColor: AppTheme.gray200,
                                backgroundImage: _getAvatarImage(hasDialled, _log),
                                child: _getAvatarImage(hasDialled, _log) == null
                                    ? Icon(Icons.person, color: AppTheme.gray500, size: 24)
                                    : null,
                              ),
                            ),
                            title: Text(
                              hasDialled ? _log.receiverName! : _log.callerName!,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            subtitle: Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  getIcon(_log.callStatus),
                                  SizedBox(width: 4),
                                  Text(
                                    formatTimestampSafe(_log.timeStamp),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.gray600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.videocam,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                );
              }
              return Container();
            }
            return Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.call_outlined,
                      size: 64,
                      color: AppTheme.gray400,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No Call Logs',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.gray800,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Your call history will appear here',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.gray600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
