import 'package:my_porject/configs/app_theme.dart';

import 'package:my_porject/widgets/page_transitions.dart';
import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:grouped_list/grouped_list.dart';
import 'package:image_picker/image_picker.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:my_porject/screens/chathome_screen.dart';
import 'package:my_porject/screens/group/group_info.dart';
import 'package:my_porject/services/group_encryption_service.dart';
import 'package:my_porject/services/voice_message_service.dart';
import 'package:my_porject/services/file_sharing_service.dart';
import 'package:my_porject/widgets/voice_message_player.dart';
import 'package:my_porject/widgets/file_message_widget.dart';
import 'package:uuid/uuid.dart';

import '../chat_screen.dart';
import '../../resources/methods.dart';
import '../../widgets/animated_avatar.dart';

// ignore: must_be_immutable
class GroupChatRoom extends StatefulWidget {
  User user;
  bool isDeviceConnected;
  final String groupChatId, groupName;

  GroupChatRoom(
      {Key? key,
      required this.groupChatId,
      required this.groupName,
      required this.user,
      required this.isDeviceConnected})
      : super(key: key);

  @override
  State<GroupChatRoom> createState() => _GroupChatRoomState();
}

class _GroupChatRoomState extends State<GroupChatRoom> {
  final TextEditingController _message = TextEditingController();

  FirebaseFirestore _firestore = FirebaseFirestore.instance;

  FirebaseAuth _auth = FirebaseAuth.instance;

  late ScrollController controller = ScrollController();

  List memberList = [];
  String? avatarUrl;
  bool isLoading = false;

  // E2EE Decryption caching to prevent repeated decryption on widget rebuilds
  final Map<String, String> _decryptedMessagesCache = {};
  final Map<String, Future<String>> _decryptionFuturesCache = {};

  @override
  void initState() {
    getConnectivity();
    getMemberList();
    getCurrentUserAvatar();
    updateIsReadMessage();
    // WidgetsBinding.instance.addPostFrameCallback((_) => scrollToIndex());
    super.initState();
    focusNode.addListener(() {
      if (focusNode.hasFocus) {
        setState(() {
          showEmoji = false;
        });
      }
    });
  }

