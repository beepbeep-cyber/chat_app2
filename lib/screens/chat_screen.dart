import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:grouped_list/grouped_list.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:my_porject/resources/methods.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:my_porject/models/user_model.dart';
import 'package:my_porject/services/encrypted_chat_service.dart';
import 'package:my_porject/services/voice_message_service.dart';
import 'package:my_porject/services/file_sharing_service.dart';
import 'package:my_porject/widgets/voice_message_player.dart';
import 'package:my_porject/widgets/file_message_widget.dart';
import 'package:my_porject/widgets/video_call_message_widget.dart';
import 'package:my_porject/screens/chat_settings_screen.dart';
import 'package:my_porject/screens/video_call_screen.dart';
import 'package:my_porject/services/auto_delete_service.dart';
import 'package:my_porject/utils/loading_utils.dart';
import 'package:my_porject/configs/app_theme.dart';
import 'package:my_porject/widgets/animated_avatar.dart';
import 'package:my_porject/widgets/page_transitions.dart';


// ignore: must_be_immutable
class ChatScreen extends StatefulWidget {
  Map<String, dynamic> userMap;

  late String chatRoomId;

  bool isDeviceConnected;

  User user;

  ChatScreen({
    key,
    required this.chatRoomId,
    required this.userMap,
    required this.user,
    required this.isDeviceConnected,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _message = TextEditingController();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  late String email = widget.userMap['email'];

  bool isLoading = false;

  // Cache for decrypted messages to prevent re-decryption
  final Map<String, String> _decryptedMessagesCache = {};
  // Cache for Future objects to prevent FutureBuilder rebuild flickering
  final Map<String, Future<String>> _decryptionFuturesCache = {};

  // Auto Delete Service
  final AutoDeleteService _autoDeleteService = AutoDeleteService();
  bool _autoDeleteEnabled = false;
  int _autoDeleteDuration = 0;

  // Optimized: Limit messages for better performance
  static const int _messageLimit = 50; // Load max 50 messages initially

  // Helper function to format call duration in seconds to readable format
  String _formatCallDuration(dynamic seconds) {
    if (seconds == null) return '';
    final int secs = seconds is int ? seconds : int.tryParse(seconds.toString()) ?? 0;
    if (secs < 60) return '${secs}s';
    final int mins = secs ~/ 60;
    final int remainingSecs = secs % 60;
    if (mins < 60) return '${mins}m ${remainingSecs}s';
    final int hours = mins ~/ 60;
    final int remainingMins = mins % 60;
    return '${hours}h ${remainingMins}m';
  }

  // Helper function to format Timestamp to readable time string
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    
    // If already a String, return it
    if (timestamp is String) return timestamp;
    
    // If it's a Firestore Timestamp, convert it
    if (timestamp is Timestamp) {
      final DateTime dateTime = timestamp.toDate();
      final String hour = dateTime.hour.toString().padLeft(2, '0');
      final String minute = dateTime.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }
    
    // If it's a DateTime
    if (timestamp is DateTime) {
      final String hour = timestamp.hour.toString().padLeft(2, '0');
      final String minute = timestamp.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }
    
    return '';
  }

  @override
  void initState() {
    getConnectivity();
    focusNode.addListener(() {
      if (focusNode.hasFocus) {
        setState(() {
          showEmoji = false;
        });
      }
    });
    updateIsReadMessage();
    getUserInfo();
    _initAutoDelete(); // Khởi động auto delete service
    super.initState();
  }

  /// Khởi động Auto Delete Service cho chatroom này
  Future<void> _initAutoDelete() async {
    // Bắt đầu monitoring auto-delete cho chatroom
    await _autoDeleteService.startMonitoring(widget.chatRoomId);
    
    // Lấy cài đặt hiện tại để hiển thị indicator
    final settings = await _autoDeleteService.getAutoDeleteSettings(widget.chatRoomId);
    if (settings != null && mounted) {
      setState(() {
        _autoDeleteEnabled = settings['enabled'] ?? false;
        _autoDeleteDuration = settings['duration'] ?? 0;
      });
    }
    
    // Lắng nghe thay đổi cài đặt
    _firestore.collection('chatroom').doc(widget.chatRoomId).snapshots().listen((snapshot) {
      if (snapshot.exists && mounted) {
        final data = snapshot.data()!;
        setState(() {
          _autoDeleteEnabled = data['autoDeleteEnabled'] ?? false;
          _autoDeleteDuration = data['autoDeleteDuration'] ?? 0;
        });
      }
    });
  }

  @override
  void dispose() {
    controller.dispose();
    updateIsReadMessage();
    // Dừng auto delete service khi rời khỏi chat
    _autoDeleteService.stopMonitoring(widget.chatRoomId);
    super.dispose();
  }

  updateIsReadMessage() async {
    await _firestore
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .collection('chatHistory')
        .doc(widget.userMap['uid'])
        .update({
      'isRead': true,
    });
  }

  late StreamSubscription subscription;

  getConnectivity() async {
    return subscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) async {
      widget.isDeviceConnected = await InternetConnection().hasInternetAccess;
      if (mounted) {
        setState(() {});
      }
    });
  }

  late Userr receiver;
  late Userr sender;
  late String lat;
  late String long;

  // Helper method to get decrypted message text with caching
  Future<String> _getMessageText(Map<String, dynamic> map, String messageId) async {
    if (map['encrypted'] == true) {
      // Check result cache first (instant return)
      if (_decryptedMessagesCache.containsKey(messageId)) {
        return _decryptedMessagesCache[messageId]!;
      }
      
      // Decrypt and cache
      final decryptedText = await EncryptedChatService.decryptMessage(map);
      _decryptedMessagesCache[messageId] = decryptedText;
      return decryptedText;
    }
    return map['message'] ?? '';
  }

  // Get cached Future for FutureBuilder to prevent flickering
  Future<String> _getCachedMessageFuture(Map<String, dynamic> map, String messageId) {
    // If already have result, return completed future immediately
    if (_decryptedMessagesCache.containsKey(messageId)) {
      return Future.value(_decryptedMessagesCache[messageId]!);
    }
    
    // If Future already in progress, return same Future (prevents duplicate decryption)
    if (_decryptionFuturesCache.containsKey(messageId)) {
      return _decryptionFuturesCache[messageId]!;
    }
    
    // Create new Future and cache it
    final future = _getMessageText(map, messageId);
    _decryptionFuturesCache[messageId] = future;
    return future;
  }

  showDialogInternetCheck() => showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.grey[700], size: 28),
                const SizedBox(width: 12),
                Text(
                  'No Connection',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[900],
                  ),
                ),
              ],
            ),
            content: Text(
              'Please check your internet connectivity and try again.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
            actions: <Widget>[
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context, 'OK');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('OK', style: TextStyle(fontSize: 15)),
              ),
            ],
          ));

  void getUserInfo() async {
    receiver = Userr(
      uid: widget.userMap['uid'],
      name: widget.userMap['name'],
      avatar: widget.userMap['avatar'],
      email: widget.userMap['email'],
      status: widget.userMap['status'],
    );
    await _firestore
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .get()
        .then((value) {
      Map<String, dynamic>? map = value.data();
      sender = Userr(
        uid: map!['uid'],
        name: map['name'],
        email: map['email'],
        avatar: map['avatar'],
        status: map['status'],
      );
    });
  }

  void onSendMessage() async {
    String message;
    message = _message.text;
    setState(() {
      _message.clear();
    });
    if (message.isNotEmpty) {
      // Try to send encrypted message
      final canEncrypt =
          await EncryptedChatService.canEncryptChat(widget.userMap['uid']);

      bool sent = false;
      if (canEncrypt) {
        // Send encrypted message
        sent = await EncryptedChatService.sendEncryptedMessage(
          recipientUid: widget.userMap['uid'],
          message: message,
          chatRoomId: widget.chatRoomId,
          additionalData: {
            'time': timeForMessage(DateTime.now().toString()),
          },
        );
      }

      // Fallback to unencrypted if encryption not available
      if (!sent) {
        Map<String, dynamic> messages = {
          'sendBy': _auth.currentUser!.displayName,
          'message': message,
          'encrypted': false,
          'type': "text",
          'time': timeForMessage(DateTime.now().toString()),
          'timeStamp': DateTime.now(),
        };
        await _firestore
            .collection('chatroom')
            .doc(widget.chatRoomId)
            .collection('chats')
            .add(messages);
      }
      await _firestore.collection('chatroom').doc(widget.chatRoomId).set({
        'user1': widget.user.displayName,
        'user2': widget.userMap['name'],
        'lastMessage': message,
        'type': "text",
      });
      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('chatHistory')
          .doc(widget.userMap['uid'])
          .set({
        'lastMessage': "Bạn: $message",
        'type': "text",
        'name': widget.userMap['name'],
        'time': timeForMessage(DateTime.now().toString()),
        'uid': widget.userMap['uid'],
        'avatar': widget.userMap['avatar'],
        'status': widget.userMap['status'],
        'datatype': 'p2p',
        'timeStamp': DateTime.now(),
        'isRead': true,
      });
      String? currentUserAvatar;
      String? status;
      await _firestore
          .collection("users")
          .where("email", isEqualTo: _auth.currentUser!.email)
          .get()
          .then((value) {
        currentUserAvatar = value.docs[0]['avatar'];
        status = value.docs[0]['status'];
      });
      await _firestore
          .collection('users')
          .doc(widget.userMap['uid'])
          .collection('chatHistory')
          .doc(_auth.currentUser!.uid)
          .set({
        'lastMessage': message,
        'type': "text",
        'name': widget.user.displayName,
        'time': timeForMessage(DateTime.now().toString()),
        'uid': _auth.currentUser!.uid,
        'avatar': currentUserAvatar,
        'status': status,
        'datatype': 'p2p',
        'timeStamp': DateTime.now(),
        'isRead': false,
      });
    } else {
      if (kDebugMode) { debugPrint("Enter some text"); }
    }
  }

  File? imageFile;

  Future getImage() async {
    ImagePicker _picker = ImagePicker();

    await _picker.pickImage(source: ImageSource.gallery).then((xFile) {
      if (xFile != null) {
        imageFile = File(xFile.path);
        uploadImage();
      }
    });
  }

  Future uploadImage() async {
    String fileName = const Uuid().v1();

    int status = 1;

    await _firestore
        .collection('chatroom')
        .doc(widget.chatRoomId)
        .collection('chats')
        .doc(fileName)
        .set({
      'sendBy': widget.user.displayName,
      'message': _message.text,
      'type': "img",
      'time': timeForMessage(DateTime.now().toString()),
      'timeStamp': DateTime.now(),
    });

    var ref =
        FirebaseStorage.instance.ref().child('images').child("$fileName.jpg");

    var uploadTask = await ref.putFile(imageFile!).catchError((error) async {
      await _firestore
          .collection('chatroom')
          .doc(widget.chatRoomId)
          .collection('chats')
          .doc(fileName)
          .delete();
      status = 0;
    });

    if (status == 1) {
      String imageUrl = await uploadTask.ref.getDownloadURL();

      await _firestore
          .collection('chatroom')
          .doc(widget.chatRoomId)
          .collection('chats')
          .doc(fileName)
          .update({
        'message': imageUrl,
      });
      await _firestore.collection('chatroom').doc(widget.chatRoomId).set({
        'user1': widget.user.displayName,
        'user2': widget.userMap['name'],
        'lastMessage': "Bạn đã gửi 1 ảnh",
        'type': "img",
        'uid': widget.userMap['uid'],
      });
      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('chatHistory')
          .doc(widget.userMap['uid'])
          .set({
        'lastMessage': "Bạn đã gửi 1 ảnh",
        'type': "img",
        'name': widget.userMap['name'],
        'time': timeForMessage(DateTime.now().toString()),
        'uid': widget.userMap['uid'],
        'avatar': widget.userMap['avatar'],
        'status': widget.userMap['status'],
        'datatype': 'p2p',
        'timeStamp': DateTime.now(),
        'isRead': true,
      });
      String? currentUserAvatar;
      String? status;
      await _firestore
          .collection("users")
          .where("email", isEqualTo: _auth.currentUser!.email)
          .get()
          .then((value) {
        currentUserAvatar = value.docs[0]['avatar'];
        status = value.docs[0]['status'];
      });
      await _firestore
          .collection('users')
          .doc(widget.userMap['uid'])
          .collection('chatHistory')
          .doc(_auth.currentUser!.uid)
          .set({
        'lastMessage': "${widget.user.displayName} đã gửi 1 ảnh",
        'type': "img",
        'name': widget.user.displayName,
        'time': timeForMessage(DateTime.now().toString()),
        'uid': _auth.currentUser!.uid,
        'avatar': currentUserAvatar,
        'status': status,
        'datatype': 'p2p',
        'timeStamp': DateTime.now(),
        'isRead': false,
      });
    }
  }

  late ScrollController controller = ScrollController();
  late int index;

  /// Open camera and capture photo to send
  Future<void> _openCamera() async {
    try {
      if (widget.isDeviceConnected == false) {
        showDialogInternetCheck();
        return;
      }

      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (photo == null) {
        debugPrint('📷 Camera: No photo captured');
        return;
      }

      debugPrint('📷 Camera: Photo captured: ${photo.path}');

      // Show loading overlay
      if (mounted) {
        LoadingUtils.show(context, message: 'Sending photo...');
      }

      // Upload photo
      imageFile = File(photo.path);
      await _uploadCameraPhoto();

      // Hide loading overlay
      LoadingUtils.hide();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Photo sent successfully!'),
              ],
            ),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if open
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      debugPrint('❌ Camera error: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Failed to send photo. Please try again.')),
              ],
            ),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Upload camera photo to Firebase Storage
  Future<void> _uploadCameraPhoto() async {
    if (imageFile == null) return;
    
    String fileName = const Uuid().v1();
    int status = 1;

    // Create placeholder message
    await _firestore
        .collection('chatroom')
        .doc(widget.chatRoomId)
        .collection('chats')
        .doc(fileName)
        .set({
      'sendBy': widget.user.displayName,
      'message': 'Uploading photo...',
      'type': "img",
      'time': timeForMessage(DateTime.now().toString()),
      'timeStamp': DateTime.now(),
    });

    // Upload to Firebase Storage
    var ref = FirebaseStorage.instance
        .ref()
        .child('camera_photos')
        .child("$fileName.jpg");

    var uploadTask = await ref.putFile(imageFile!).catchError((error) async {
      await _firestore
          .collection('chatroom')
          .doc(widget.chatRoomId)
          .collection('chats')
          .doc(fileName)
          .delete();
      status = 0;
      throw error;
    });

    if (status == 1) {
      String imageUrl = await uploadTask.ref.getDownloadURL();

      // Update message with actual image URL
      await _firestore
          .collection('chatroom')
          .doc(widget.chatRoomId)
          .collection('chats')
          .doc(fileName)
          .update({
        'message': imageUrl,
      });

      // Update chatroom info
      await _firestore.collection('chatroom').doc(widget.chatRoomId).set({
        'user1': widget.user.displayName,
        'user2': widget.userMap['name'],
        'lastMessage': "📷 Photo",
        'type': "img",
        'uid': widget.userMap['uid'],
      }, SetOptions(merge: true));

      // Update sender's chat history
      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('chatHistory')
          .doc(widget.userMap['uid'])
          .set({
        'lastMessage': "📷 You sent a photo",
        'type': "img",
        'name': widget.userMap['name'],
        'time': timeForMessage(DateTime.now().toString()),
        'uid': widget.userMap['uid'],
        'avatar': widget.userMap['avatar'],
        'status': widget.userMap['status'],
        'datatype': 'p2p',
        'timeStamp': DateTime.now(),
        'isRead': true,
      });

      // Get current user info for receiver's chat history
      String? currentUserAvatar;
      String? userStatus;
      await _firestore
          .collection("users")
          .where("email", isEqualTo: _auth.currentUser!.email)
          .get()
          .then((value) {
        if (value.docs.isNotEmpty) {
          currentUserAvatar = value.docs[0]['avatar'];
          userStatus = value.docs[0]['status'];
        }
      });

      // Update receiver's chat history
      await _firestore
          .collection('users')
          .doc(widget.userMap['uid'])
          .collection('chatHistory')
          .doc(_auth.currentUser!.uid)
          .set({
        'lastMessage': "📷 ${widget.user.displayName} sent a photo",
        'type': "img",
        'name': widget.user.displayName,
        'time': timeForMessage(DateTime.now().toString()),
        'uid': _auth.currentUser!.uid,
        'avatar': currentUserAvatar,
        'status': userStatus,
        'datatype': 'p2p',
        'timeStamp': DateTime.now(),
        'isRead': false,
      });
    }
  }

  void liveLocation() {
    LocationSettings locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high, distanceFilter: 100);

    Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      lat = position.latitude.toString();
      long = position.longitude.toString();
    });
  }

  int limit = 20;
  Future<void> abc() async {
    setState(() {
      limit += 20;
    });
  }

  FocusNode focusNode = FocusNode();

  bool showEmoji = false;
  Widget showEmojiPicker() {
    return SizedBox(
      height: 250,
      child: EmojiPicker(
        config: const Config(
            ),
        onEmojiSelected: (emoji, category) {
          _message.text = _message.text + category.emoji;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: AppTheme.backgroundLight,
        appBar: AppBar(
          automaticallyImplyLeading: false, // Disable default back button
          backgroundColor: AppTheme.primaryDark,
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.3),
          flexibleSpace: SafeArea(
            child: Container(
              padding: const EdgeInsets.only(right: 10),
              child: Row(
                children: <Widget>[
                  IconButton(
                    onPressed: () async {
                      Navigator.pop(context);
                    },
                    icon: const Icon(
                      Icons.arrow_back_ios,
                      color: AppTheme.textWhite,
                      size: 22,
                    ),
                  ),
                  const SizedBox(
                    width: 2,
                  ),
                  AnimatedAvatar(
                    imageUrl: widget.userMap['avatar'],
                    name: widget.userMap['name'] ?? 'User',
                    size: 40,
                    isOnline: false,
                    showStatus: false,
                  ),
                  const SizedBox(
                    width: 12,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          widget.userMap['name'] ?? 'Unknown',
                          style: AppTheme.titleMedium.copyWith(
                            color: AppTheme.textWhite,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(
                          height: 4,
                        ),
                        StreamBuilder<DocumentSnapshot>(
                          stream: _firestore
                              .collection("users")
                              .doc(widget.userMap['uid'])
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.data != null) {
                              return Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: snapshot.data!['status'].toLowerCase().contains('online') 
                                          ? AppTheme.online 
                                          : AppTheme.offline,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    snapshot.data!['status'],
                                    style: const TextStyle(
                                      color: AppTheme.textHint,
                                      fontSize: 13,
                                    ),
                                  ),
                                  // Auto-delete indicator
                                  if (_autoDeleteEnabled) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.auto_delete,
                                            color: Colors.orange[300],
                                            size: 12,
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            AutoDeleteService.formatDuration(_autoDeleteDuration),
                                            style: TextStyle(
                                              color: Colors.orange[300],
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              );
                            } else {
                              return const Text('');
                            }
                          },
                        )
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      if (widget.isDeviceConnected == false) {
                        showDialogInternetCheck();
                      } else {
                        // Generate unique channel name for this call
                        final channelName = '${widget.chatRoomId}_${DateTime.now().millisecondsSinceEpoch}';
                        
                        Navigator.push(
                          context,
                          SlideRightRoute(
                            page: VideoCallScreen(
                              channelName: channelName,
                              userName: widget.user.displayName ?? 'You',
                              userAvatar: widget.user.photoURL,
                              calleeName: widget.userMap['name'] ?? 'Unknown',
                              calleeAvatar: widget.userMap['avatar'] ?? widget.userMap['image'],
                              chatRoomId: widget.chatRoomId,
                              calleeUid: widget.userMap['uid'],
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(
                      Icons.video_call_outlined,
                      color: AppTheme.textWhite,
                      size: 28,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        SlideRightRoute(
                          page: ChatSettingsScreen(
                            chatRoomId: widget.chatRoomId,
                            userMap: widget.userMap,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.settings_outlined,
                      color: AppTheme.textWhite,
                      size: 26,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: isLoading
            ? Container(
                height: size.height,
                width: size.width,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(),
              )
            : RefreshIndicator(
                onRefresh: () {
                  return abc();
                },
                child: Column(
                  children: <Widget>[
                    widget.isDeviceConnected == false
                        ? Container(
                            alignment: Alignment.center,
                            width: MediaQuery.of(context).size.width,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.wifi_off, color: Colors.grey[700], size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  'No Internet Connection',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[800],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Container(),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        // Optimized: Limit messages to improve performance
                        stream: _firestore
                            .collection('chatroom')
                            .doc(widget.chatRoomId)
                            .collection('chats')
                            .orderBy('timeStamp', descending: true)
                            .limit(_messageLimit)
                            .snapshots(),
                        builder: (BuildContext context,
                            AsyncSnapshot<QuerySnapshot> snapshot) {
                          // Only auto-scroll when messages change, not on every rebuild
                          if (snapshot.hasData) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (controller.hasClients && 
                                  controller.position.pixels < controller.position.maxScrollExtent - 100) {
                                controller.animateTo(
                                  controller.position.maxScrollExtent,
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeOut,
                                );
                              }
                            });
                          }
                          if (snapshot.data != null) {
                            return GroupedListView<
                                QueryDocumentSnapshot<Object?>, String>(
                              elements: snapshot.data?.docs
                                  as List<QueryDocumentSnapshot<Object?>>,
                              shrinkWrap: true,
                              groupBy: (element) {
                                // Handle mixed time types (String, Timestamp, DateTime)
                                final timeValue = element['time'];
                                if (timeValue is String) {
                                  return timeValue;
                                } else if (timeValue is Timestamp) {
                                  final dateTime = timeValue.toDate();
                                  return timeForMessage(dateTime.toString());
                                } else if (timeValue is DateTime) {
                                  return timeForMessage(timeValue.toString());
                                } else {
                                  return timeForMessage(DateTime.now().toString());
                                }
                              },
                              order: GroupedListOrder.ASC,
                              reverse: false,
                              padding: const EdgeInsets.only(bottom: 80), // Add padding to prevent input box from covering last message
                              groupSeparatorBuilder: (String groupByValue) =>
                                  Container(
                                alignment: Alignment.center,
                                margin: const EdgeInsets.symmetric(vertical: 12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    formatTimestampSafe(groupByValue),
                                    style: TextStyle(
                                        color: Colors.grey[700],
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ),
                              indexedItemBuilder: (context, element, index) {
                                Map<String, dynamic> map =
                                    element.data() as Map<String, dynamic>;
                                return messages(
                                    size,
                                    map,
                                    widget.userMap,
                                    index,
                                    snapshot.data?.docs.length as int,
                                    context,
                                    element.id); // Pass document ID for caching
                              },
                              controller: controller,
                            );
                          } else {
                            return Container();
                          }
                        },
                      ),
                    ),
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border(
                              top: BorderSide(color: Colors.grey[200]!, width: 0.5),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: <Widget>[
                                // Attachment menu button
                                IconButton(
                                  onPressed: () {
                                    _showAttachmentMenu();
                                  },
                                  icon: Icon(
                                    Icons.add_circle_outline,
                                    color: Colors.grey[600],
                                  ),
                                  iconSize: 28,
                                  padding: const EdgeInsets.all(6),
                                  constraints: const BoxConstraints(
                                    minWidth: 40,
                                    minHeight: 40,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Text input field - Modern redesign
                                Expanded(
                                  child: Container(
                                    constraints: const BoxConstraints(
                                      minHeight: 48,
                                      maxHeight: 120,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: Colors.grey[300]!,
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.withValues(alpha: 0.08),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        const SizedBox(width: 4),
                                        // Emoji button - moved to left
                                        IconButton(
                                          onPressed: () {
                                            setState(() {
                                              focusNode.unfocus();
                                              focusNode.canRequestFocus = false;
                                              showEmoji = !showEmoji;
                                            });
                                          },
                                          icon: Icon(
                                            showEmoji 
                                              ? Icons.keyboard_rounded
                                              : Icons.emoji_emotions_rounded,
                                            color: Colors.grey[700],
                                          ),
                                          iconSize: 26,
                                          padding: const EdgeInsets.all(8),
                                          constraints: const BoxConstraints(
                                            minWidth: 40,
                                            minHeight: 40,
                                          ),
                                        ),
                                        // Text input
                                        Expanded(
                                          child: TextField(
                                            focusNode: focusNode,
                                            controller: _message,
                                            maxLines: null,
                                            textInputAction: TextInputAction.newline,
                                            style: TextStyle(
                                              color: Colors.grey[900],
                                              fontSize: 16,
                                              height: 1.5,
                                              fontWeight: FontWeight.w400,
                                            ),
                                            decoration: InputDecoration(
                                              hintText: "Type a message...",
                                              hintStyle: TextStyle(
                                                color: Colors.grey[500],
                                                fontSize: 16,
                                                fontWeight: FontWeight.w400,
                                              ),
                                              filled: false,
                                              contentPadding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 12,
                                              ),
                                              border: InputBorder.none,
                                              enabledBorder: InputBorder.none,
                                              focusedBorder: InputBorder.none,
                                              isDense: false,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Voice/Send button with ValueListenableBuilder to prevent flickering
                                ValueListenableBuilder<TextEditingValue>(
                                  valueListenable: _message,
                                  builder: (context, value, child) {
                                    return Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[800],
                                        shape: BoxShape.circle,
                                      ),
                                      child: IconButton(
                                        onPressed: () {
                                          if (value.text.trim().isNotEmpty) {
                                            onSendMessage();
                                          } else {
                                            _showVoiceRecording();
                                          }
                                        },
                                        icon: Icon(
                                          value.text.trim().isNotEmpty
                                            ? Icons.send
                                            : Icons.mic,
                                          color: Colors.white,
                                        ),
                                        iconSize: 22,
                                        padding: EdgeInsets.zero,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                        ),
                      ],
                    ),
                    showEmoji ? showEmojiPicker() : Container(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget messages(
      Size size,
      Map<String, dynamic> map,
      Map<String, dynamic> userMap,
      int index,
      int length,
      BuildContext context,
      String messageId) {
    if (map['status'] == 'removed') {
      return Row(
        children: [
          const SizedBox(
            width: 2,
          ),
          map['sendBy'] != widget.user.displayName
              ? SizedBox(
                  height: size.width / 13,
                  width: size.width / 13,
                  child: CircleAvatar(
                    backgroundImage: NetworkImage(userMap['avatar']),
                    maxRadius: 30,
                  ),
                )
              : Container(),
          GestureDetector(
            onLongPress: () {},
            child: Container(
              width: map['sendBy'] == widget.user.displayName
                  ? size.width * 0.98
                  : size.width * 0.7,
              alignment: map['sendBy'] == widget.user.displayName
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Container(
                constraints: BoxConstraints(maxWidth: size.width / 1.5),
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  color: Colors.grey.shade200,
                ),
                child: Text(
                  map['message'],
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 17,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      if (map['type'] == "text") {
        return Row(
          children: [
            const SizedBox(
              width: 2,
            ),
            map['sendBy'] != widget.user.displayName
                ? SizedBox(
                    height: size.width / 13,
                    width: size.width / 13,
                    child: CircleAvatar(
                      backgroundImage: NetworkImage(userMap['avatar']),
                      maxRadius: 30,
                    ),
                  )
                : Container(),
            GestureDetector(
              onLongPress: () {
                if (map['sendBy'] == widget.user.displayName) {
                  changeMessage(index, length, map['message'], map['type']);
                }
              },
              child: Container(
                width: map['sendBy'] == widget.user.displayName
                    ? size.width * 0.98
                    : size.width * 0.7,
                alignment: map['sendBy'] == widget.user.displayName
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  constraints: BoxConstraints(maxWidth: size.width / 1.5),
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                  margin:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  decoration: BoxDecoration(
                    borderRadius: map['sendBy'] == widget.user.displayName
                        ? const BorderRadius.only(
                            topLeft: Radius.circular(18),
                            topRight: Radius.circular(18),
                            bottomLeft: Radius.circular(18),
                            bottomRight: Radius.circular(4),
                          )
                        : const BorderRadius.only(
                            topLeft: Radius.circular(18),
                            topRight: Radius.circular(18),
                            bottomLeft: Radius.circular(4),
                            bottomRight: Radius.circular(18),
                          ),
                    color: map['sendBy'] == widget.user.displayName
                        ? AppTheme.sentBubble
                        : AppTheme.receivedBubble,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.15),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: FutureBuilder<String>(
                    future: _getCachedMessageFuture(map, messageId),
                    builder: (context, snapshot) {
                      // Show loading only if no cached data available
                      if (snapshot.connectionState == ConnectionState.waiting && 
                          !_decryptedMessagesCache.containsKey(messageId)) {
                        return Text(
                          'Decrypting...',
                          style: TextStyle(
                              color: map['sendBy'] == widget.user.displayName
                                  ? AppTheme.textWhite.withValues(alpha: 0.7)
                                  : Colors.grey[600],
                              fontSize: 15,
                              fontStyle: FontStyle.italic),
                        );
                      }
                      // Use cached data if available, otherwise use snapshot data
                      final messageText = _decryptedMessagesCache[messageId] ?? 
                                          snapshot.data ?? 
                                          map['message'] ?? '';
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (map['encrypted'] == true)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Icon(Icons.lock_outline,
                                  color: map['sendBy'] == widget.user.displayName
                                      ? Colors.green[300]
                                      : Colors.green[600],
                                  size: 14),
                            ),
                          Flexible(
                            child: Text(
                              messageText,
                              style: TextStyle(
                                  color: map['sendBy'] == widget.user.displayName
                                      ? Colors.white
                                      : Colors.grey[900],
                                  fontSize: 16),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      } else if (map['type'] == "img") {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const SizedBox(
              width: 2,
            ),
            map['sendBy'] != widget.user.displayName
                ? Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    height: size.width / 13,
                    width: size.width / 13,
                    child: CircleAvatar(
                      backgroundImage: userMap['avatar'] != null && userMap['avatar'].toString().isNotEmpty
                          ? CachedNetworkImageProvider(userMap['avatar'])
                          : null,
                      backgroundColor: Colors.grey.shade300,
                      maxRadius: 30,
                      child: userMap['avatar'] == null || userMap['avatar'].toString().isEmpty
                          ? Icon(Icons.person, color: Colors.grey.shade600, size: 20)
                          : null,
                    ),
                  )
                : Container(),
            GestureDetector(
              onLongPress: () {
                if (map['sendBy'] == widget.user.displayName) {
                  changeMessage(index, length, map['message'], map['type']);
                }
              },
              child: Container(
                height: size.height / 2.5,
                width: map['sendBy'] == widget.user.displayName
                    ? size.width * 0.98
                    : size.width * 0.77,
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                alignment: map['sendBy'] == widget.user.displayName
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: InkWell(
                  onTap: () => Navigator.of(context).push(
                    SlideRightRoute(
                        page: ShowImage(
                              imageUrl: map['message'],
                              isDeviceConnected: widget.isDeviceConnected,
                            )),
                  ),
                  child: Container(
                    height: size.height / 2.5,
                    width: size.width / 2,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.grey.shade300,
                    ),
                    alignment:
                        map['message'] != "" && widget.isDeviceConnected == true
                            ? null
                            : Alignment.center,
                    child:
                        map['message'] != "" && widget.isDeviceConnected == true
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(18.0),
                                child: CachedNetworkImage(
                                  fit: BoxFit.cover,
                                  imageUrl: map['message'],
                                  memCacheWidth: 400, // Optimize memory usage
                                  memCacheHeight: 400,
                                  fadeInDuration: const Duration(milliseconds: 200),
                                  placeholder: (context, url) => Container(
                                    color: Colors.grey.shade200,
                                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                  ),
                                ))
                            : const CircularProgressIndicator(),
                  ),
                ),
              ),
            ),
          ],
        );
      } else if (map['type'] == "videocall") {
        // Premium Video Call Message Widget
        return VideoCallMessageWidget(
          messageData: map,
          userMap: userMap,
          currentUserName: widget.user.displayName ?? '',
          onLongPress: () {
            if (map['sendBy'] == widget.user.displayName) {
              changeMessage(index, length, map['message'], map['type']);
            }
          },
          onTap: map['callStatus'] == 'missed' ? () {
            // Navigate to video call screen for callback
            Navigator.push(
              context,
              SlideRightRoute(
                page: VideoCallScreen(
                  channelName: widget.chatRoomId,
                  userName: widget.user.displayName ?? '',
                  userAvatar: widget.user.photoURL,
                  calleeName: widget.userMap['name'] ?? '',
                  calleeAvatar: widget.userMap['avatar'],
                  chatRoomId: widget.chatRoomId,
                  calleeUid: widget.userMap['uid'],
                ),
              ),
            );
          } : null,
        );
      } else if (map['type'] == 'location') {
        bool isMe = map['sendBy'] == widget.user.displayName;
        return Container(
          margin: EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isMe) ...[
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.grey.shade300,
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    backgroundImage: userMap['avatar'] != null && userMap['avatar'].toString().isNotEmpty
                        ? CachedNetworkImageProvider(userMap['avatar'])
                        : null,
                    backgroundColor: Colors.grey.shade300,
                    radius: 16,
                    child: userMap['avatar'] == null || userMap['avatar'].toString().isEmpty
                        ? Icon(Icons.person, color: Colors.grey.shade600, size: 14)
                        : null,
                  ),
                ),
                SizedBox(width: 8),
              ],
              Flexible(
                child: GestureDetector(
                  onLongPress: () {
                    if (isMe) {
                      changeMessage(index, length, map['message'], map['type']);
                    }
                  },
                  child: Container(
                    constraints: BoxConstraints(maxWidth: size.width * 0.65),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: isMe ? Colors.blue : Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isMe 
                                      ? Colors.white.withValues(alpha: 0.2)
                                      : Colors.blue.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.my_location,
                                  color: isMe ? Colors.white : Colors.blue,
                                  size: 18,
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Live Location",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: isMe ? Colors.white : Colors.grey[800],
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: Colors.green,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          "Sharing now",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isMe ? Colors.white.withValues(alpha: 0.8) : Colors.grey[600],
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
                        GestureDetector(
                          onTap: () {
                            if (isMe) {
                              openMap(lat, long);
                            } else {
                              takeUserLocation();
                            }
                          },
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isMe 
                                  ? Colors.white.withValues(alpha: 0.15)
                                  : Colors.blue.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(16),
                                bottomRight: Radius.circular(16),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.map_outlined,
                                  size: 16,
                                  color: isMe ? Colors.white : Colors.blue,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  "View Location",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isMe ? Colors.white : Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      } else if (map['type'] == 'voice') {
        bool isMe = map['sendBy'] == widget.user.displayName;
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isMe) ...[ 
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.grey.shade300,
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    backgroundImage: userMap['avatar'] != null && userMap['avatar'].toString().isNotEmpty
                        ? CachedNetworkImageProvider(userMap['avatar'])
                        : null,
                    backgroundColor: Colors.grey.shade300,
                    radius: 16,
                    child: userMap['avatar'] == null || userMap['avatar'].toString().isEmpty
                        ? Icon(Icons.person, color: Colors.grey.shade600, size: 14)
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,  // ✅ Max 75% screen width
                  ),
                  child: Column(
                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      VoiceMessagePlayer(
                        audioUrl: map['message'],
                        isMe: isMe,
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          _formatTimestamp(map['time']),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      } else if (map['type'] == 'file') {
        bool isMe = map['sendBy'] == widget.user.displayName;
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isMe) ...[ 
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.grey.shade300,
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    backgroundImage: userMap['avatar'] != null && userMap['avatar'].toString().isNotEmpty
                        ? CachedNetworkImageProvider(userMap['avatar'])
                        : null,
                    backgroundColor: Colors.grey.shade300,
                    radius: 16,
                    child: userMap['avatar'] == null || userMap['avatar'].toString().isEmpty
                        ? Icon(Icons.person, color: Colors.grey.shade600, size: 14)
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75, // 75% of screen width
                  ),
                  child: Column(
                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      FileMessageWidget(
                        fileUrl: map['message'],
                        fileName: map['fileName'] ?? 'Unknown file',
                        fileSize: map['fileSize'] ?? 0,
                        fileExtension: map['fileExtension'] ?? 'bin',
                        isMe: isMe,
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          _formatTimestamp(map['time']),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      } else if (map['type'] == 'locationed') {
        bool isMe = map['sendBy'] == widget.user.displayName;
        return Container(
          margin: EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isMe) ...[
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.grey.shade300,
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    backgroundImage: NetworkImage(userMap['avatar']),
                    radius: 16,
                  ),
                ),
                SizedBox(width: 8),
              ],
              Flexible(
                child: GestureDetector(
                  onLongPress: () {
                    if (isMe) {
                      changeMessage(index, length, map['message'], map['type']);
                    }
                  },
                  child: Container(
                    constraints: BoxConstraints(maxWidth: size.width * 0.65),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: isMe ? Colors.blue : Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isMe 
                                ? Colors.white.withValues(alpha: 0.2)
                                : Colors.grey.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.location_off_outlined,
                            color: isMe ? Colors.white : Colors.grey[600],
                            size: 18,
                          ),
                        ),
                        SizedBox(width: 10),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Location Sharing Ended",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: isMe ? Colors.white : Colors.grey[800],
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                "No longer available",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isMe ? Colors.white.withValues(alpha: 0.7) : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      } else {
        return Container();
      }
    }
  }

  bool? isLocationed;

  void initLocationDoc() async {
    if (isLocationed == false) {
      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('location')
          .doc(widget.userMap['uid'])
          .set({
        'isLocationed': null,
      });
    }
    return checkUserisLocationed();
  }

  void checkUserisLocationed() async {
    if (isLocationed == null) {
      isLocationed = true;
      return showTurnOnLocation();
    } else {
      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('location')
          .doc(widget.userMap['uid'])
          .get()
          .then((value) {
        isLocationed = value.data()!['isLocationed'];
      });
      if (isLocationed == true) {
        return showTurnOffLocation();
      } else {
        return showTurnOnLocation();
      }
    }
  }

  // Attachment menu bottom sheet
  void _showAttachmentMenu() {
    showModalBottomSheet(
      backgroundColor: Colors.transparent,
      context: context,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
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
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      // Photo & Video
                      _buildAttachmentOption(
                        icon: Icons.photo_library_outlined,
                        label: 'Photo & Video',
                        color: Colors.purple,
                        onTap: () {
                          Navigator.pop(context);
                          getImage();
                        },
                      ),
                      const SizedBox(height: 12),
                      // Document
                      _buildAttachmentOption(
                        icon: Icons.insert_drive_file_outlined,
                        label: 'Document',
                        color: Colors.blue,
                        onTap: () {
                          Navigator.pop(context);
                          _pickDocument();
                        },
                      ),
                      const SizedBox(height: 12),
                      // Location
                      _buildAttachmentOption(
                        icon: Icons.location_on_outlined,
                        label: 'Location',
                        color: Colors.green,
                        onTap: () {
                          Navigator.pop(context);
                          if (widget.isDeviceConnected == false) {
                            showDialogInternetCheck();
                          } else {
                            initLocationDoc();
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      // Camera
                      _buildAttachmentOption(
                        icon: Icons.camera_alt_outlined,
                        label: 'Camera',
                        color: Colors.red,
                        onTap: () {
                          Navigator.pop(context);
                          _openCamera();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[900],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Pick document (placeholder - requires file_picker package)
  Future<void> _pickDocument() async {
    try {
      if (widget.isDeviceConnected == false) {
        showDialogInternetCheck();
        return;
      }

      debugPrint('📁 ChatScreen: Starting document picker...');

      // Chọn file
      final file = await FileSharingService.pickFile();
      
      if (file == null) {
        debugPrint('📁 ChatScreen: No file selected');
        return;
      }

      debugPrint('📁 ChatScreen: File selected: ${file.name}');

      // Show loading overlay
      LoadingUtils.show(context, message: 'Uploading ${file.name}...');

      // Upload file
      final result = await FileSharingService.uploadFile(
        file: file,
        chatRoomId: widget.chatRoomId,
        onProgress: (progress) {
          debugPrint('📁 ChatScreen: Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
        },
      );

      // Hide loading overlay
      LoadingUtils.hide();

      debugPrint('✅ ChatScreen: File uploaded successfully');

      // Gửi file message
      await _sendFileMessage(
        downloadUrl: result.downloadUrl,
        fileName: result.fileName,
        fileSize: result.fileSize,
        fileExtension: result.fileExtension,
        storagePath: result.storagePath,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('File đã được gửi thành công!')),
              ],
            ),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } on FileException catch (e) {
      // Đóng dialog loading nếu đang mở
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      debugPrint('❌ ChatScreen: FileException: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(e.message)),
              ],
            ),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // Đóng dialog loading nếu đang mở
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      debugPrint('❌ ChatScreen: Error picking/uploading document: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Lỗi khi gửi file. Vui lòng thử lại!')),
              ],
            ),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _sendFileMessage({
    required String downloadUrl,
    required String fileName,
    required int fileSize,
    required String fileExtension,
    required String storagePath,
  }) async {
    try {
      debugPrint('📤 ChatScreen: Sending file message...');

      final message = FirebaseFirestore.instance
          .collection('chatroom')
          .doc(widget.chatRoomId)
          .collection('chats')
          .doc();

      await message.set({
        "sendBy": widget.user.displayName,
        "message": downloadUrl,
        "type": "file",
        "time": FieldValue.serverTimestamp(),
        "avatar": widget.user.photoURL,
        "timeStamp": DateTime.now(),
        // File metadata
        "fileName": fileName,
        "fileSize": fileSize,
        "fileExtension": fileExtension,
        "storagePath": storagePath,
        // Encryption status (files are not encrypted for now)
        "isEncrypted": false,
      });

      // Update last message in chatroom
      await FirebaseFirestore.instance
          .collection('chatroom')
          .doc(widget.chatRoomId)
          .update({
        "last_time": DateTime.now(),
        "last_chat": "📁 $fileName",
      });

      debugPrint('✅ ChatScreen: File message sent successfully');
    } catch (e) {
      debugPrint('❌ ChatScreen: Error sending file message: $e');
      rethrow;
    }
  }

  // Voice recording
  void _showVoiceRecording() {
    if (kDebugMode) { debugPrint('🎤 [ChatScreen] Voice recording button pressed'); }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (BuildContext context) {
        return _VoiceRecordingBottomSheet(
          onSendVoiceMessage: _sendVoiceMessage,
        );
      },
    );
  }

  Future<void> _sendVoiceMessage(String audioUrl, int fileSize) async {
    if (kDebugMode) { debugPrint('🎤 [ChatScreen] Sending voice message...'); }
    if (kDebugMode) { debugPrint('🎤 [ChatScreen] Audio URL: $audioUrl'); }
    
    try {
      setState(() {
        isLoading = true;
      });

      String roomId = widget.chatRoomId;

      Map<String, dynamic> messageData = {
        "sendBy": widget.user.displayName,
        "message": audioUrl,
        "type": "voice",
        "time": timeForMessage(DateTime.now().toString()),
        'avatar': widget.user.photoURL ?? '',
        'timeStamp': DateTime.now(),
        'fileSize': fileSize,
      };

      await _firestore.collection('chatroom').doc(roomId).collection('chats').add(messageData);

      // Update chat history for current user
      await _firestore.collection('users').doc(_auth.currentUser!.uid).collection('chatHistory').doc(widget.userMap['uid']).update({
        'recentMessage': '🎤 Voice message',
        'timeStamp': DateTime.now(),
      });

      // Update chat history for recipient
      await _firestore.collection('users').doc(widget.userMap['uid']).collection('chatHistory').doc(_auth.currentUser!.uid).update({
        'recentMessage': '🎤 Voice message',
        'timeStamp': DateTime.now(),
      });

      if (kDebugMode) { debugPrint('✅ [ChatScreen] Voice message sent successfully'); }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) { debugPrint('❌ [ChatScreen] Error sending voice message: $e'); }
      setState(() {
        isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send voice message: $e'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    }
  }

  void showTurnOnLocation() {
    showModalBottomSheet(
        backgroundColor: Colors.transparent,
        context: context,
        builder: (BuildContext context) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
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
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () {
                      turnOnLocation();
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.location_on,
                              color: Colors.blue[700],
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Share your location",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: Colors.grey[900],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Send your current location to chat",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        });
  }

  void turnOnLocation() async {
    await getLocation().then((value) {
      lat = '${value.latitude}';
      long = '${value.longitude}';
    });
    await _firestore
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .collection('location')
        .doc(widget.userMap['uid'])
        .set({
      'isLocationed': true,
      'lat': lat,
      'long': long,
    });
    sendLocation();
  }

  void sendLocation() async {
    String messageId = const Uuid().v1();
    await _firestore
        .collection('chatroom')
        .doc(widget.chatRoomId)
        .collection('chats')
        .doc(messageId)
        .set({
      'sendBy': widget.user.displayName,
      'message': 'Bạn đã gửi một vị trí trực tiếp',
      'type': "location",
      'time': timeForMessage(DateTime.now().toString()),
      'messageId': messageId,
      'timeStamp': DateTime.now(),
    });
    await _firestore
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .collection('location')
        .doc(widget.userMap['uid'])
        .update({
      'messageId': messageId,
    });

    await _firestore
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .collection('chatHistory')
        .doc(widget.userMap['uid'])
        .set({
      'lastMessage': "Bạn đã gửi một vị trí trực tiếp",
      'type': "location",
      'name': widget.userMap['name'],
      'time': timeForMessage(DateTime.now().toString()),
      'uid': widget.userMap['uid'],
      'avatar': widget.userMap['avatar'],
      'status': widget.userMap['status'],
      'datatype': 'p2p',
      'timeStamp': DateTime.now(),
      'isRead': true,
    });
    String? currentUserAvatar;
    String? status;
    await _firestore
        .collection("users")
        .where("email", isEqualTo: _auth.currentUser!.email)
        .get()
        .then((value) {
      currentUserAvatar = value.docs[0]['avatar'];
      status = value.docs[0]['status'];
    });
    await _firestore
        .collection('users')
        .doc(widget.userMap['uid'])
        .collection('chatHistory')
        .doc(_auth.currentUser!.uid)
        .set({
      'lastMessage': "${widget.user.displayName} da gui mot vi tri truc tiep",
      'type': "location",
      'name': widget.user.displayName,
      'time': timeForMessage(DateTime.now().toString()),
      'uid': _auth.currentUser!.uid,
      'avatar': currentUserAvatar,
      'status': status,
      'datatype': 'p2p',
      'timeStamp': DateTime.now(),
      'isRead': false,
    });
  }

  String? userLat;
  String? userLong;
  void takeUserLocation() async {
    await _firestore
        .collection('users')
        .doc(widget.userMap['uid'])
        .collection('location')
        .doc(_auth.currentUser!.uid)
        .get()
        .then((value) {
      userLat = value.data()!['lat'];
      userLong = value.data()!['long'];
    });
    openMap(userLat!, userLong!);
  }

  void showTurnOffLocation() {
    showModalBottomSheet(
        backgroundColor: Colors.transparent,
        context: context,
        builder: (BuildContext context) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
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
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () {
                      turnOffLocation();
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.location_off,
                              color: Colors.red[700],
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Stop sharing location",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: Colors.red[700],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Your location will no longer be shared",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        });
  }

  void turnOffLocation() async {
    String? messageId;
    await _firestore
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .collection('location')
        .doc(widget.userMap['uid'])
        .update({
      'isLocationed': false,
    });
    await _firestore
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .collection('location')
        .doc(widget.userMap['uid'])
        .get()
        .then((value) {
      messageId = value.data()!['messageId'];
    });
    await _firestore
        .collection('chatroom')
        .doc(widget.chatRoomId)
        .collection('chats')
        .doc(messageId)
        .update({
      'type': 'locationed',
    });
  }

  void changeMessage(
      int index, int length, String message, String messageType) {
    showModalBottomSheet(
        backgroundColor: Colors.transparent,
        context: context,
        builder: (BuildContext context) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
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
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Text(
                      "Message Options",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                  Divider(height: 1, color: Colors.grey[200]),
                  GestureDetector(
                    onTap: () {
                      removeMessage(index, length);
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.delete_outline,
                              color: Colors.red[700],
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              "Delete message",
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 15,
                                color: Colors.red[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (messageType == 'text') ...[
                    Divider(height: 1, color: Colors.grey[200]),
                    GestureDetector(
                      onTap: () {
                        showEditForm(index, length, message);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.edit_outlined,
                                color: Colors.grey[700],
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                "Edit message",
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 15,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        });
  }

  void showEditForm(int index, int length, String message) {
    TextEditingController _controller = TextEditingController();
    setState(() {
      _controller.text = message;
    });
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.edit_outlined, color: Colors.grey[700], size: 24),
              const SizedBox(width: 12),
              Text(
                "Edit Message",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[900],
                ),
              ),
            ],
          ),
          content: TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 3,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[900],
            ),
            decoration: InputDecoration(
              hintText: "Enter your message...",
              hintStyle: TextStyle(color: Colors.grey[400]),
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[600]!, width: 2),
              ),
            ),
            onSubmitted: (text) {
              if (text.trim().isNotEmpty) {
                editMessage(index, length, text);
                Navigator.pop(context);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Cancel",
                style: TextStyle(color: Colors.grey[600], fontSize: 15),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (_controller.text.trim().isNotEmpty) {
                  editMessage(index, length, _controller.text);
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[800],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: const Text("Save", style: TextStyle(fontSize: 15)),
            ),
          ],
        );
      },
    );
  }

  void editMessage(int index, int length, String message) async {
    String? str;
    await _firestore
        .collection('chatroom')
        .doc(widget.chatRoomId)
        .collection('chats')
        .orderBy('timeStamp')
        .get()
        .then((value) {
      str = value.docs[index].id;
    });
    if (str != null) {
      await _firestore
          .collection('chatroom')
          .doc(widget.chatRoomId)
          .collection('chats')
          .doc(str)
          .update({
        'message': message,
        'status': 'edited',
      });
      if (index == length - 1) {
        await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .collection('chatHistory')
            .doc(widget.userMap['uid'])
            .update({
          'lastMessage': 'Bạn: $message',
          'time': timeForMessage(DateTime.now().toString()),
          'timeStamp': DateTime.now(),
        });
        await _firestore
            .collection('users')
            .doc(widget.userMap['uid'])
            .collection('chatHistory')
            .doc(_auth.currentUser!.uid)
            .update({
          'lastMessage': message,
          'time': timeForMessage(DateTime.now().toString()),
          'timeStamp': DateTime.now(),
        });
      }
    }
  }

  void removeMessage(int index, int length) async {
    String? str;
    await _firestore
        .collection('chatroom')
        .doc(widget.chatRoomId)
        .collection('chats')
        .orderBy('timeStamp')
        .get()
        .then((value) {
      str = value.docs[index].id;
    });
    if (str != null) {
      await _firestore
          .collection('chatroom')
          .doc(widget.chatRoomId)
          .collection('chats')
          .doc(str)
          .update({
        'message': 'Bạn đã xóa một tin nhắn',
        'status': 'removed',
      });
      if (index == length - 1) {
        await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .collection('chatHistory')
            .doc(widget.userMap['uid'])
            .update({
          'lastMessage': 'Bạn đã xóa một tin nhắn',
          'time': timeForMessage(DateTime.now().toString()),
          'timeStamp': DateTime.now(),
        });
        await _firestore
            .collection('users')
            .doc(widget.userMap['uid'])
            .collection('chatHistory')
            .doc(_auth.currentUser!.uid)
            .update({
          'lastMessage': '${widget.user.displayName} đã xóa một tin nhắn',
          'time': timeForMessage(DateTime.now().toString()),
          'timeStamp': DateTime.now(),
        });
      }
    }
  }
}

class ShowImage extends StatelessWidget {
  bool isDeviceConnected;
  ShowImage({Key? key, required this.imageUrl, required this.isDeviceConnected})
      : super(key: key);

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        height: size.height,
        width: size.width,
        color: Colors.grey.shade300,
        alignment: Alignment.center,
        child: isDeviceConnected == true
            ? CachedNetworkImage(
                imageUrl: imageUrl,
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}

/// Voice Recording Bottom Sheet Widget
class _VoiceRecordingBottomSheet extends StatefulWidget {
  final Function(String audioUrl, int fileSize) onSendVoiceMessage;

  const _VoiceRecordingBottomSheet({
    required this.onSendVoiceMessage,
  });

  @override
  State<_VoiceRecordingBottomSheet> createState() => _VoiceRecordingBottomSheetState();
}

class _VoiceRecordingBottomSheetState extends State<_VoiceRecordingBottomSheet> with SingleTickerProviderStateMixin {
  bool _isRecording = false;
  bool _isUploading = false;
  String _recordingTime = '00:00';
  Timer? _timer;
  int _seconds = 0;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _startRecording();
  }

  Future<void> _startRecording() async {
    if (kDebugMode) { debugPrint('🎤 [BottomSheet] Starting recording...'); }
    final success = await VoiceMessageService.startRecording();
    
    if (success) {
      setState(() {
        _isRecording = true;
      });
      
      // Start timer
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _seconds++;
            _recordingTime = _formatTime(_seconds);
          });
        }
      });
      
      if (kDebugMode) { debugPrint('✅ [BottomSheet] Recording started successfully'); }
    } else {
      if (kDebugMode) { debugPrint('❌ [BottomSheet] Failed to start recording'); }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Microphone permission denied'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    }
  }

  Future<void> _stopAndSend() async {
    if (kDebugMode) { debugPrint('🎤 [BottomSheet] Stopping and sending...'); }
    _timer?.cancel();
    
    setState(() {
      _isRecording = false;
      _isUploading = true;
    });

    final audioPath = await VoiceMessageService.stopRecording();
    
    if (audioPath != null) {
      if (kDebugMode) { debugPrint('🎤 [BottomSheet] Recording stopped, uploading...'); }
      final result = await VoiceMessageService.uploadVoiceMessage(audioPath);
      
      if (result != null && mounted) {
        if (kDebugMode) { debugPrint('✅ [BottomSheet] Upload successful'); }
        Navigator.pop(context);
        widget.onSendVoiceMessage(result['url'], result['size']);
      } else {
        if (kDebugMode) { debugPrint('❌ [BottomSheet] Upload failed'); }
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to upload voice message'),
              backgroundColor: Colors.red[700],
            ),
          );
        }
      }
    } else {
      if (kDebugMode) { debugPrint('❌ [BottomSheet] Failed to stop recording'); }
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _cancel() async {
    if (kDebugMode) { debugPrint('🎤 [BottomSheet] Cancelling recording...'); }
    _timer?.cancel();
    await VoiceMessageService.cancelRecording();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  String _formatTime(int seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Title
          Text(
            _isUploading ? 'Sending...' : 'Recording Voice Message',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[100],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Recording indicator / Loading
          if (_isUploading)
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[400]!),
            )
          else
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Container(
                  width: 80 + (_animationController.value * 20),
                  height: 80 + (_animationController.value * 20),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mic,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                );
              },
            ),
          
          const SizedBox(height: 24),
          
          // Timer
          if (!_isUploading)
            Text(
              _recordingTime,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.grey[100],
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          
          const SizedBox(height: 32),
          
          // Action buttons
          if (!_isUploading)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Cancel button
                GestureDetector(
                  onTap: _cancel,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close,
                      color: Colors.grey[300],
                      size: 28,
                    ),
                  ),
                ),
                
                // Send button
                GestureDetector(
                  onTap: _stopAndSend,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.blue[700],
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withValues(alpha: 0.3),
                          spreadRadius: 2,
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.send,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
