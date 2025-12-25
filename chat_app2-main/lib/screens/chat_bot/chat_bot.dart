import 'package:my_porject/configs/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:grouped_list/grouped_list.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../resources/methods.dart';
import '../../services/ai_chat_service.dart';
import '../../services/remote_config_service.dart';

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
  
  // API Key storage
  String? _apiKey;
  static const String _apiKeyPrefKey = 'gemini_api_key';
  bool _isLoadingRemoteConfig = true;

  @override
  void initState() {
    super.initState();
    _initializeAI();
    _initTypingAnimation();
  }

  /// Initialize AI Service (Remote Config first, then local key)
  Future<void> _initializeAI() async {
    setState(() {
      _isLoadingRemoteConfig = true;
    });

    try {
      // Step 1: Initialize Remote Config and get API key from server
      await AIChatService.initializeFromRemoteConfig();
      
      // Step 2: Load local custom key (if user has set one)
      await _loadApiKey();
      
      // Update state after initialization
      setState(() {
        _isLoadingRemoteConfig = false;
      });
    } catch (e) {
      debugPrint('❌ ChatBot: Failed to initialize AI: $e');
      // Fallback to local key only
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

  Future<void> _loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final savedKey = prefs.getString(_apiKeyPrefKey);
    if (savedKey != null && savedKey.isNotEmpty) {
      AIChatService.setApiKey(savedKey);
      setState(() {
        _apiKey = savedKey;
      });
    }
  }

  Future<void> _saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyPrefKey, key);
    AIChatService.setApiKey(key);
    setState(() {
      _apiKey = key;
    });
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

    // If using Remote Config key, show success banner
    if (AIChatService.isInitialized && AIChatService.isUsingRemoteConfig) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.success.withValues(alpha: 0.1), AppTheme.accent.withValues(alpha: 0.1)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.cloud_done, color: AppTheme.success, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Using server API key - Ready to chat!',
                style: TextStyle(
                  color: AppTheme.success,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
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
              child: SelectableText(
                map['message'] ?? '',
                style: TextStyle(
                  color: isUser ? Colors.white : AppTheme.gray800,
                  fontSize: 15,
                  height: 1.4,
                ),
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
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.gray100,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _message,
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: InputDecoration(
                          hintText: AIChatService.isInitialized 
                              ? 'Ask me anything...' 
                              : 'Setup API key first...',
                          hintStyle: TextStyle(color: AppTheme.gray500),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        enabled: AIChatService.isInitialized,
                      ),
                    ),
                  ],
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

  void _sendMessage() async {
    final message = _message.text.trim();
    if (message.isEmpty || !AIChatService.isInitialized) return;

    setState(() {
      _message.clear();
      _isTyping = true;
      _showSuggestions = false;
    });

    HapticFeedback.lightImpact();

    // Save user message to Firestore
    await _firestore
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .collection('chatvsBot')
        .add({
      'sendBy': widget.user.displayName,
      'message': message,
      'type': 'text',
      'time': timeForMessage(DateTime.now().toString()),
      'timeStamp': DateTime.now(),
    });

    // Get AI response
    final response = await AIChatService.sendMessage(message);

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
    bool obscureKey = true;
    final remoteConfig = RemoteConfigService();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
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
                'AI Settings',
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
                // Current API Key Source Status
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AIChatService.isInitialized 
                        ? AppTheme.success.withValues(alpha: 0.1)
                        : AppTheme.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AIChatService.isInitialized 
                          ? AppTheme.success.withValues(alpha: 0.3)
                          : AppTheme.warning.withValues(alpha: 0.3),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current Status',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.gray500,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              AIChatService.apiKeySource,
                              style: TextStyle(
                                fontSize: 13,
                                color: AIChatService.isInitialized ? AppTheme.success : AppTheme.warning,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Server Key Option (if available)
                if (remoteConfig.hasApiKey && _apiKey != null && _apiKey!.isNotEmpty) ...[
                  Text(
                    'API Key Options',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.gray800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      // Clear custom key and use server key
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove(_apiKeyPrefKey);
                      await AIChatService.clearCustomApiKey();
                      setState(() {
                        _apiKey = null;
                      });
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Switched to server API key'),
                          backgroundColor: AppTheme.success,
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.gray100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.gray300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.cloud, color: AppTheme.accent, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Use Server API Key',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.gray800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios, color: AppTheme.gray400, size: 16),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Custom Key Input
                Text(
                  'Or enter your own API key:',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.gray700,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: apiKeyController,
                  obscureText: obscureKey,
                  decoration: InputDecoration(
                    hintText: 'AIza...',
                    prefixIcon: const Icon(Icons.vpn_key_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(obscureKey ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setDialogState(() => obscureKey = !obscureKey),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: AppTheme.accent, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Get your free API key from:\nmakersuite.google.com/app/apikey',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: AppTheme.gray600)),
            ),
            ElevatedButton(
              onPressed: () async {
                final key = apiKeyController.text.trim();
                if (key.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter an API key')),
                  );
                  return;
                }
                
                await _saveApiKey(key);
                Navigator.pop(context);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Custom API key saved!'),
                    backgroundColor: AppTheme.success,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Save Custom Key'),
            ),
          ],
        ),
      ),
    );
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
