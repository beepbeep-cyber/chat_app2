import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
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
    setStatus("Online");
    changeStatus("Online");
    SchedulerBinding.instance.addPostFrameCallback((_) {
      userProvider = Provider.of<UserProvider>(context, listen: false);
      userProvider.refreshUser();
    });
    LogRepository.init(dbName: _auth.currentUser!.uid);
    _getConnectivity();
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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showNoConnectionDialog() {
    showCupertinoDialog<String>(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: const Text('No Connection'),
        content: const Text('Please check your internet connectivity'),
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
    if (state == AppLifecycleState.resumed) {
      setStatus("Online");
      changeStatus('Online');
    } else {
      setStatus("Offline");
      changeStatus('Offline');
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
      case 0: return "Messages";
      case 1: return "Groups";
      case 2: return "Calls";
      default: return "Messages";
    }
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: GlassSearchBar(
        controller: _searchController,
        hintText: "Search messages...",
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
            'Recent',
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
              
              if (snapshot.data!.docs.isEmpty) {
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
                itemCount: snapshot.data!.docs.length,
                padding: const EdgeInsets.only(top: 5, bottom: 20),
                physics: const BouncingScrollPhysics(),
                cacheExtent: 500,
                itemBuilder: (context, index) {
                  final map = snapshot.data!.docs[index].data() as Map<String, dynamic>;
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
          label: 'Chats',
        ),
        GlassNavItem(
          icon: Icons.groups_outlined,
          activeIcon: Icons.groups_rounded,
          label: 'Groups',
        ),
        GlassNavItem(
          icon: Icons.call_outlined,
          activeIcon: Icons.call_rounded,
          label: 'Calls',
        ),
        GlassNavItem(
          icon: Icons.settings_outlined,
          activeIcon: Icons.settings_rounded,
          label: 'Settings',
        ),
      ],
    );
  }
}
