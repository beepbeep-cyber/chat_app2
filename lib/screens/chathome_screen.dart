import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:my_porject/provider/user_provider.dart';
import 'package:my_porject/screens/call_log_screen.dart';
import 'package:my_porject/screens/chat_bot/chat_bot.dart';
import 'package:my_porject/screens/finding_screen.dart';
import 'package:my_porject/screens/setting.dart';
import 'package:my_porject/screens/group/group_chat.dart';
import 'package:my_porject/screens/private_chat_screen.dart';
import 'package:my_porject/widgets/conversationList.dart';
import 'package:my_porject/services/cache_service.dart';
import 'package:my_porject/services/presence_service.dart';
import 'package:my_porject/services/onesignal_service.dart';  // ✅ OneSignal
import 'package:my_porject/services/incoming_call_service.dart';
import 'package:my_porject/screens/video_call_screen.dart';
import 'package:provider/provider.dart';
import 'package:my_porject/resources/methods.dart';
import '../db/log_repository.dart';
import '../configs/app_theme.dart';
import '../widgets/animated_avatar.dart';
import '../widgets/animated_list_item.dart';
import '../widgets/glass_container.dart';
import '../widgets/micro_interactions.dart';
import '../widgets/page_transitions.dart';
import 'chat_screen.dart';

class HomeScreen extends StatefulWidget {
  final User user;
  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CacheService _cacheService = CacheService();

  late UserProvider userProvider;
  late StreamSubscription subscription;
  
  var isDeviceConnected = true;
  bool isAlertSet = false;
  int _selectedIndex = 0;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  void _initializeApp() async {
    // Initialize presence service for automatic offline detection
    await PresenceService().initialize();
    
    setStatus("Online");
    changeStatus("Online");
    SchedulerBinding.instance.addPostFrameCallback((_) {
      userProvider = Provider.of<UserProvider>(context, listen: false);
      userProvider.refreshUser();
    });
    LogRepository.init(dbName: _auth.currentUser!.uid);
    _getConnectivity();
    
    // ✅ Save OneSignal Player ID to Firestore
    await OneSignalService.savePlayerIdToFirestore(_auth.currentUser!.uid);
    
    // 🔔 CRITICAL: Start listening for incoming calls AFTER initialization
    // Must wait for Firebase Auth to be ready!
    await Future.delayed(const Duration(milliseconds: 500)); // Small delay to ensure auth is ready
    _initializeIncomingCallListener();
  }

  /// Initialize incoming call listener (NO FCM REQUIRED!)
  void _initializeIncomingCallListener() {
    final callService = IncomingCallService();
    
    // Set callback để show dialog khi có cuộc gọi đến
    callService.onIncomingCall = (callData) {
      if (kDebugMode) {
        debugPrint('📞 [HomeScreen] Incoming call callback triggered!');
        debugPrint('   Caller: ${callData['callerName']}');
        debugPrint('   CallId: ${callData['callId']}');
      }
      _showIncomingCallDialog(callData);
    };
    
    // Start listening
    callService.startListening();
    
    if (kDebugMode) {
      debugPrint('📞 [HomeScreen] Incoming call listener initialized');
    }
  }

