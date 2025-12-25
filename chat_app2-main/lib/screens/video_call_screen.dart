import 'package:my_porject/configs/app_theme.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../configs/agora_configs.dart';
import '../db/log_repository.dart';
import '../models/log_model.dart';

class VideoCallScreen extends StatefulWidget {
  final String channelName;
  final String userName;
  final String? userAvatar;  // Nullable
  final String calleeName;
  final String? calleeAvatar;  // Nullable
  final bool isGroupCall;
  final String? chatRoomId;  // For sending call message to chat
  final String? calleeUid;   // For identifying callee

  const VideoCallScreen({
    Key? key,
    required this.channelName,
    required this.userName,
    this.userAvatar,  // Optional
    required this.calleeName,
    this.calleeAvatar,  // Optional
    this.isGroupCall = false,
    this.chatRoomId,
    this.calleeUid,
  }) : super(key: key);

  @override
  _VideoCallScreenState createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  late RtcEngine _engine;
  int? _remoteUid;
  bool _localUserJoined = false;
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isSpeakerOn = true;
  bool _isFrontCamera = true;
  Timer? _callTimer;
  int _callDuration = 0;

  @override
  void initState() {
    super.initState();
    initAgora();
  }

  Future<void> initAgora() async {
    // Request permissions
    await [Permission.microphone, Permission.camera].request();

    // Create Agora engine
    _engine = createAgoraRtcEngine();
    
    await _engine.initialize(const RtcEngineContext(
      appId: APP_ID,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    // Register event handlers
    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint('🎥 VideoCall: Local user joined channel: ${connection.channelId}');
          setState(() {
            _localUserJoined = true;
          });
          _startCallTimer();
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint('🎥 VideoCall: Remote user $remoteUid joined');
          setState(() {
            _remoteUid = remoteUid;
          });
        },
        onUserOffline: (RtcConnection connection, int remoteUid,
            UserOfflineReasonType reason) {
          debugPrint('🎥 VideoCall: Remote user $remoteUid left channel');
          setState(() {
            _remoteUid = null;
          });
        },
        onError: (ErrorCodeType err, String msg) {
          debugPrint('🎥 VideoCall: Error: $err - $msg');
        },
      ),
    );

    // Enable video
    await _engine.enableVideo();
    await _engine.startPreview();