  @override
  void dispose() {
    updateIsReadMessage();
    super.dispose();
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

  updateIsReadMessage() async {
    await _firestore
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .collection('chatHistory')
        .doc(widget.groupChatId)
        .update({
      'isRead': true,
    });
  }

  void getCurrentUserAvatar() async {
    await _firestore
        .collection('users')
        .doc(widget.user.uid)
        .get()
        .then((value) {
      avatarUrl = value.data()!['avatar'].toString();
    });
  }

  void onSendMessage() async {
    String message;
    message = _message.text;
    if (_message.text.isNotEmpty) {
      // Encrypt message
      if (kDebugMode) {
        debugPrint('🔐 Attempting to encrypt group message...');
      }
      String? encryptedMessage = await GroupEncryptionService.encryptGroupMessage(
        _message.text,
        widget.groupChatId,
      );

      // Track encryption success
      bool encryptionSucceeded = false;
      
      // If encryption fails, send unencrypted (fallback)
      if (encryptedMessage == null) {
        encryptedMessage = _message.text;
        encryptionSucceeded = false;
        if (kDebugMode) {
          debugPrint('⚠️ Encryption FAILED - Sending unencrypted message');
        }
      } else {
        encryptionSucceeded = true;
        if (kDebugMode) {
          debugPrint('✅ Message encrypted successfully');
        }
      }

      Map<String, dynamic> chatData = {
        "sendBy": widget.user.displayName,
        "message": encryptedMessage, // Encrypted message
        "type": "text",
        "time": timeForMessage(DateTime.now().toString()),
        'avatar': avatarUrl,
        'timeStamp': DateTime.now(),
        'isEncrypted': encryptionSucceeded, // Mark if encryption succeeded
      };

      _message.clear();

      await _firestore
          .collection('groups')
          .doc(widget.groupChatId)
          .collection('chats')
          .add(chatData);
      
      // For chat history, show actual message (not encrypted indicator)
      // The message shown in history should be the ORIGINAL readable message
      String historyPreview = "${widget.user.displayName}: $message";
          
      for (int i = 0; i < memberList.length; i++) {
        await _firestore
            .collection('users')
            .doc(memberList[i]['uid'])
            .collection('chatHistory')
            .doc(widget.groupChatId)
            .update({
          'lastMessage': historyPreview,
          'type': "text",
          'time': timeForMessage(DateTime.now().toString()),
          'timeStamp': DateTime.now(),
          'isRead': false,
        });
      }
    }
  }

  // Decrypt message if it's encrypted (with caching)
  Future<String> _decryptMessageIfNeeded(Map<String, dynamic> chatMap, String messageId) async {
    try {
      final String message = chatMap['message'] ?? '';
      final bool isEncrypted = chatMap['isEncrypted'] ?? false;
      
      // If not encrypted, return original message
      if (!isEncrypted || message.isEmpty) {
        return message;
      }
      
      // Check cache first (instant return)
      if (_decryptedMessagesCache.containsKey(messageId)) {
        return _decryptedMessagesCache[messageId]!;
      }
      
      // Decrypt the message
      String? decryptedMessage = await GroupEncryptionService.decryptGroupMessage(
        message,
        widget.groupChatId,
      );
      
      final result = decryptedMessage ?? '[Unable to decrypt message]';
      
      // Cache the result
      _decryptedMessagesCache[messageId] = result;
      
      return result;
    } catch (e) {
      if (kDebugMode) { debugPrint('Error decrypting message: $e'); }
      return '[Decryption error]';
    }
  }

  // Get cached Future for FutureBuilder to prevent flickering
  Future<String> _getCachedMessageFuture(Map<String, dynamic> chatMap, String messageId) {
    // If already have result, return completed future immediately
    if (_decryptedMessagesCache.containsKey(messageId)) {
      return Future.value(_decryptedMessagesCache[messageId]!);
    }
    
    // If Future already in progress, return same Future (prevents duplicate decryption)
    if (_decryptionFuturesCache.containsKey(messageId)) {
      return _decryptionFuturesCache[messageId]!;
    }
    
    // Create new Future and cache it
    final future = _decryptMessageIfNeeded(chatMap, messageId);
    _decryptionFuturesCache[messageId] = future;
    return future;
  }

  void getMemberList() async {
    await _firestore
        .collection('groups')
        .doc(widget.groupChatId)
        .get()
        .then((value) {
      setState(() {
        memberList = value.data()!['members'];
      });
    });
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
    // scrollToIndex();
  }

  Future uploadImage() async {
    String fileName = const Uuid().v1();

    int status = 1;

    await _firestore
        .collection('groups')
        .doc(widget.groupChatId)
        .collection('chats')
        .doc(fileName)
        .set({
      'sendBy': widget.user.displayName,
      'message': _message.text,
      'type': "img",
      'time': timeForMessage(DateTime.now().toString()),
      'avatar': avatarUrl,
      'timeStamp': DateTime.now(),
    });

    var ref =
        FirebaseStorage.instance.ref().child('images').child("$fileName.jpg");

    var uploadTask = await ref.putFile(imageFile!).catchError((error) async {
      await _firestore
          .collection('groups')
          .doc(widget.groupChatId)
          .collection('chats')
          .doc(fileName)
          .delete();
      status = 0;
      throw error; // Re-throw to satisfy return type
    });

    if (status == 1) {
      String imageUrl = await uploadTask.ref.getDownloadURL();

      await _firestore
          .collection('groups')
          .doc(widget.groupChatId)
          .collection('chats')
          .doc(fileName)
          .update({
        'message': imageUrl,
      });
      for (int i = 0; i < memberList.length; i++) {
        await _firestore
            .collection('users')
            .doc(memberList[i]['uid'])
            .collection('chatHistory')
            .doc(widget.groupChatId)
            .update({
          'lastMessage': "${widget.user.displayName} đã gửi một ảnh",
          'type': "img",
          'time': timeForMessage(DateTime.now().toString()),
          'timeStamp': DateTime.now(),
          'isRead': false,
        });
      }
    }
  }

  late String lat;
  late String long;

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
            // columns: 7,  // Deprecated in grouped_list 6.0.0
            ),
        onEmojiSelected: (emoji, category) {
          _message.text = _message.text + category.emoji;
        },
      ),
    );
  }

  void _showAttachmentMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Photo & Video
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.photo_library_outlined, color: AppTheme.accent, size: 24),
              ),
              title: Text('Photo & Video', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppTheme.primaryDark)),
              onTap: () {
                Navigator.pop(context);
                getImage();
              },
            ),
            const SizedBox(height: 8),
            // Document
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.accentDark.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.insert_drive_file_outlined, color: AppTheme.accentDark, size: 24),
              ),
              title: Text('Document', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppTheme.primaryDark)),
              onTap: () {
                Navigator.pop(context);
                _pickDocument();
              },
            ),
            const SizedBox(height: 8),
            // Location
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.location_on_outlined, color: AppTheme.success, size: 24),
              ),
              title: Text('Location', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppTheme.primaryDark)),
              onTap: () {
                Navigator.pop(context);
                if (widget.isDeviceConnected == false) {
                  showDialogInternetCheck();
                } else {
                  checkUserisLocationed();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDocument() async {
    try {
      if (widget.isDeviceConnected == false) {
        showDialogInternetCheck();
        return;
      }

      debugPrint('📁 GroupChatRoom: Starting document picker...');

      // Chọn file
      final file = await FileSharingService.pickFile();
      
      if (file == null) {
        debugPrint('📁 GroupChatRoom: No file selected');
        return;
      }

      debugPrint('📁 GroupChatRoom: File selected: ${file.name}');

      // Hiển thị dialog loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            backgroundColor: AppTheme.primaryDark,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Colors.blue),
                const SizedBox(height: 20),
                Text(
                  'Đang tải lên ${file.name}...',
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );

      // Upload file
      final result = await FileSharingService.uploadFile(
        file: file,
        chatRoomId: widget.groupChatId,
        onProgress: (progress) {
          debugPrint('📁 GroupChatRoom: Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
        },
      );

      // Đóng dialog loading
      if (mounted) Navigator.pop(context);

      debugPrint('✅ GroupChatRoom: File uploaded successfully');

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
            backgroundColor: AppTheme.success,
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
      
      debugPrint('❌ GroupChatRoom: FileException: $e');
      
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
            backgroundColor: AppTheme.error,
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
      
      debugPrint('❌ GroupChatRoom: Error picking/uploading document: $e');
      
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
            backgroundColor: AppTheme.error,
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
      debugPrint('📤 GroupChatRoom: Sending file message...');

      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupChatId)
          .collection("chats")
          .add({
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

      debugPrint('✅ GroupChatRoom: File message sent successfully');
    } catch (e) {
      debugPrint('❌ GroupChatRoom: Error sending file message: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: AppTheme.backgroundLight,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: AppTheme.primaryDark,
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.3),
          flexibleSpace: SafeArea(
            child: Container(
              padding: const EdgeInsets.only(right: 10),
              child: Row(
                children: <Widget>[
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                          context,
                          SlideRightRoute(
                              page: HomeScreen(user: widget.user)));
                    },
                    icon: const Icon(
                      Icons.arrow_back_ios,
                      color: AppTheme.textWhite,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 2),
                  // Use GroupAvatar for consistent styling
                  GroupAvatar(
                    groupName: widget.groupName,
                    size: 40,
                    memberCount: memberList.length,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.groupName,
                          style: AppTheme.titleMedium.copyWith(
                            color: AppTheme.textWhite,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppTheme.online,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${memberList.length} members',
                              style: const TextStyle(
                                color: AppTheme.textHint,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                          context,
                          SlideRightRoute(
                              page: GroupInfo(
                                    groupName: widget.groupName,
                                    groupId: widget.groupChatId,
                                    user: widget.user,
                                    memberListt: memberList,
                                    isDeviceConnected: widget.isDeviceConnected,
                                  )));
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
        body: RefreshIndicator(
          onRefresh: () {
            return abc();
          },
          child: Column(
            children: <Widget>[
              widget.isDeviceConnected == false
                  ? Container(
                      alignment: Alignment.center,
                      width: MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.height / 30,
                      // color: Colors.red,
                      child: const Text(
                        'No Internet Connection',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  : Container(),
              Expanded(
                child: Container(
                    color: Colors.transparent,
                    width: size.width,
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _firestore
                          .collection('groups')
                          .doc(widget.groupChatId)
                          .collection('chats')
                          .orderBy('timeStamp', descending: false)
                          .limit(limit)
                          .snapshots(),
                      builder: (context, snapshot) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (controller.hasClients) {
                            controller
                                .jumpTo(controller.position.maxScrollExtent);
                          }
                        });
                        if (snapshot.hasData) {
                          return GroupedListView<QueryDocumentSnapshot<Object?>,
                              String>(
                            elements: snapshot.data?.docs
                                as List<QueryDocumentSnapshot<Object?>>,
                            shrinkWrap: true,
                            controller: controller,
                            groupBy: (element) => element['time'],
                            order: GroupedListOrder.ASC,
                            reverse: false,
                            groupSeparatorBuilder: (String groupByValue) =>
                                Container(
                              alignment: Alignment.center,
                              height: 30,
                              child: Text(
                                formatTimestampSafe(groupByValue),
                                style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            // itemCount: snapshot.data?.docs.length as int ,
                            indexedItemBuilder: (context, element, index) {
                              // Map<String, dynamic> map = snapshot.data?.docs[index].data() as Map<String, dynamic>;
                              Map<String, dynamic> map =
                                  element.data() as Map<String, dynamic>;
                              final String messageId = element.id; // Get document ID for caching
                              return messageTitle(
                                  size, map, index, snapshot.data!.docs.length, messageId);
                            },
                            // controller: itemScrollController,
                          );
                        } else {
                          return Container();
                        }
                      },
                    )),
              ),
              Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(color: AppTheme.gray200!, width: 0.5),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        // Attachment button
                        Container(
                          width: 44,
                          height: 44,
                          margin: const EdgeInsets.only(right: 6),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              _showAttachmentMenu(context);
                            },
                            icon: Icon(
                              Icons.add_circle_outline,
                              color: AppTheme.gray700,
                              size: 28,
                            ),
                          ),
                        ),
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
                                color: AppTheme.gray300!,
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
                                // Emoji button - moved to left inside input
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
                                    color: AppTheme.gray700,
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
                                    style: TextStyle(
                                      fontSize: 16, 
                                      color: Colors.grey[900], // Fixed: Use solid color instead of transparent
                                      height: 1.5,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Type a message...',
                                      hintStyle: TextStyle(
                                        color: Colors.grey[500], // Fixed: Use solid color
                                        fontSize: 16,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      filled: false,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
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
                        // Send/Mic button
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _message,
                          builder: (context, value, child) {
                            return Container(
                              width: 44,
                              height: 44,
                              margin: const EdgeInsets.only(left: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.gray800,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                onPressed: () {
                                  if (_message.text.trim().isNotEmpty) {
                                    onSendMessage();
                                  } else {
                                    _showVoiceRecording();
                                  }
                                },
                                icon: Icon(
                                  _message.text.trim().isEmpty ? Icons.mic : Icons.send,
                                  color: Colors.white,
                                  size: 22,
                                ),
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

  Widget messageTitle(
      Size size, Map<String, dynamic> chatMap, int index, int length, String messageId) {
    return Builder(builder: (context) {
      if (chatMap['status'] == 'removed') {
        // Removed message - matching 1-1 chat theme
        final bool isMe = chatMap['sendBy'] == widget.user.displayName;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            const SizedBox(width: 2),
            if (!isMe)
              SizedBox(
                height: size.width / 13,
                width: size.width / 13,
                child: CircleAvatar(
                  backgroundImage: chatMap['avatar'] != null 
                      ? NetworkImage(chatMap['avatar']) 
                      : null,
                  backgroundColor: Colors.grey.shade300,
                  maxRadius: 30,
                  child: chatMap['avatar'] == null 
                      ? Icon(Icons.person, color: Colors.grey.shade600, size: 18)
                      : null,
                ),
              ),
            Container(
              constraints: BoxConstraints(maxWidth: size.width * 0.7),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: Colors.grey.shade200,
                border: Border.all(color: Colors.grey.shade300, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.block, color: Colors.grey.shade500, size: 16),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      chatMap['message'] ?? 'Message deleted',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 15,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      } else {
        if (chatMap['type'] == 'text') {
          final bool isMe = chatMap['sendBy'] == widget.user.displayName;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const SizedBox(width: 2),
              // Avatar for other users (not me)
              !isMe
                  ? Container(
                      margin: const EdgeInsets.only(bottom: 5),
                      height: size.width / 13,
                      width: size.width / 13,
                      child: CircleAvatar(
                        backgroundImage: chatMap['avatar'] != null 
                            ? NetworkImage(chatMap['avatar']) 
                            : null,
                        backgroundColor: Colors.grey.shade300,
                        maxRadius: 30,
                        child: chatMap['avatar'] == null 
                            ? Icon(Icons.person, color: Colors.grey.shade600, size: 18)
                            : null,
                      ),
                    )
                  : Container(),
              Expanded(
                child: Column(
                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    // Sender name for group chat (only for others)
                    if (!isMe)
                      Container(
                        padding: const EdgeInsets.only(left: 12, bottom: 2),
                        child: Text(
                          chatMap['sendBy'] ?? '',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    GestureDetector(
                      onLongPress: () {
                        if (isMe) {
                          changeMessage(index, length, chatMap['message'], chatMap['type']);
                        }
                      },
                      child: Container(
                        constraints: BoxConstraints(maxWidth: size.width * 0.7),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        decoration: BoxDecoration(
                          // Match 1-1 chat theme: different border radius for sent/received
                          borderRadius: isMe
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
                          // Match 1-1 chat theme colors
                          color: isMe ? AppTheme.sentBubble : AppTheme.receivedBubble,
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
                          future: _getCachedMessageFuture(chatMap, messageId),
                          builder: (context, snapshot) {
                            // Show loading only if no cached data available
                            if (snapshot.connectionState == ConnectionState.waiting &&
                                !_decryptedMessagesCache.containsKey(messageId)) {
                              return Text(
                                'Decrypting...',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isMe ? Colors.white70 : Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              );
                            }
                            // Use cached data if available, otherwise use snapshot data
                            final messageText = _decryptedMessagesCache[messageId] ??
                                snapshot.data ??
                                chatMap['message'] ?? '';
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (chatMap['isEncrypted'] == true)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: Icon(
                                      Icons.lock_outline,
                                      color: isMe ? Colors.green[300] : Colors.green[600],
                                      size: 14,
                                    ),
                                  ),
                                Flexible(
                                  child: Text(
                                    messageText,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: isMe ? Colors.white : Colors.grey[900],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        } else if (chatMap['type'] == 'img') {
          final bool isMe = chatMap['sendBy'] == widget.user.displayName;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const SizedBox(width: 2),
              !isMe
                  ? Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      height: size.width / 13,
                      width: size.width / 13,
                      child: CircleAvatar(
                        backgroundImage: chatMap['avatar'] != null 
                            ? NetworkImage(chatMap['avatar']) 
                            : null,
                        backgroundColor: Colors.grey.shade300,
                        maxRadius: 30,
                        child: chatMap['avatar'] == null 
                            ? Icon(Icons.person, color: Colors.grey.shade600, size: 18)
                            : null,
                      ),
                    )
                  : Container(),
              GestureDetector(
                onLongPress: () {
                  if (isMe) {
                    changeMessage(index, length, chatMap['message'], chatMap['type']);
                  }
                },
                child: Container(
                  height: size.height / 2.5,
                  width: isMe ? size.width * 0.98 : size.width * 0.77,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: InkWell(
                    onTap: () => Navigator.of(context).push(
                      SlideRightRoute(
                          page: ShowImage(
                                imageUrl: chatMap['message'],
                                isDeviceConnected: widget.isDeviceConnected,
                              )),
                    ),
                    child: Container(
                      height: size.height / 2.5,
                      width: size.width / 2,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: Colors.grey.shade300,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withValues(alpha: 0.15),
                            spreadRadius: 1,
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      alignment: chatMap['message'] != "" &&
                              widget.isDeviceConnected == true
                          ? null
                          : Alignment.center,
                      child: chatMap['message'] != "" &&
                              widget.isDeviceConnected == true
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(18.0),
                              child: CachedNetworkImage(
                                fit: BoxFit.cover,
                                imageUrl: chatMap['message'],
                                memCacheWidth: 400,
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
        } else if (chatMap['type'] == 'voice') {
          // Voice message rendering for group chat - matching 1-1 chat theme
          final bool isMe = chatMap['sendBy'] == widget.user.displayName;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              const SizedBox(width: 2),
              if (!isMe)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  height: size.width / 13,
                  width: size.width / 13,
                  child: CircleAvatar(
                    backgroundImage: chatMap['avatar'] != null 
                        ? NetworkImage(chatMap['avatar']) 
                        : null,
                    backgroundColor: Colors.grey.shade300,
                    maxRadius: 30,
                    child: chatMap['avatar'] == null 
                        ? Icon(Icons.person, color: Colors.grey.shade600, size: 18)
                        : null,
                  ),
                ),
              Flexible(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  padding: const EdgeInsets.all(10),
                  constraints: BoxConstraints(maxWidth: size.width * 0.7),
                  decoration: BoxDecoration(
                    borderRadius: isMe
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
                    color: isMe ? AppTheme.sentBubble : AppTheme.receivedBubble,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.15),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: VoiceMessagePlayer(
                    audioUrl: chatMap['message'],
                    isMe: isMe,
                  ),
                ),
              ),
            ],
          );
        } else if (chatMap['type'] == 'file') {
          // File message rendering for group chat - matching 1-1 chat theme
          final bool isMe = chatMap['sendBy'] == widget.user.displayName;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              const SizedBox(width: 2),
              if (!isMe)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  height: size.width / 13,
                  width: size.width / 13,
                  child: CircleAvatar(
                    backgroundImage: chatMap['avatar'] != null 
                        ? NetworkImage(chatMap['avatar']) 
                        : null,
                    backgroundColor: Colors.grey.shade300,
                    maxRadius: 30,
                    child: chatMap['avatar'] == null 
                        ? Icon(Icons.person, color: Colors.grey.shade600, size: 18)
                        : null,
                  ),
                ),
              Flexible(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  constraints: BoxConstraints(maxWidth: size.width * 0.7),
                  child: FileMessageWidget(
                    fileUrl: chatMap['message'],
                    fileName: chatMap['fileName'] ?? 'Unknown file',
                    fileSize: chatMap['fileSize'] ?? 0,
                    fileExtension: chatMap['fileExtension'] ?? 'bin',
                    isMe: isMe,
                  ),
                ),
              ),
            ],
          );
        } else if (chatMap['type'] == 'notify') {
          // System notification message - matching 1-1 chat theme
          return Container(
            width: size.width,
            alignment: Alignment.center,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.grey[200],
              ),
              child: Text(
                chatMap['message'],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        } else if (chatMap['type'] == 'location') {
          final bool isMe = chatMap['sendBy'] == widget.user.displayName;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              const SizedBox(width: 2),
              if (!isMe)
                Container(
                  margin: const EdgeInsets.only(bottom: 5),
                  height: size.width / 13,
                  width: size.width / 13,
                  child: CircleAvatar(
                    backgroundImage: chatMap['avatar'] != null 
                        ? NetworkImage(chatMap['avatar']) 
                        : null,
                    backgroundColor: Colors.grey.shade300,
                    maxRadius: 30,
                    child: chatMap['avatar'] == null 
                        ? Icon(Icons.person, color: Colors.grey.shade600, size: 18)
                        : null,
                  ),
                ),
              GestureDetector(
                onLongPress: () {
                  if (isMe) {
                    changeMessage(index, length, chatMap['message'], chatMap['type']);
                  }
                },
                child: Container(
                  width: size.width / 2,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                  margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  decoration: BoxDecoration(
                    borderRadius: isMe
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
                    color: isMe ? AppTheme.sentBubble : AppTheme.receivedBubble,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.15),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isMe ? Colors.white24 : AppTheme.accent.withValues(alpha: 0.2),
                            ),
                            child: Icon(
                              Icons.location_on,
                              color: isMe ? Colors.white : AppTheme.accent,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Live Location",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: isMe ? Colors.white : Colors.grey[900],
                                  ),
                                ),
                                Text(
                                  "Sharing started",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isMe ? Colors.white70 : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () => takeUserLocation(chatMap['uid']),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: isMe ? Colors.white24 : AppTheme.accent,
                          ),
                          child: Text(
                            "View Location",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ],
          );
        } else if (chatMap['type'] == 'locationed') {
          final bool isMe = chatMap['sendBy'] == widget.user.displayName;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              const SizedBox(width: 2),
              if (!isMe)
                Container(
                  margin: const EdgeInsets.only(bottom: 5),
                  height: size.width / 13,
                  width: size.width / 13,
                  child: CircleAvatar(
                    backgroundImage: chatMap['avatar'] != null 
                        ? NetworkImage(chatMap['avatar']) 
                        : null,
                    backgroundColor: Colors.grey.shade300,
                    maxRadius: 30,
                    child: chatMap['avatar'] == null 
                        ? Icon(Icons.person, color: Colors.grey.shade600, size: 18)
                        : null,
                  ),
                ),
              GestureDetector(
                onLongPress: () {
                  if (isMe) {
                    changeMessage(index, length, chatMap['message'], chatMap['type']);
                  }
                },
                child: Container(
                  constraints: BoxConstraints(maxWidth: size.width * 0.65),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                  margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  decoration: BoxDecoration(
                    borderRadius: isMe
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
                    color: Colors.grey[300],
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.15),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey[400],
                        ),
                        child: Icon(
                          Icons.location_off,
                          color: Colors.grey[600],
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          "Location sharing ended",
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        } else {
          return Container();
        }
      }
    });
  }

  bool? isLocationed;
  void checkUserisLocationed() async {
    await _firestore
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .collection('location')
        .doc(widget.groupChatId)
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

  void showTurnOnLocation() {
    showModalBottomSheet(
        backgroundColor: Colors.transparent,
        context: context,
        builder: (BuildContext context) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.gray300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(height: 20),
                  GestureDetector(
                    onTap: () {
                      turnOnLocation();
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.location_on,
                              color: AppTheme.accent,
                              size: 24,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Share your location",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: AppTheme.primaryDark,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  "Send your current location to group",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.gray600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios, color: AppTheme.gray400, size: 16),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
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
        .doc(widget.groupChatId)
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
        .collection('groups')
        .doc(widget.groupChatId)
        .collection('chats')
        .doc(messageId)
        .set({
      'sendBy': widget.user.displayName,
      'message': '${widget.user.displayName} đã gửi một vị trí trực tiếp',
      'type': "location",
      'time': timeForMessage(DateTime.now().toString()),
      'avatar': avatarUrl,
      'messageId': messageId,
      'uid': _auth.currentUser!.uid,
      'timeStamp': DateTime.now(),
    });

    await _firestore
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .collection('location')
        .doc(widget.groupChatId)
        .update({
      'messageId': messageId,
    });

    for (int i = 0; i < memberList.length; i++) {
      await _firestore
          .collection('users')
          .doc(memberList[i]['uid'])
          .collection('chatHistory')
          .doc(widget.groupChatId)
          .update({
        'lastMessage': "${widget.user.displayName} đã gửi một vị trí trực tiếp",
        'type': "location",
        'time': timeForMessage(DateTime.now().toString()),
        'timeStamp': DateTime.now(),
        'isRead': false,
      });
    }
    // scrollToIndex();
  }

  String? userLat;
  String? userLong;
  void takeUserLocation(String uid) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('location')
        .doc(widget.groupChatId)
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
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.gray300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(height: 20),
                  GestureDetector(
                    onTap: () {
                      turnOffLocation();
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.location_off,
                              color: AppTheme.error,
                              size: 24,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Stop sharing location",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: AppTheme.error,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  "Turn off location sharing",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.gray600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios, color: AppTheme.gray400, size: 16),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
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
        .doc(widget.groupChatId)
        .update({
      'isLocationed': false,
    });
    await _firestore
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .collection('location')
        .doc(widget.groupChatId)
        .get()
        .then((value) {
      messageId = value.data()!['messageId'];
    });
    await _firestore
        .collection('groups')
        .doc(widget.groupChatId)
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
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        context: context,
        builder: (BuildContext context) {
          return Container(
            decoration: BoxDecoration(
              color: AppTheme.gray50,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.gray400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Remove message option
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: AppTheme.gray200!, width: 1),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.delete_outline,
                          color: AppTheme.error),
                    ),
                    title: const Text('Remove message',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('Delete this message for everyone',
                        style: TextStyle(
                            color: AppTheme.gray600, fontSize: 13)),
                    onTap: () {
                      removeMessage(index, length);
                      Navigator.pop(context);
                    },
                  ),
                ),
                if (messageType == 'text') ...[
                  const SizedBox(height: 8),
                  Card(
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: AppTheme.gray200!, width: 1),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.edit_outlined,
                            color: AppTheme.accent),
                      ),
                      title: const Text('Edit message',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('Modify your message',
                          style: TextStyle(
                              color: AppTheme.gray600, fontSize: 13)),
                      onTap: () {
                        showEditForm(index, length, message);
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 10),
              ],
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
            content: TextField(
          controller: _controller,
          onSubmitted: (text) {
            editMessage(index, length, text);
            Navigator.pop(context);
          },
        ));
      },
    );
  }

  void editMessage(int index, int length, String message) async {
    String? str;
    await _firestore
        .collection('groups')
        .doc(widget.groupChatId)
        .collection('chats')
        .orderBy('timeStamp')
        .get()
        .then((value) {
      str = value.docs[index].id;
    });
    if (str != null) {
      await _firestore
          .collection('groups')
          .doc(widget.groupChatId)
          .collection('chats')
          .doc(str)
          .update({
        'message': message,
        'status': 'edited',
      });
      if (index == length - 1) {
        for (int i = 0; i < memberList.length; i++) {
          await _firestore
              .collection('users')
              .doc(memberList[i]['uid'])
              .collection('chatHistory')
              .doc(widget.groupChatId)
              .update({
            'lastMessage': '${widget.user.displayName}: $message',
            'time': timeForMessage(DateTime.now().toString()),
            'timeStamp': DateTime.now(),
            'isRead': false,
          });
        }
      }
    }
  }

  void removeMessage(int index, int length) async {
    String? str;
    await _firestore
        .collection('groups')
        .doc(widget.groupChatId)
        .collection('chats')
        .orderBy('timeStamp')
        .get()
        .then((value) {
      str = value.docs[index].id;
    });
    if (str != null) {
      await _firestore
          .collection('groups')
          .doc(widget.groupChatId)
          .collection('chats')
          .doc(str)
          .update({
        'message': 'Bạn đã xóa một tin nhắn',
        'status': 'removed',
      });
      if (index == length - 1) {
        for (int i = 0; i < memberList.length; i++) {
          await _firestore
              .collection('users')
              .doc(memberList[i]['uid'])
              .collection('chatHistory')
              .doc(widget.groupChatId)
              .update({
            'lastMessage': '${widget.user.displayName} đã xóa một tin nhắn',
            'time': timeForMessage(DateTime.now().toString()),
            'timeStamp': DateTime.now(),
            'isRead': false,
          });
        }
      }
    }
  }

  showDialogInternetCheck() => showCupertinoDialog<String>(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
            title: const Text(
              'No Connection',
              style: TextStyle(
                letterSpacing: 0.5,
              ),
            ),
            content: const Text(
              'Please check your internet connectivity',
              style: TextStyle(letterSpacing: 0.5, fontSize: 12),
            ),
            actions: <Widget>[
              TextButton(
                  onPressed: () async {
                    Navigator.pop(context, 'Cancel');
                  },
                  child: const Text(
                    'OK',
                    style: TextStyle(letterSpacing: 0.5, fontSize: 15),
                  ))
            ],
          ));

  void _showVoiceRecording() {
    if (kDebugMode) { debugPrint('🎤 [GroupChat] Voice recording button pressed'); }
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
    if (kDebugMode) { debugPrint('🎤 [GroupChat] Sending voice message...'); }
    if (kDebugMode) { debugPrint('🎤 [GroupChat] Audio URL: $audioUrl'); }
    
    try {
      setState(() {
        isLoading = true;
      });

      Map<String, dynamic> chatData = {
        "sendBy": widget.user.displayName,
        "message": audioUrl,
        "type": "voice",
        "time": timeForMessage(DateTime.now().toString()),
        'avatar': avatarUrl,
        'timeStamp': DateTime.now(),
        'fileSize': fileSize,
        'isEncrypted': false, // Voice messages not encrypted
      };

      await _firestore
          .collection('groups')
          .doc(widget.groupChatId)
          .collection('chats')
          .add(chatData);

      if (kDebugMode) { debugPrint('✅ [GroupChat] Voice message sent successfully'); }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) { debugPrint('❌ [GroupChat] Error sending voice message: $e'); }
      setState(() {
        isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send voice message: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }
}

/// Voice Recording Bottom Sheet Widget for Group Chat
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
    final success = await VoiceMessageService.startRecording();
    
    if (success) {
      setState(() {
        _isRecording = true;
      });
      
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _seconds++;
            _recordingTime = _formatTime(_seconds);
          });
        }
      });
    } else {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Microphone permission denied'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _stopAndSend() async {
    _timer?.cancel();
    
    setState(() {
      _isRecording = false;
      _isUploading = true;
    });

    final audioPath = await VoiceMessageService.stopRecording();
    
    if (audioPath != null) {
      final result = await VoiceMessageService.uploadVoiceMessage(audioPath);
      
      if (result != null && mounted) {
        Navigator.pop(context);
        widget.onSendVoiceMessage(result['url'], result['size']);
      } else {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to upload voice message'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    } else {
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _cancel() async {
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
        color: AppTheme.primaryDark,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.gray700,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            _isUploading ? 'Sending...' : 'Recording Voice Message',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.gray100,
            ),
          ),
          const SizedBox(height: 32),
          if (_isUploading)
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentLight!),
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
          if (!_isUploading)
            Text(
              _recordingTime,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppTheme.gray100,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          const SizedBox(height: 32),
          if (!_isUploading)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: _cancel,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppTheme.gray800,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close,
                      color: AppTheme.gray300,
                      size: 28,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _stopAndSend,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: AppTheme.accent,
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