  /// Show incoming call dialog with beautiful UI
  void _showIncomingCallDialog(Map<String, dynamic> callData) {
    final String callerName = callData['callerName'] ?? 'Unknown';
    final String callerAvatar = callData['callerAvatar'] ?? '';
    final String channelName = callData['channelName'] ?? '';
    final String chatRoomId = callData['chatRoomId'] ?? '';
    final String callerUid = callData['callerUid'] ?? '';
    final String callId = callData['callId'] ?? '';
    
    // CRITICAL: Save HomeScreen context before showing dialog!
    final homeContext = context;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF667eea),
                Color(0xFF764ba2),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Video call icon with animation
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.video_call,
                  size: 48,
                  color: Colors.white,
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Title
              const Text(
                'Cuộc gọi video đến',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Caller Avatar with border and shadow
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: callerAvatar.isNotEmpty
                    ? CircleAvatar(
                        radius: 50,
                        backgroundImage: NetworkImage(callerAvatar),
                        backgroundColor: Colors.white,
                      )
                    : const CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.person,
                          size: 50,
                          color: Color(0xFF667eea),
                        ),
                      ),
              ),
              
              const SizedBox(height: 20),
              
              // Caller name
              Text(
                callerName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 8),
              
              // Calling text with animation dots
              const Text(
                'đang gọi cho bạn...',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Action buttons - Big and beautiful
              Row(
                children: [
                  // Reject button - Red
                  Expanded(
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () async {
                            if (!mounted) return;
                            Navigator.pop(dialogContext); // Close dialog with dialog context
                            
                            // Update status to rejected
                            await IncomingCallService.rejectCall(callId);
                            
                            // CRITICAL: Cleanup document immediately!
                            await IncomingCallService.cleanupCall(callId);
                            
                            if (kDebugMode) {
                              debugPrint('❌ [HomeScreen] Call rejected');
                              debugPrint('🧹 [HomeScreen] Call document cleaned up: $callId');
                            }
                          },
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.call_end,
                                color: Colors.white,
                                size: 24,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Từ chối',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Accept button - Green
                  Expanded(
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.green.shade600,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () async {
                            // CRITICAL: Close dialog first with dialog context
                            if (!mounted) return;
                            Navigator.pop(dialogContext); // Use dialog context to close
                            
                            // Update call status to accepted
                            await IncomingCallService.acceptCall(callId);
                            
                            // CRITICAL: Cleanup document immediately to prevent re-triggering!
                            // This prevents the caller from receiving the call notification
                            await IncomingCallService.cleanupCall(callId);
                            
                            if (kDebugMode) {
                              debugPrint('✅ [HomeScreen] Call accepted, joining channel: $channelName');
                              debugPrint('🧹 [HomeScreen] Call document cleaned up: $callId');
                            }
                            
                            // CRITICAL: Check if widget is still mounted before navigating
                            if (!mounted) {
                              if (kDebugMode) {
                                debugPrint('⚠️ [HomeScreen] Widget unmounted, cannot navigate');
                              }
                              return;
                            }
                            
                            // Navigate using HOME context (not dialog context!)
                            Navigator.push(
                              homeContext, // Use saved home context!
                              MaterialPageRoute(
                                builder: (context) => VideoCallScreen(
                                  channelName: channelName,
                                  userName: _auth.currentUser?.displayName ?? 'Me',
                                  userAvatar: _auth.currentUser?.photoURL,
                                  calleeName: callerName,
                                  calleeAvatar: callerAvatar,
                                  chatRoomId: chatRoomId,
                                  calleeUid: callerUid,
                                ),
                              ),
                            );
                          },
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.video_call,
                                color: Colors.white,
                                size: 28,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Trả lời',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _getConnectivity() {
    subscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) async {
      isDeviceConnected = await InternetConnection().hasInternetAccess;
      if (mounted) setState(() {});
      if (!isDeviceConnected && !isAlertSet) {
        _showNoConnectionDialog();
        setState(() => isAlertSet = true);
      }
    });
  }

  @override
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    IncomingCallService().stopListening();
    super.dispose();
  }

  void _showNoConnectionDialog() {
    showCupertinoDialog<String>(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: const Text('Không có kết nối'),
        content: const Text('Vui lòng kiểm tra kết nối internet'),
        actions: <Widget>[
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => isAlertSet = false);
              isDeviceConnected = await InternetConnection().hasInternetAccess;
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void setStatus(String status) async {
    final userDoc = await _firestore.collection('users').doc(_auth.currentUser!.uid).get();
    final bool isStatusLocked = userDoc.data()?['isStatusLocked'] ?? false;
    final String actualStatus = isStatusLocked ? "Offline" : status;
    
    await _firestore.collection('users').doc(_auth.currentUser?.uid).update({
      "status": actualStatus,
    });
  }

  void changeStatus(String status) async {
    final cachedUser = await _cacheService.getUser(_auth.currentUser!.uid);
    final bool isStatusLocked = cachedUser?['isStatusLocked'] ?? false;
    
    if (isStatusLocked) return;
    
    try {
      final chatHistorySnapshot = await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('chatHistory')
          .where('datatype', isEqualTo: 'p2p')
          .get();
      
      if (chatHistorySnapshot.docs.isEmpty) return;
      
      WriteBatch batch = _firestore.batch();
      int operationCount = 0;
      
      for (final doc in chatHistorySnapshot.docs) {
        final uId = doc['uid'];
        if (uId != null) {
          final ref = _firestore
              .collection('users')
              .doc(uId)
              .collection('chatHistory')
              .doc(_auth.currentUser!.uid);
          
          batch.update(ref, {'status': status});
          operationCount++;
          
          if (operationCount >= 400) {
            await batch.commit();
            batch = _firestore.batch();
            operationCount = 0;
          }
        }
      }
      
      if (operationCount > 0) {
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Error updating status: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // App returned to foreground
        setStatus("Online");
        changeStatus('Online');
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // App going to background or being killed
        // Use PresenceService for reliable offline detection
        PresenceService().setOffline();
        break;
    }
  }

  void _onNavTapped(int index) {
    HapticFeedback.selectionClick();
    setState(() => _selectedIndex = index);
  }

  void _onSearch() {
    showSearch(
      context: context,
      delegate: CustomSearch(
        user: widget.user, 
        isDeviceConnected: isDeviceConnected,
      ),
    );
    _searchController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: AppTheme.backgroundLight,
        body: _buildBody(),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildBody() {
    if (_selectedIndex == 3) {
      return Setting(
        user: widget.user,
        isDeviceConnected: isDeviceConnected,
      );
    }
    return _buildMainContent();
  }

  Widget _buildMainContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        _buildSearchBar(),
        _buildConnectionStatus(),
        _buildOnlineUsers(),
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildHeader() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.only(left: 20, top: 16, right: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _getHeaderTitle(),
              style: AppTheme.headlineLarge,
            ),
            Row(
              children: [
                // Private Chats Button
                BounceButton(
                  onPressed: () => Navigator.push(
                    context,
                    SlideRightRoute(
                      page: PrivateChatScreen(
                        user: widget.user,
                        isDeviceConnected: isDeviceConnected,
                      ),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: AppTheme.accentGradient,
                    ),
                    child: const Icon(
                      Icons.lock_outline,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // AI Bot Button
                BounceButton(
                  onPressed: () {
                    if (!isDeviceConnected) {
                      _showNoConnectionDialog();
                    } else {
                      Navigator.push(
                        context,
                        SlideUpRoute(page: ChatBot(user: widget.user)),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: AppTheme.primaryDark,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                        SizedBox(width: 6),
                        Text(
                          "AI",
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getHeaderTitle() {
    switch (_selectedIndex) {
      case 0: return "Tin nhắn";
      case 1: return "Groups";
      case 2: return "Cuộc gọi";
      default: return "Tin nhắn";
    }
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: GlassSearchBar(
        controller: _searchController,
        hintText: "Tìm kiếm tin nhắn...",
        readOnly: true,
        onTap: () {
          if (!isDeviceConnected) {
            _showNoConnectionDialog();
          } else {
            _onSearch();
          }
        },
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return StreamBuilder<List<ConnectivityResult>>(
      stream: Connectivity().onConnectivityChanged,
      builder: (_, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          final states = snapshot.data;
          if (states != null && states.contains(ConnectivityResult.none)) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off, color: AppTheme.error, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'No Internet Connection',
                    style: AppTheme.bodyMedium.copyWith(color: AppTheme.error),
                  ),
                ],
              ),
            );
          }
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildOnlineUsers() {
    if (_selectedIndex != 0) return const SizedBox.shrink();
    
    return SizedBox(
      height: 100,
      child: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('users')
            .doc(widget.user.uid.isNotEmpty ? widget.user.uid : "0")
            .collection('chatHistory')
            .where('status', isEqualTo: 'Online')
            .where('datatype', isEqualTo: 'p2p')
            .limit(10)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.data == null || snapshot.data!.docs.isEmpty) {
            return const SizedBox.shrink();
          }
          
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final map = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              final roomId = ChatRoomId().chatRoomId(
                widget.user.displayName, 
                map['name'],
              );
              
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    SlideRightRoute(
                      page: ChatScreen(
                        chatRoomId: roomId,
                        userMap: map,
                        user: widget.user,
                        isDeviceConnected: isDeviceConnected,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedAvatar(
                        imageUrl: map['avatar'],
                        name: map['name'] ?? 'User',
                        size: 60,
                        isOnline: true,
                        showStatus: true,
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: 70,
                        child: Text(
                          map['name'] ?? 'User',
                          style: AppTheme.bodySmall.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildChatList();
      case 1:
        return GroupChatHomeScreen(
          user: widget.user,
          isDeviceConnected: isDeviceConnected,
        );
      case 2:
        return const CallLogScreen();
      default:
        return _buildChatList();
    }
  }

  Widget _buildChatList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, top: 8, bottom: 8),
          child: Text(
            'Gần đây',
            style: AppTheme.labelLarge.copyWith(color: AppTheme.textSecondary),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('users')
                .doc(widget.user.uid.isNotEmpty ? widget.user.uid : "0")
                .collection('chatHistory')
                .orderBy('timeStamp', descending: true)
                .limit(50)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.data == null) {
                return ChatListShimmer(itemCount: 8);
              }
              
              // ✅ Filter private chats in code instead of query (no index needed)
              final allDocs = snapshot.data!.docs;
              final publicChats = allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                // Show chat if isPrivate field doesn't exist OR is false
                return data['isPrivate'] != true;
              }).toList();
              
              if (publicChats.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 64,
                        color: AppTheme.gray300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No conversations yet',
                        style: AppTheme.bodyLarge.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start chatting by searching for users',
                        style: AppTheme.bodySmall,
                      ),
                    ],
                  ),
                );
              }
              
              return ListView.builder(
                itemCount: publicChats.length,
                padding: const EdgeInsets.only(top: 5, bottom: 20),
                physics: const BouncingScrollPhysics(),
                cacheExtent: 500,
                itemBuilder: (context, index) {
                  final map = publicChats[index].data() as Map<String, dynamic>;
                  return AnimatedListItem(
                    index: index,
                    delay: const Duration(milliseconds: 30),
                    child: ConversationList(
                      chatHistory: map,
                      user: widget.user,
                      isDeviceConnected: isDeviceConnected,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    return GlassBottomNavBar(
      currentIndex: _selectedIndex,
      onTap: _onNavTapped,
      items: const [
        GlassNavItem(
          icon: Icons.chat_bubble_outline_rounded,
          activeIcon: Icons.chat_bubble_rounded,
          label: 'Trò chuyện',
        ),
        GlassNavItem(
          icon: Icons.groups_outlined,
          activeIcon: Icons.groups_rounded,
          label: 'Nhóm',
        ),
        GlassNavItem(
          icon: Icons.call_outlined,
          activeIcon: Icons.call_rounded,
          label: 'Cuộc gọi',
        ),
        GlassNavItem(
          icon: Icons.settings_outlined,
          activeIcon: Icons.settings_rounded,
          label: 'Cài đặt',
        ),
      ],
    );
  }
}