    // Join channel
    await _engine.joinChannel(
      token: '', // Use token server in production
      channelId: widget.channelName,
      uid: 0,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );
  }

  void _startCallTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _callDuration++;
      });
    });
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _dispose();
    super.dispose();
  }

  Future<void> _dispose() async {
    await _engine.leaveChannel();
    await _engine.release();
  }

  void _onToggleMute() async {
    setState(() {
      _isMuted = !_isMuted;
    });
    await _engine.muteLocalAudioStream(_isMuted);
  }

  void _onToggleCamera() async {
    setState(() {
      _isCameraOff = !_isCameraOff;
    });
    await _engine.muteLocalVideoStream(_isCameraOff);
  }

  void _onSwitchCamera() async {
    setState(() {
      _isFrontCamera = !_isFrontCamera;
    });
    await _engine.switchCamera();
  }

  void _onToggleSpeaker() async {
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
    await _engine.setEnableSpeakerphone(_isSpeakerOn);
  }

  void _onCallEnd() async {
    // Save call log to SQLite
    await _saveCallLog();
    
    // Send call message to chat
    await _sendCallMessageToChat();
    
    Navigator.pop(context);
  }

  /// Save call log to local SQLite database for Recent Calls
  Future<void> _saveCallLog() async {
    try {
      final log = Log(
        callerName: widget.userName,
        callerPic: widget.userAvatar ?? '',
        receiverName: widget.calleeName,
        receiverPic: widget.calleeAvatar ?? '',
        callStatus: _remoteUid != null ? 'Completed' : 'Missed',
        timeStamp: DateTime.now().toString(),
      );
      
      await LogRepository.addLogs(log);
      debugPrint('📞 VideoCall: Call log saved - Duration: ${_formatDuration(_callDuration)}');
    } catch (e) {
      debugPrint('❌ VideoCall: Error saving call log: $e');
    }
  }

  /// Send call message to chat screen
  Future<void> _sendCallMessageToChat() async {
    if (widget.chatRoomId == null) {
      debugPrint('⚠️ VideoCall: No chatRoomId provided, skipping chat message');
      return;
    }

    try {
      final firestore = FirebaseFirestore.instance;
      final callStatus = _remoteUid != null ? 'completed' : 'missed';
      final callMessage = _remoteUid != null 
          ? 'Video call - ${_formatDuration(_callDuration)}'
          : 'Missed video call';

      // Add call message to chat
      await firestore
          .collection('chatroom')
          .doc(widget.chatRoomId)
          .collection('chats')
          .add({
        'sendBy': widget.userName,
        'message': callMessage,
        'type': 'videocall',
        'callStatus': callStatus,
        'callDuration': _callDuration,
        'timeSpend': _callDuration,
        'time': '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
        'timeStamp': FieldValue.serverTimestamp(),
      });

      // Update last message in chatroom
      await firestore.collection('chatroom').doc(widget.chatRoomId).update({
        'lastMessage': callMessage,
        'type': 'videocall',
        'time': FieldValue.serverTimestamp(),
      });

      // Update chat history for both users
      if (widget.calleeUid != null) {
        // Update caller's chat history
        await firestore
            .collection('users')
            .doc(widget.calleeUid)
            .collection('chatHistory')
            .doc(widget.chatRoomId)
            .update({
          'lastMessage': callMessage,
          'time': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      }

      debugPrint('📞 VideoCall: Call message sent to chat - $callMessage');
    } catch (e) {
      debugPrint('❌ VideoCall: Error sending call message: $e');
    }
  }

  Widget _buildLocalPreview() {
    // ✅ FIX: Khi camera off, hiển thị avatar thay vì video
    if (!_localUserJoined || _isCameraOff) {
      return Container(
        color: Colors.black87,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Avatar with fallback
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.gray800,
                ),
                child: widget.userAvatar != null && widget.userAvatar!.isNotEmpty
                    ? ClipOval(
                        child: Image.network(
                          widget.userAvatar!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.person, size: 40, color: Colors.white70);
                          },
                        ),
                      )
                    : const Icon(Icons.person, size: 40, color: Colors.white70),
              ),
              const SizedBox(height: 8),
              // User name - compact for small preview
              Text(
                widget.userName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              // Camera off indicator
              if (_isCameraOff) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.videocam_off, size: 10, color: Colors.redAccent),
                      SizedBox(width: 4),
                      Text(
                        'Off',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
    // Normal case: Show video preview
    return AgoraVideoView(
      controller: VideoViewController(
        rtcEngine: _engine,
        canvas: const VideoCanvas(uid: 0),
      ),
    );
  }

  Widget _buildRemoteVideo() {
    if (_remoteUid != null) {
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: _engine,
          canvas: VideoCanvas(uid: _remoteUid),
          connection: RtcConnection(channelId: widget.channelName),
        ),
      );
    } else {
      // ✅ FIX: Waiting for remote user - show callee avatar
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Callee avatar with fallback
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.gray800,
                  border: Border.all(color: Colors.white24, width: 3),
                ),
                child: widget.calleeAvatar != null && widget.calleeAvatar!.isNotEmpty
                    ? ClipOval(
                        child: Image.network(
                          widget.calleeAvatar!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.person, size: 80, color: Colors.white70);
                          },
                        ),
                      )
                    : const Icon(Icons.person, size: 80, color: Colors.white70),
              ),
              const SizedBox(height: 24),
              Text(
                widget.calleeName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Calling...',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              // Animated waiting indicator
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.gray600!),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Remote video (full screen)
          _buildRemoteVideo(),

          // Local video (small preview in corner)
          Positioned(
            top: 50,
            right: 16,
            child: Container(
              width: 120,
              height: 160,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _buildLocalPreview(),
              ),
            ),
          ),

          // Top bar with user info and timer
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.only(top: 50, left: 16, right: 16, bottom: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.calleeName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _remoteUid != null
                            ? _formatDuration(_callDuration)
                            : 'Connecting...',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: _onSwitchCamera,
                    icon: const Icon(
                      Icons.flip_camera_ios,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom control buttons
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.only(bottom: 40, top: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.8),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mute button
                  _buildControlButton(
                    icon: _isMuted ? Icons.mic_off : Icons.mic,
                    onPressed: _onToggleMute,
                    isActive: _isMuted,
                  ),

                  // Camera button
                  _buildControlButton(
                    icon: _isCameraOff ? Icons.videocam_off : Icons.videocam,
                    onPressed: _onToggleCamera,
                    isActive: _isCameraOff,
                  ),

                  // Speaker button
                  _buildControlButton(
                    icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                    onPressed: _onToggleSpeaker,
                    isActive: !_isSpeakerOn,
                  ),

                  // End call button
                  _buildControlButton(
                    icon: Icons.call_end,
                    onPressed: _onCallEnd,
                    backgroundColor: AppTheme.error,
                    iconColor: Colors.white,
                    size: 64,
                    iconSize: 32,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    Color? backgroundColor,
    Color? iconColor,
    bool isActive = false,
    double size = 56,
    double iconSize = 28,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor ?? 
              (isActive ? Colors.white24 : Colors.white10),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: iconColor ?? 
              (isActive ? Colors.white70 : Colors.white),
          size: iconSize,
        ),
      ),
    );
  }
}
