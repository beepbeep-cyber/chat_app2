import 'dart:io';
import 'package:my_porject/configs/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:grouped_list/grouped_list.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../resources/methods.dart';
import '../../services/ai_chat_service.dart';
import '../../services/remote_config_service.dart';
import '../../utils/gemini_api_tester.dart';

/// Modern AI ChatBot Screen with Google Gemini
class ChatBot extends StatefulWidget {
  final User user;
  const ChatBot({Key? key, required this.user}) : super(key: key);

  @override
  State<ChatBot> createState() => _ChatBotState();
}

class _ChatBotState extends State<ChatBot> with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _message = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  bool _isTyping = false;
  bool _showSuggestions = true;
  late AnimationController _typingAnimationController;
  
  // Image & Voice features
  File? _selectedImage;
  final ImagePicker _imagePicker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _recordingPath;
  
  // API Key storage
  String? _apiKey;
  static const String _apiKeyPrefKey = 'gemini_api_key';
  bool _isLoadingRemoteConfig = true;
  
  // Cooldown timer
  int _cooldownSeconds = 0;
  bool _isCooldown = false;

  @override
  void initState() {
    super.initState();
    _initializeAI();
    _initTypingAnimation();
    _startCooldownTimer();
  }

  /// Start periodic timer to update cooldown UI
  void _startCooldownTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      
      final globalCooldown = AIChatService.globalCooldownRemaining;
      if (globalCooldown > 0) {
        setState(() {
          _cooldownSeconds = globalCooldown;
          _isCooldown = true;
        });
      } else if (_isCooldown) {
        setState(() {
          _cooldownSeconds = 0;
          _isCooldown = false;
        });
      }
      return mounted; // Continue while widget is mounted
    });
  }

  /// Initialize AI Service (Remote Config first, then local key)
  Future<void> _initializeAI() async {
    setState(() {
      _isLoadingRemoteConfig = true;
    });

    try {
      // Step 1: Initialize Remote Config and get API key from server
      // This will also load user's custom key from Firestore automatically
      await AIChatService.initializeFromRemoteConfig();
      
      // Step 2: Sync SharedPreferences with Firestore (for backward compatibility)
      await _syncApiKeyFromFirestore();
      
      // Update state after initialization
      setState(() {
        _isLoadingRemoteConfig = false;
      });
    } catch (e) {
      debugPrint('❌ ChatBot: Failed to initialize AI: $e');
      // Fallback: try to load from SharedPreferences
      await _loadApiKey();
      setState(() {
        _isLoadingRemoteConfig = false;
      });
    }
  }

  void _initTypingAnimation() {
    _typingAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  /// Sync API key from Firestore to SharedPreferences
  Future<void> _syncApiKeyFromFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (doc.exists && doc.data() != null) {
        final firestoreKey = doc.data()!['geminiApiKey'] as String?;
        if (firestoreKey != null && firestoreKey.isNotEmpty) {
          // Save to SharedPreferences for backward compatibility
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_apiKeyPrefKey, firestoreKey);
          
          // Set in AIChatService
          AIChatService.setApiKey(firestoreKey);
          
          setState(() {
            _apiKey = firestoreKey;
          });
          
          debugPrint('✅ Synced API key from Firestore: ${_maskApiKey(firestoreKey)}');
          return;
        }
      }
    } catch (e) {
      debugPrint('❌ Error syncing API key from Firestore: $e');
    }
    
    // Fallback: Load from SharedPreferences
    await _loadApiKey();
  }
  
  Future<void> _loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final savedKey = prefs.getString(_apiKeyPrefKey);
    if (savedKey != null && savedKey.isNotEmpty) {
      AIChatService.setApiKey(savedKey);
      setState(() {
        _apiKey = savedKey;
      });
      debugPrint('✅ Loaded API key from SharedPreferences: ${_maskApiKey(savedKey)}');
    }
  }
  
  String _maskApiKey(String apiKey) {
    if (apiKey.length <= 8) return '****';
    return '${apiKey.substring(0, 4)}...${apiKey.substring(apiKey.length - 4)}';
  }

  Future<void> _saveApiKey(String key) async {
    try {
      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_apiKeyPrefKey, key);
      
      // Save to Firestore (for consistency with Profile screen)
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'geminiApiKey': key});
        debugPrint('✅ Saved API key to Firestore');
      }
      
      // Set in AIChatService
      AIChatService.setApiKey(key);
      
      setState(() {
        _apiKey = key;
      });
      
      debugPrint('✅ API key saved: ${_maskApiKey(key)}');
    } catch (e) {
      debugPrint('❌ Error saving API key: $e');
      
      // Still try to set in AIChatService even if Firestore fails
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_apiKeyPrefKey, key);
      AIChatService.setApiKey(key);
      setState(() {
        _apiKey = key;
      });
    }
  }

  @override
  void dispose() {
    _typingAnimationController.dispose();
    _scrollController.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.gray50,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // API Key Banner (loading, success, or setup required)
          _buildApiKeyBanner(),
          
          // Chat messages
          Expanded(
            child: _buildChatArea(),
          ),
          
          // Suggestions chips
          if (_showSuggestions && AIChatService.isInitialized && !_isLoadingRemoteConfig) _buildSuggestionChips(),
          
          // Input area
          _buildInputArea(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: AppTheme.gray800),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Assistant',
                  style: TextStyle(
                    color: AppTheme.primaryDark,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isLoadingRemoteConfig
                            ? AppTheme.warning
                            : (AIChatService.isInitialized 
                                ? AppTheme.success 
                                : AppTheme.error),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isLoadingRemoteConfig
                          ? 'Connecting...'
                          : (AIChatService.isInitialized 
                              ? (AIChatService.isUsingRemoteConfig 
                                  ? 'Server API Key' 
                                  : 'Custom API Key')
                              : 'Setup required'),
                      style: TextStyle(
                        color: AppTheme.gray500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.settings_outlined, color: AppTheme.gray700),
          onPressed: _showSettingsDialog,
        ),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: AppTheme.gray700),
          onSelected: (value) {
            if (value == 'clear') {
              _showClearHistoryDialog();
            } else if (value == 'test_key') {
              _testApiKey();
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'clear',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, size: 20),
                  SizedBox(width: 12),
                  Text('Clear Chat'),
                ],
              ),
            ),
            // Debug: Test API Key
            if (kDebugMode)
              const PopupMenuItem(
                value: 'test_key',
                child: Row(
                  children: [
                    Icon(Icons.science, size: 20),
                    SizedBox(width: 12),
                    Text('🔬 Test API Key'),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildApiKeyBanner() {
    // If loading, show loading state
    if (_isLoadingRemoteConfig) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.accent.withValues(alpha: 0.1), AppTheme.accentLight.withValues(alpha: 0.1)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Connecting to server for API key...',
                style: TextStyle(
                  color: AppTheme.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Show cooldown banner if in cooldown
    if (_isCooldown && _cooldownSeconds > 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red[100]!, Colors.orange[100]!],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    value: _cooldownSeconds / 70,
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.red[400]!),
                    backgroundColor: Colors.red[200],
                  ),
                ),
                Text(
                  '$_cooldownSeconds',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Server quá tải - Đang chờ...',
                    style: TextStyle(
                      color: Colors.red[700],
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tự động thử lại sau $_cooldownSeconds giây',
                    style: TextStyle(
                      color: Colors.red[600],
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: _showSettingsDialog,
              child: Text(
                'Dùng key riêng',
                style: TextStyle(
                  color: Colors.red[700],
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // If using Remote Config key, show success banner with rate limit status
    if (AIChatService.isInitialized && AIChatService.isUsingRemoteConfig) {
      final status = AIChatService.detailedStatus;
      final isReady = status['isReady'] as bool;
      final availableKeys = status['availableKeys'] as int;
      final totalKeys = status['totalKeys'] as int;
      final remaining = status['remainingRequests'] as int;
      
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isReady 
                ? [AppTheme.success.withValues(alpha: 0.1), AppTheme.accent.withValues(alpha: 0.1)]
                : [Colors.orange[100]!, Colors.amber[100]!],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isReady ? Icons.cloud_done : Icons.cloud_off,
              color: isReady ? AppTheme.success : Colors.orange[700],
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isReady ? 'Server API - Sẵn sàng!' : 'Server đang bận',
                    style: TextStyle(
                      color: isReady ? AppTheme.success : Colors.orange[700],
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (isReady ? AppTheme.success : Colors.orange).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '🖥 $availableKeys/$totalKeys',
                          style: TextStyle(
                            color: isReady ? AppTheme.success : Colors.orange[700],
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (remaining > 3 ? AppTheme.success : Colors.orange).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '💬 $remaining/8',
                          style: TextStyle(
                            color: remaining > 3 ? AppTheme.success : Colors.orange[700],
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: _showSettingsDialog,
              child: Text(
                'Settings',
                style: TextStyle(
                  color: AppTheme.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // If no API key available, show setup banner
    if (!AIChatService.isInitialized) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.amber[100]!, Colors.orange[100]!],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.key, color: AppTheme.warning, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Server API key not found. Set up your own key.',
                style: TextStyle(
                  color: Colors.orange[900],
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(
              onPressed: _showSettingsDialog,
              child: Text(
                'Setup',
                style: TextStyle(
                  color: AppTheme.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // If using custom key, show nothing (or minimal indicator)
    return const SizedBox.shrink();
  }

  Widget _buildChatArea() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('chatvsBot')
          .orderBy('timeStamp', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          }
        });

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        return GroupedListView<QueryDocumentSnapshot<Object?>, String>(
          shrinkWrap: true,
          elements: snapshot.data!.docs,
          groupBy: (element) => element['time'] ?? '',
          groupSeparatorBuilder: (String groupByValue) => Container(
            alignment: Alignment.center,
            margin: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.gray200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                formatTimestampSafe(groupByValue),
                style: TextStyle(
                  color: AppTheme.gray600,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          indexedItemBuilder: (context, element, index) {
            Map<String, dynamic> map = element.data() as Map<String, dynamic>;
            return _buildMessageBubble(map);
          },
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 50),
            ),
            const SizedBox(height: 24),
            Text(
              'Hi! I\'m your AI Assistant',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryDark,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'I can help you with questions, ideas, writing, coding, and much more!',
              style: TextStyle(
                fontSize: 15,
                color: AppTheme.gray600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (!AIChatService.isInitialized) ...[
              ElevatedButton.icon(
                onPressed: _showSettingsDialog,
                icon: const Icon(Icons.key),
                label: const Text('Setup API Key'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> map) {
    final bool isUser = map['sendBy'] == widget.user.displayName;
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: isUser
                    ? const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isUser ? null : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Show voice indicator if voice message
                  if (map['type'] == 'voice') ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.mic,
                          size: 16,
                          color: isUser ? Colors.white70 : AppTheme.accent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Voice message',
                          style: TextStyle(
                            color: isUser ? Colors.white70 : AppTheme.gray600,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  // Show image if available
                  if (map['type'] == 'image' && map['imageUrl'] != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        map['imageUrl'],
                        width: 200,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            width: 200,
                            height: 200,
                            alignment: Alignment.center,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isUser ? Colors.white : AppTheme.accent,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 200,
                            height: 200,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppTheme.gray200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image, size: 40, color: AppTheme.gray500),
                                const SizedBox(height: 8),
                                Text(
                                  'Image not available',
                                  style: TextStyle(color: AppTheme.gray600, fontSize: 12),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    if (map['message'] != null && 
                        map['message'].toString().isNotEmpty && 
                        map['message'] != '📸 [Image]')
                      const SizedBox(height: 8),
                  ],
                  // Show text message
                  if (map['message'] != null && 
                      map['message'].toString().isNotEmpty &&
                      map['message'] != '📸 [Image]')
                    SelectableText(
                      map['message'] ?? '',
                      style: TextStyle(
                        color: isUser ? Colors.white : AppTheme.gray800,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 10),
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.gray200,
              child: Text(
                (widget.user.displayName ?? 'U')[0].toUpperCase(),
                style: TextStyle(
                  color: AppTheme.gray700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSuggestionChips() {
    final suggestions = AIChatService.getSuggestedPrompts();
    
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: suggestions.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text(
                suggestions[index],
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.gray700,
                ),
              ),
              backgroundColor: Colors.white,
              side: BorderSide(color: AppTheme.gray300),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              onPressed: () {
                // Remove emoji prefix for actual message
                final prompt = suggestions[index].replaceAll(RegExp(r'^[^\s]+\s'), '');
                _message.text = prompt;
                _sendMessage();
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image preview (if selected)
            if (_selectedImage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.gray100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        _selectedImage!,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Image selected',
                        style: TextStyle(
                          color: AppTheme.gray700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: AppTheme.gray600),
                      onPressed: () {
                        setState(() {
                          _selectedImage = null;
                        });
                      },
                    ),
                  ],
                ),
              ),
            
            Row(
              children: [
                // Camera button
                IconButton(
                  icon: Icon(Icons.camera_alt, color: AppTheme.accent),
                  onPressed: AIChatService.isInitialized ? _pickImage : null,
                ),
                // Mic button (hold to record)
                GestureDetector(
                  onLongPressStart: (_) => _startRecording(),
                  onLongPressEnd: (_) => _stopRecording(),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _isRecording 
                          ? Colors.red.withValues(alpha: 0.1)
                          : AppTheme.gray100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isRecording ? Icons.mic : Icons.mic_none,
                      color: _isRecording ? Colors.red : AppTheme.accent,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.gray100,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _message,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: _isRecording 
                            ? 'Recording...'
                            : (AIChatService.isInitialized 
                                ? 'Ask me anything...' 
                                : 'Setup API key first...'),
                        hintStyle: TextStyle(
                          color: _isRecording ? Colors.red : AppTheme.gray500,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      enabled: AIChatService.isInitialized && !_isRecording,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Send button
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: AIChatService.isInitialized
                        ? const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: AIChatService.isInitialized ? null : AppTheme.gray300,
                    shape: BoxShape.circle,
                  ),
                  child: _isTyping
                      ? _buildTypingIndicator()
                      : IconButton(
                          icon: const Icon(Icons.send_rounded, color: Colors.white),
                          onPressed: AIChatService.isInitialized ? _sendMessage : null,
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      ),
    );
  }
  
  // Image picker with option to choose gallery or camera
  Future<void> _pickImage() async {
    try {
      // Show bottom sheet to choose source
      final ImageSource? source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.gray300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Choose image source',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryDark,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.camera_alt, color: AppTheme.accent),
                  ),
                  title: const Text('Camera'),
                  subtitle: const Text('Take a photo'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.photo_library, color: AppTheme.accent),
                  ),
                  title: const Text('Gallery'),
                  subtitle: const Text('Choose from gallery'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      );
      
      if (source == null) return;
      
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error picking image: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể chọn ảnh: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }
  
  // Voice recording
  Future<void> _startRecording() async {
    if (!AIChatService.isInitialized) return;
    
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );
        
        setState(() {
          _isRecording = true;
          _recordingPath = path;
        });
        
        if (kDebugMode) {
          debugPrint('🎤 Recording started: $path');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error starting recording: $e');
      }
    }
  }
  
  Future<void> _stopRecording() async {
    if (!_isRecording) return;
    
    try {
      final path = await _audioRecorder.stop();
      
      setState(() {
        _isRecording = false;
      });
      
      if (path != null && File(path).existsSync()) {
        if (kDebugMode) {
          debugPrint('🎤 Recording stopped: $path');
        }
        
        // Send voice message
        await _sendVoiceMessage(path);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error stopping recording: $e');
      }
      setState(() {
        _isRecording = false;
      });
    }
  }
  
  Future<void> _sendVoiceMessage(String audioPath) async {
    setState(() {
      _isTyping = true;
    });
    
    try {
      // Convert audio to text using Gemini Audio API
      final response = await AIChatService.audioToText(File(audioPath));
      
      if (!response.success) {
        setState(() {
          _isTyping = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message),
              backgroundColor: AppTheme.error,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }
      
      // Got transcribed text - now send it to the bot
      final transcribedText = response.message;
      
      if (kDebugMode) {
        debugPrint('✅ Transcribed: $transcribedText');
      }
      
      // Show success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎤 Đã nghe: "$transcribedText"'),
            backgroundColor: AppTheme.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
      // Save voice message to Firestore (as text type with voice metadata)
      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('chatvsBot')
          .add({
        'sendBy': widget.user.displayName,
        'message': transcribedText,
        'type': 'voice', // Mark as voice message
        'time': timeForMessage(DateTime.now().toString()),
        'timeStamp': DateTime.now(),
      });
      
      // Get AI response for the transcribed text
      final aiResponse = await AIChatService.sendMessage(transcribedText);
      
      // Update cooldown if rate limited
      if (aiResponse.isRateLimited && aiResponse.cooldownSeconds != null) {
        setState(() {
          _cooldownSeconds = aiResponse.cooldownSeconds!;
          _isCooldown = true;
        });
      }
      
      // Save AI response
      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('chatvsBot')
          .add({
        'sendBy': 'bot',
        'message': aiResponse.message,
        'type': 'text',
        'time': timeForMessage(DateTime.now().toString()),
        'timeStamp': DateTime.now(),
      });
      
      setState(() {
        _isTyping = false;
      });
      
      // Scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Voice message error: $e');
      }
      
      setState(() {
        _isTyping = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _sendMessage() async {
    final message = _message.text.trim();
    final hasImage = _selectedImage != null;
    
    // Validation: either text or image must be provided
    if (message.isEmpty && !hasImage) return;
    if (!AIChatService.isInitialized) return;
    
    // Check cooldown before sending
    if (_isCooldown && _cooldownSeconds > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đang chờ server... còn $_cooldownSeconds giây'),
          backgroundColor: Colors.orange[700],
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // Capture image reference before clearing state
    final imageToSend = _selectedImage;
    
    setState(() {
      _message.clear();
      _selectedImage = null; // Clear image preview
      _isTyping = true;
      _showSuggestions = false;
    });

    HapticFeedback.lightImpact();

    String? imageUrl;
    
    // Upload image to Firebase Storage if present
    if (imageToSend != null) {
      try {
        final fileName = 'chatbot_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('chat_images')
            .child(_auth.currentUser!.uid)
            .child(fileName);
        
        await storageRef.putFile(imageToSend);
        imageUrl = await storageRef.getDownloadURL();
        
        if (kDebugMode) {
          debugPrint('✅ Image uploaded to Firebase Storage: $imageUrl');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ Failed to upload image: $e');
        }
        setState(() {
          _isTyping = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Không thể upload ảnh: $e'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
        return;
      }
    }

    // Save user message to Firestore
    await _firestore
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .collection('chatvsBot')
        .add({
      'sendBy': widget.user.displayName,
      'message': message.isEmpty ? '📸 [Image]' : message,
      'type': hasImage ? 'image' : 'text',
      'imageUrl': imageUrl,
      'time': timeForMessage(DateTime.now().toString()),
      'timeStamp': DateTime.now(),
    });

    // Get AI response (with or without image)
    final response = hasImage
        ? await AIChatService.sendMessageWithImage(
            message.isEmpty ? 'Hãy phân tích ảnh này' : message,
            imageToSend!,
          )
        : await AIChatService.sendMessage(message);
    
    // Update cooldown if rate limited
    if (response.isRateLimited && response.cooldownSeconds != null) {
      setState(() {
        _cooldownSeconds = response.cooldownSeconds!;
        _isCooldown = true;
      });
    }

    // Save AI response to Firestore
    await _firestore
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .collection('chatvsBot')
        .add({
      'sendBy': 'bot',
      'message': response.message,
      'type': 'text',
      'time': timeForMessage(DateTime.now().toString()),
      'timeStamp': DateTime.now(),
    });

    setState(() {
      _isTyping = false;
    });

    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showSettingsDialog() {
    final TextEditingController apiKeyController = TextEditingController(
      text: _apiKey ?? '',
    );
    final remoteConfig = RemoteConfigService();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.key, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 16),
            Text(
              'Gemini API Key',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryDark,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Current Status
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AIChatService.isInitialized 
                      ? AppTheme.success.withValues(alpha: 0.1)
                      : AppTheme.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AIChatService.isInitialized 
                        ? AppTheme.success
                        : AppTheme.warning,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      AIChatService.isInitialized ? Icons.check_circle : Icons.warning,
                      color: AIChatService.isInitialized ? AppTheme.success : AppTheme.warning,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        AIChatService.isInitialized 
                            ? '✓ AI Bot đang hoạt động'
                            : '⚠️ Chưa có API Key',
                        style: TextStyle(
                          fontSize: 13,
                          color: AIChatService.isInitialized ? AppTheme.success : AppTheme.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Info banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Lấy API key miễn phí để tránh giới hạn rate limit',
                        style: TextStyle(fontSize: 13, color: Colors.blue[700]),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Get API Key button
              OutlinedButton.icon(
                onPressed: () async {
                  final url = Uri.parse('https://aistudio.google.com/app/apikey');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Lấy API Key Miễn Phí'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF6366F1),
                  side: const BorderSide(color: Color(0xFF6366F1)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // API Key input
              TextField(
                controller: apiKeyController,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  labelText: 'Dán API Key của bạn',
                  hintText: 'AIza...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                  ),
                  prefixIcon: const Icon(Icons.vpn_key),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.paste),
                    onPressed: () async {
                      final data = await Clipboard.getData('text/plain');
                      if (data?.text != null) {
                        apiKeyController.text = data!.text!;
                      }
                    },
                  ),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              
              // Instructions
              Text(
                'Các bước:\n'
                '1. Nhấp "Lấy API Key Miễn Phí" ở trên\n'
                '2. Đăng nhập bằng Google\n'
                '3. Nhấp "Create API Key"\n'
                '4. Sao chép và dán vào đây',
                style: TextStyle(fontSize: 12, color: AppTheme.gray600, height: 1.5),
              ),
            ],
          ),
        ),
        actions: [
          // Clear button (if has custom key)
          if (_apiKey != null && _apiKey!.isNotEmpty)
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _clearApiKey();
              },
              child: Text('Xóa', style: TextStyle(color: Colors.red[600])),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppTheme.gray600)),
          ),
          ElevatedButton(
            onPressed: () async {
              final key = apiKeyController.text.trim();
              if (key.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Vui lòng nhập API key'),
                    backgroundColor: AppTheme.warning,
                  ),
                );
                return;
              }
              
              // Validate API key format
              if (!key.startsWith('AIza')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('❌ API key không hợp lệ!\n\nKey phải bắt đầu bằng "AIza"'),
                    backgroundColor: AppTheme.error,
                    duration: Duration(seconds: 3),
                  ),
                );
                return;
              }
              
              Navigator.pop(context);
              await _saveApiKey(key);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _clearApiKey() async {
    try {
      // Clear from Firestore
      await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
        'geminiApiKey': FieldValue.delete(),
      });
      
      // Clear from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_apiKeyPrefKey);
      
      // Clear from AIChatService and revert to Remote Config
      await AIChatService.clearCustomApiKey();
      
      setState(() {
        _apiKey = null;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ API Key đã xóa. Đang dùng Server Key.'),
            backgroundColor: AppTheme.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error clearing API key: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi xóa API key: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }
  
  void _testApiKey() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔬 Testing API key... Check console/logcat for results'),
        duration: Duration(seconds: 2),
      ),
    );
    
    await GeminiApiTester.testCurrentApiKey();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Test complete! Check debug console for detailed report'),
          duration: Duration(seconds: 3),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  void _showClearHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red[400]),
            const SizedBox(width: 12),
            const Text('Clear Chat History'),
          ],
        ),
        content: const Text(
          'This will delete all messages with the AI assistant. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppTheme.gray600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // Clear Firestore history
              final batch = _firestore.batch();
              final docs = await _firestore
                  .collection('users')
                  .doc(_auth.currentUser!.uid)
                  .collection('chatvsBot')
                  .get();
              
              for (var doc in docs.docs) {
                batch.delete(doc.reference);
              }
              await batch.commit();
              
              // Clear service history
              AIChatService.clearHistory();
              
              setState(() {
                _showSuggestions = true;
              });
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Chat history cleared'),
                  backgroundColor: AppTheme.success,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[400],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
