import 'dart:collection';
import 'dart:convert';
import 'dart:math' show Random, min;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'remote_config_service.dart';

/// AI Chat Service using Google Gemini API
/// ✅ SOLUTION: Multiple API Keys Rotation to avoid rate limits
/// 
/// Cách hoạt động:
/// 1. Lưu nhiều API keys trong Firebase Remote Config (gemini_api_keys)
/// 2. Mỗi user được assign 1 key ngẫu nhiên
/// 3. Nếu key bị rate limit → tự động chuyển sang key khác
/// 4. Nếu tất cả keys đều bị limit → thông báo user chờ
class AIChatService {
  // API Configuration
  static List<String> _apiKeys = []; // Multiple keys for rotation
  static int _currentKeyIndex = 0;
  static String? _customApiKey; // User's personal key (highest priority)
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta';
  static String _model = 'gemini-2.5-flash';
  
  // Track which keys are rate limited
  static final Map<int, DateTime> _rateLimitedKeys = {};
  static const int _keyRateLimitCooldown = 65; // 65 seconds cooldown per key
  
  // Conversation history
  static final List<Map<String, String>> _conversationHistory = [];
  static const int _maxHistoryLength = 20;
  
  // Client-side rate limiting (per user)
  static final Queue<DateTime> _requestTimestamps = Queue<DateTime>();
  static const int _maxRequestsPerMinute = 8; // Reduced to leave buffer
  static const Duration _rateLimitWindow = Duration(minutes: 1);
  
  // Server-side rate limit tracking
  static DateTime? _globalRateLimitUntil;
  static const int _globalCooldownSeconds = 70; // Wait longer after all keys fail
  
  // Valid models
  static const List<String> _validModels = [
    'gemini-2.5-flash',
    'gemini-2.5-pro',
    'gemini-2.0-flash-exp',
    'gemini-2.0-flash',
    'gemini-1.5-flash-latest',
    'gemini-1.5-flash',
    'gemini-1.5-pro-latest',
    'gemini-1.5-pro',
    'gemini-pro',
  ];
  
  static const String _defaultModel = 'gemini-2.5-flash';

  /// Initialize with custom API key
  static void initialize(String apiKey) {
    _customApiKey = apiKey;
    debugPrint('✅ AIChatService: Initialized with custom API key');
  }

  /// Initialize from Remote Config with multiple keys support
  static Future<void> initializeFromRemoteConfig() async {
    final remoteConfig = RemoteConfigService();
    
    if (!remoteConfig.isInitialized) {
      await remoteConfig.initialize();
    }
    
    // FORCE refresh Remote Config to get latest keys
    try {
      await remoteConfig.refresh();
      debugPrint('🔄 Remote Config refreshed');
    } catch (e) {
      debugPrint('⚠️ Remote Config refresh failed: $e');
    }
    
    // Priority 1: User's custom API key from Firestore
    await _loadUserApiKey();
    
    // Priority 2: Load multiple API keys from Remote Config
    if (_customApiKey == null || _customApiKey!.isEmpty) {
      await _loadMultipleApiKeys(remoteConfig);
    }
    
    // Load model preference
    final modelName = remoteConfig.aiModelName;
    if (modelName.isNotEmpty && _validModels.contains(modelName)) {
      _model = modelName;
    } else {
      _model = _defaultModel;
    }
    
    // Assign a random key index to this user (for load distribution)
    await _assignKeyToUser();
    
    debugPrint('✅ AIChatService: Initialized with ${_apiKeys.length} API keys');
    debugPrint('📡 Using model: $_model');
  }
  
  /// Load multiple API keys from Remote Config
  static Future<void> _loadMultipleApiKeys(RemoteConfigService remoteConfig) async {
    _apiKeys.clear();
    
    // 🔥 TEMPORARY FIX: Hardcode keys for testing
    // TODO: Remove this after Remote Config is fixed
    const hardcodedKeys = [
      'AIzaSyC0JZBVaCyq8FUiakLT73Wfg0TBxzLkmQk',
      'AIzaSyAxSt3RGX0PtGGjR3H1Uv3z8UL-NfBp_wk',
      'AIzaSyAiaBz4nSAwgUexE7eIYkF6eyUcXJpcpiI',
      'AIzaSyATkoDQA5I1BMWkhg2sbk02w1yTdf5AdsI',
      'AIzaSyBWPFwPm_pACYSxN0SJsFbUkVqS16rJScU',
    ];
    
    debugPrint('═══════════════════════════════════════');
    debugPrint('🔥 USING HARDCODED KEYS (TESTING MODE)');
    debugPrint('═══════════════════════════════════════');
    
    _apiKeys.addAll(hardcodedKeys);
    debugPrint('✅ Loaded ${_apiKeys.length} hardcoded keys');
    for (int i = 0; i < _apiKeys.length; i++) {
      debugPrint('   Key ${i + 1}: ${_apiKeys[i].substring(0, 10)}...${_apiKeys[i].substring(_apiKeys[i].length - 5)}');
    }
    
    // Assign random key to this user session
    _assignKeyToUser();
    debugPrint('═══════════════════════════════════════');
    return; // Skip Remote Config for now
    
    // Try to get multiple keys (comma-separated or JSON array)
    final keysString = remoteConfig.geminiApiKeys; // New field for multiple keys
    
    debugPrint('═══════════════════════════════════════');
    debugPrint('🔍 Loading API Keys from Remote Config');
    debugPrint('═══════════════════════════════════════');
    debugPrint('📝 Raw gemini_api_keys:');
    debugPrint('   Length: ${keysString.length}');
    if (keysString.length > 0) {
      debugPrint('   First 30 chars: "${keysString.length > 30 ? keysString.substring(0, 30) + '...' : keysString}"');
      debugPrint('   Last 30 chars: "${keysString.length > 30 ? '...' + keysString.substring(keysString.length - 30) : keysString}"');
    }
    debugPrint('');
    
    if (keysString.isNotEmpty) {
      // Try JSON array first
      debugPrint('🧪 Attempting JSON array parsing...');
      try {
        final List<dynamic> keysList = jsonDecode(keysString);
        debugPrint('✅ Valid JSON array with ${keysList.length} elements');
        
        for (int i = 0; i < keysList.length; i++) {
          final rawKey = keysList[i].toString();
          // Clean the key thoroughly
          final cleanKey = rawKey
              .trim()
              .replaceAll('"', '')
              .replaceAll("'", '')
              .replaceAll('\n', '')
              .replaceAll('\r', '')
              .replaceAll('\t', '');
          
          debugPrint('');
          debugPrint('   Key $i:');
          debugPrint('      Raw length: ${rawKey.length}');
          debugPrint('      Clean length: ${cleanKey.length}');
          debugPrint('      First 10 chars: "${cleanKey.length >= 10 ? cleanKey.substring(0, 10) : cleanKey}"');
          debugPrint('      Starts with AIza: ${cleanKey.startsWith('AIza')}');
          
          if (cleanKey.isNotEmpty && cleanKey.startsWith('AIza')) {
            _apiKeys.add(cleanKey);
            debugPrint('      ✅ Added to list');
          } else {
            debugPrint('      ❌ Invalid format - skipped');
          }
        }
        debugPrint('');
        debugPrint('📋 Parsed ${_apiKeys.length} valid keys from JSON array');
      } catch (e) {
        debugPrint('❌ JSON parsing failed: $e');
        debugPrint('');
        
        // Fallback: comma-separated
        debugPrint('🧪 Attempting comma-separated parsing...');
        final parts = keysString.split(',');
        debugPrint('   Found ${parts.length} parts');
        
        for (int i = 0; i < parts.length; i++) {
          final rawKey = parts[i];
          // Clean the key thoroughly
          final cleanKey = rawKey
              .trim()
              .replaceAll('"', '')
              .replaceAll("'", '')
              .replaceAll('[', '')
              .replaceAll(']', '')
              .replaceAll('\n', '')
              .replaceAll('\r', '')
              .replaceAll('\t', '');
          
          debugPrint('');
          debugPrint('   Part $i:');
          debugPrint('      Raw length: ${rawKey.length}');
          debugPrint('      Clean length: ${cleanKey.length}');
          debugPrint('      First 10 chars: "${cleanKey.length >= 10 ? cleanKey.substring(0, 10) : cleanKey}"');
          debugPrint('      Starts with AIza: ${cleanKey.startsWith('AIza')}');
          
          if (cleanKey.isNotEmpty && cleanKey.startsWith('AIza')) {
            _apiKeys.add(cleanKey);
            debugPrint('      ✅ Added to list');
          } else {
            debugPrint('      ❌ Invalid format - skipped');
          }
        }
        debugPrint('');
        debugPrint('📋 Parsed ${_apiKeys.length} valid keys from comma-separated');
      }
    }
    
    // Fallback to single key if no multiple keys
    if (_apiKeys.isEmpty) {
      debugPrint('⚠️ No valid keys found in gemini_api_keys');
      debugPrint('🔄 Trying fallback to single gemini_api_key...');
      final singleKey = remoteConfig.geminiApiKey;
      if (singleKey.isNotEmpty) {
        final cleanKey = singleKey
            .trim()
            .replaceAll('"', '')
            .replaceAll("'", '');
        if (cleanKey.startsWith('AIza')) {
          _apiKeys = [cleanKey];
          debugPrint('✅ Fallback to single key successful');
        } else {
          debugPrint('❌ Single key also invalid');
        }
      } else {
        debugPrint('❌ Single key is empty');
      }
    }
    
    debugPrint('');
    debugPrint('📡 FINAL RESULT: ${_apiKeys.length} valid API keys loaded');
    
    // Log first few chars of each key for verification
    for (int i = 0; i < _apiKeys.length; i++) {
      final key = _apiKeys[i];
      debugPrint('  ✓ Key $i: ${key.substring(0, min(10, key.length))}... (length: ${key.length})');
    }
    debugPrint('═══════════════════════════════════════');
    debugPrint('');
  }
  
  /// Assign a random key index to user (truly random each session for better distribution)
  static Future<void> _assignKeyToUser() async {
    if (_apiKeys.isEmpty) return;
    
    try {
      // ALWAYS assign random key each session for better load distribution
      // Don't use saved index - it causes all users to pile up on same keys
      _currentKeyIndex = Random().nextInt(_apiKeys.length);
      
      debugPrint('🔑 User assigned to key index: $_currentKeyIndex (total: ${_apiKeys.length})');
    } catch (e) {
      _currentKeyIndex = 0;
    }
  }
  
  /// Load user's custom API key from Firestore
  static Future<void> _loadUserApiKey() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (doc.exists && doc.data() != null) {
        final apiKey = doc.data()!['geminiApiKey'] as String?;
        if (apiKey != null && apiKey.isNotEmpty) {
          _customApiKey = apiKey;
          debugPrint('✅ Using user\'s custom API key');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error loading user API key: $e');
    }
  }
  
  /// Get current active API key
  static String? get _activeApiKey {
    if (_customApiKey != null && _customApiKey!.isNotEmpty) {
      return _customApiKey;
    }
    if (_apiKeys.isNotEmpty && _currentKeyIndex < _apiKeys.length) {
      return _apiKeys[_currentKeyIndex];
    }
    return null;
  }
  
  /// Check if service is ready
  static bool get isInitialized {
    return _customApiKey != null && _customApiKey!.isNotEmpty || _apiKeys.isNotEmpty;
  }
  
  static bool get isUsingRemoteConfig {
    return (_customApiKey == null || _customApiKey!.isEmpty) && _apiKeys.isNotEmpty;
  }
  
  static void setApiKey(String apiKey) {
    _customApiKey = apiKey;
  }
  
  static Future<void> clearCustomApiKey() async {
    _customApiKey = null;
    await initializeFromRemoteConfig();
  }
  
  static String? get apiKey => _activeApiKey;
  
  static String get apiKeySource {
    if (_customApiKey != null && _customApiKey!.isNotEmpty) {
      return 'Custom (Your key)';
    } else if (_apiKeys.isNotEmpty) {
      return 'Server (${_apiKeys.length} keys available)';
    }
    return 'Not configured';
  }
  
  static void clearHistory() {
    _conversationHistory.clear();
  }
  
  // ========== RATE LIMIT HELPERS ==========
  
  static void _cleanupTimestamps() {
    final now = DateTime.now();
    while (_requestTimestamps.isNotEmpty &&
        now.difference(_requestTimestamps.first) > _rateLimitWindow) {
      _requestTimestamps.removeFirst();
    }
  }
  
  static bool _canMakeRequest() {
    _cleanupTimestamps();
    return _requestTimestamps.length < _maxRequestsPerMinute;
  }
  
  static int get remainingRequests {
    _cleanupTimestamps();
    return _maxRequestsPerMinute - _requestTimestamps.length;
  }
  
  /// Check if current key is rate limited
  static bool _isCurrentKeyLimited() {
    if (_customApiKey != null) return false; // Custom key not tracked
    
    final limitTime = _rateLimitedKeys[_currentKeyIndex];
    if (limitTime == null) return false;
    
    final elapsed = DateTime.now().difference(limitTime).inSeconds;
    if (elapsed >= _keyRateLimitCooldown) {
      _rateLimitedKeys.remove(_currentKeyIndex);
      return false;
    }
    return true;
  }
  
  /// Find next available (non-rate-limited) key
  static bool _switchToNextAvailableKey() {
    if (_apiKeys.length <= 1) return false;
    
    final originalIndex = _currentKeyIndex;
    
    for (int i = 0; i < _apiKeys.length; i++) {
      _currentKeyIndex = (_currentKeyIndex + 1) % _apiKeys.length;
      
      if (!_isKeyLimited(_currentKeyIndex)) {
        debugPrint('🔄 Switched to key index: $_currentKeyIndex');
        return true;
      }
    }
    
    // All keys are limited, restore original
    _currentKeyIndex = originalIndex;
    return false;
  }
  
  static bool _isKeyLimited(int index) {
    final limitTime = _rateLimitedKeys[index];
    if (limitTime == null) return false;
    
    final elapsed = DateTime.now().difference(limitTime).inSeconds;
    return elapsed < _keyRateLimitCooldown;
  }
  
  /// Mark current key as rate limited
  static void _markKeyAsLimited() {
    _rateLimitedKeys[_currentKeyIndex] = DateTime.now();
    debugPrint('🔴 Key $_currentKeyIndex marked as rate limited');
  }
  
  /// Get available keys count
  static int get availableKeysCount {
    if (_customApiKey != null) return 1;
    
    int count = 0;
    for (int i = 0; i < _apiKeys.length; i++) {
      if (!_isKeyLimited(i)) count++;
    }
    return count;
  }

  /// Check if we're in global cooldown (all keys failed recently)
  static bool _isInGlobalCooldown() {
    if (_globalRateLimitUntil == null) return false;
    if (DateTime.now().isAfter(_globalRateLimitUntil!)) {
      _globalRateLimitUntil = null;
      _rateLimitedKeys.clear(); // Reset all key limits
      return false;
    }
    return true;
  }
  
  /// Get remaining global cooldown seconds
  static int get globalCooldownRemaining {
    if (_globalRateLimitUntil == null) return 0;
    final remaining = _globalRateLimitUntil!.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  /// Send message with automatic key rotation
  static Future<AIChatResponse> sendMessage(String message) async {
    if (!isInitialized) {
      return AIChatResponse(
        success: false,
        message: '⚠️ AI chưa được cấu hình.\n\nVui lòng thiết lập API key trong Settings.',
        error: 'NO_API_KEY',
      );
    }
    
    // Check global cooldown first
    if (_isInGlobalCooldown()) {
      final waitTime = globalCooldownRemaining;
      return AIChatResponse(
        success: false,
        message: '🔴 Server đang quá tải!\n\n⏳ Tự động thử lại sau $waitTime giây.\n\n💡 Hoặc dùng API key riêng trong Settings.',
        error: 'GLOBAL_COOLDOWN',
        cooldownSeconds: waitTime,
      );
    }
    
    // Check client-side rate limit
    if (!_canMakeRequest()) {
      final waitTime = _getClientWaitTime();
      return AIChatResponse(
        success: false,
        message: '⏳ Bạn đang gửi quá nhanh!\n\nChờ $waitTime giây rồi thử lại.',
        error: 'CLIENT_RATE_LIMIT',
        cooldownSeconds: waitTime,
      );
    }
    
    // Check if current key is limited, try to switch
    if (_isCurrentKeyLimited() && !_switchToNextAvailableKey()) {
      // All keys are limited - set global cooldown
      _globalRateLimitUntil = DateTime.now().add(Duration(seconds: _globalCooldownSeconds));
      final waitTime = _globalCooldownSeconds;
      return AIChatResponse(
        success: false,
        message: '🔴 Tất cả server đang bận.\n\n⏳ Chờ $waitTime giây nữa.\n\n💡 Hoặc dùng API key riêng của bạn trong Settings.',
        error: 'ALL_KEYS_LIMITED',
        cooldownSeconds: waitTime,
      );
    }
    
    // Record request
    _requestTimestamps.add(DateTime.now());
    
    // Try to send with retry on different keys
    return await _sendWithRetry(message, maxRetries: _apiKeys.length > 0 ? _apiKeys.length : 1);
  }
  
  /// Get client-side wait time
  static int _getClientWaitTime() {
    if (_requestTimestamps.isEmpty) return 0;
    final oldest = _requestTimestamps.first;
    final elapsed = DateTime.now().difference(oldest).inSeconds;
    return (60 - elapsed).clamp(0, 60);
  }
  
  /// Send message with automatic retry on rate limit
  static Future<AIChatResponse> _sendWithRetry(String message, {int maxRetries = 3}) async {
    int attempts = 0;
    
    while (attempts < maxRetries) {
      final result = await _sendRequest(message);
      
      if (result.success) {
        return result;
      }
      
      // If rate limited with custom API key - cannot retry
      if (result.error == 'RATE_LIMIT' && _customApiKey != null && _customApiKey!.isNotEmpty) {
        debugPrint('🔴 Custom API key rate limited - cannot switch');
        return AIChatResponse(
          success: false,
          message: '🔴 API key của bạn đã vượt giới hạn!\n\n'
              '⏳ Vui lòng chờ 1 phút rồi thử lại.\n\n'
              '💡 Hoặc tạo API key mới tại:\n'
              'https://aistudio.google.com/app/apikey',
          error: 'CUSTOM_KEY_RATE_LIMITED',
          cooldownSeconds: 60,
        );
      }
      
      // If rate limited with server keys, try next key
      if (result.error == 'RATE_LIMIT' && _apiKeys.length > 1) {
        _markKeyAsLimited();
        
        if (_switchToNextAvailableKey()) {
          attempts++;
          debugPrint('🔄 Retrying with different key (attempt $attempts)');
          continue;
        }
      }
      
      // Other errors or no more keys - return result
      return result;
    }
    
    return AIChatResponse(
      success: false,
      message: '🔴 Tất cả server đang quá tải.\n\nVui lòng thử lại sau 1 phút.',
      error: 'ALL_RETRIES_FAILED',
    );
  }
  
  /// Send actual API request
  static Future<AIChatResponse> _sendRequest(String message) async {
    final apiKey = _activeApiKey;
    if (apiKey == null) {
      debugPrint('❌ [AI Request] No API key available');
      return AIChatResponse(
        success: false,
        message: '⚠️ Không có API key.',
        error: 'NO_API_KEY',
      );
    }
    
    // Validate API key format
    if (!apiKey.startsWith('AIza')) {
      debugPrint('❌ [AI Request] Invalid API key format');
      debugPrint('   Key preview: ${apiKey.substring(0, min(10, apiKey.length))}...');
      debugPrint('   Key length: ${apiKey.length}');
      return AIChatResponse(
        success: false,
        message: '🔑 API key không đúng định dạng.\n\nKey phải bắt đầu với "AIza"',
        error: 'INVALID_API_KEY_FORMAT',
      );
    }
    
    debugPrint('🚀 [AI Request] Sending message...');
    debugPrint('   Model: $_model');
    debugPrint('   Key index: $_currentKeyIndex/${_apiKeys.length}');
    debugPrint('   Key preview: ${apiKey.substring(0, min(10, apiKey.length))}...');
    debugPrint('   Key length: ${apiKey.length}');
    
    try {
      // Add to history
      _conversationHistory.add({'role': 'user', 'parts': message});
      
      if (_conversationHistory.length > _maxHistoryLength * 2) {
        _conversationHistory.removeRange(0, 2);
      }
      
      final contents = _conversationHistory.map((msg) => {
        'role': msg['role'],
        'parts': [{'text': msg['parts']}],
      }).toList();
      
      final requestBody = {
        'contents': contents,
        'generationConfig': {
          'temperature': 0.7,
          'topK': 40,
          'topP': 0.95,
          'maxOutputTokens': 1024,
        },
        'safetySettings': [
          {'category': 'HARM_CATEGORY_HARASSMENT', 'threshold': 'BLOCK_ONLY_HIGH'},
          {'category': 'HARM_CATEGORY_HATE_SPEECH', 'threshold': 'BLOCK_ONLY_HIGH'},
          {'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT', 'threshold': 'BLOCK_ONLY_HIGH'},
          {'category': 'HARM_CATEGORY_DANGEROUS_CONTENT', 'threshold': 'BLOCK_ONLY_HIGH'},
        ],
      };
      
      final url = '$_baseUrl/models/$_model:generateContent?key=$apiKey';
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String aiMessage = '';
        
        if (data['candidates'] != null && data['candidates'].isNotEmpty) {
          final candidate = data['candidates'][0];
          if (candidate['content']?['parts']?.isNotEmpty == true) {
            aiMessage = candidate['content']['parts'][0]['text'] ?? '';
          }
        }
        
        if (aiMessage.isEmpty) {
          _removeLastUserMessage();
          return AIChatResponse(
            success: false,
            message: '❓ Không nhận được phản hồi. Thử lại nhé!',
            error: 'EMPTY_RESPONSE',
          );
        }
        
        _conversationHistory.add({'role': 'model', 'parts': aiMessage});
        
        return AIChatResponse(success: true, message: aiMessage);
        
      } else if (response.statusCode == 429) {
        debugPrint('⏰ [AI Response] Rate limited (429)');
        _removeLastUserMessage();
        return AIChatResponse(
          success: false,
          message: '🔴 Server đang bận...',
          error: 'RATE_LIMIT',
        );
        
      } else {
        debugPrint('❌ [AI Response] Error ${response.statusCode}');
        debugPrint('   Response body: ${response.body}');
        _removeLastUserMessage();
        
        try {
          final errorData = jsonDecode(response.body);
          final errorMsg = errorData['error']?['message'] ?? 'Unknown error';
          final errorStatus = errorData['error']?['status'] ?? '';
          
          debugPrint('   Error message: $errorMsg');
          debugPrint('   Error status: $errorStatus');
          
          if (errorMsg.contains('API key') || errorStatus.contains('INVALID')) {
            return AIChatResponse(
              success: false,
              message: '🔑 API key không hợp lệ.\n\nChi tiết: $errorMsg',
              error: 'INVALID_API_KEY',
            );
          }
          
          return AIChatResponse(
            success: false,
            message: '❌ Lỗi: $errorMsg',
            error: 'API_ERROR',
          );
        } catch (e) {
          debugPrint('   Failed to parse error response: $e');
          return AIChatResponse(
            success: false,
            message: '❌ Lỗi HTTP ${response.statusCode}',
            error: 'API_ERROR',
          );
        }
      }
    } catch (e) {
      _removeLastUserMessage();
      
      if (e.toString().contains('TimeoutException')) {
        return AIChatResponse(
          success: false,
          message: '⏱️ Timeout. Thử lại nhé!',
          error: 'TIMEOUT',
        );
      }
      
      return AIChatResponse(
        success: false,
        message: '📡 Lỗi mạng. Kiểm tra kết nối internet.',
        error: 'NETWORK_ERROR',
      );
    }
  }
  
  static void _removeLastUserMessage() {
    if (_conversationHistory.isNotEmpty && _conversationHistory.last['role'] == 'user') {
      _conversationHistory.removeLast();
    }
  }
  
  static int _getMinWaitTime() {
    if (_rateLimitedKeys.isEmpty) return 0;
    
    int minWait = _keyRateLimitCooldown;
    final now = DateTime.now();
    
    for (final entry in _rateLimitedKeys.entries) {
      final elapsed = now.difference(entry.value).inSeconds;
      final remaining = _keyRateLimitCooldown - elapsed;
      if (remaining > 0 && remaining < minWait) {
        minWait = remaining;
      }
    }
    
    return minWait;
  }
  
  static List<String> getSuggestedPrompts() {
    return [
      '💡 Cho tôi ý tưởng hay',
      '📝 Giúp viết văn bản',
      '🧮 Giải bài toán',
      '📚 Giải thích khái niệm',
      '💻 Hỗ trợ code',
      '🇬🇧 Dịch tiếng Anh',
    ];
  }
  
  static List<Map<String, String>> get conversationHistory => 
      List.unmodifiable(_conversationHistory);
      
  static String get rateLimitStatus {
    // Check global cooldown first
    if (_isInGlobalCooldown()) {
      return '🔴 Cooldown ${globalCooldownRemaining}s';
    }
    
    final available = availableKeysCount;
    final total = _apiKeys.isEmpty ? 1 : _apiKeys.length;
    
    if (available == 0) {
      return '🔴 All busy (${_getMinWaitTime()}s)';
    }
    return '🟢 $available/$total servers';
  }
  
  /// Get detailed status for UI
  static Map<String, dynamic> get detailedStatus {
    return {
      'isReady': isInitialized && !_isInGlobalCooldown() && availableKeysCount > 0,
      'totalKeys': _apiKeys.isEmpty ? 1 : _apiKeys.length,
      'availableKeys': availableKeysCount,
      'remainingRequests': remainingRequests,
      'globalCooldown': globalCooldownRemaining,
      'isUsingCustomKey': _customApiKey != null && _customApiKey!.isNotEmpty,
      'statusText': rateLimitStatus,
    };
  }
  
  /// Force reset all rate limits (for testing/admin)
  static void resetAllLimits() {
    _rateLimitedKeys.clear();
    _globalRateLimitUntil = null;
    _requestTimestamps.clear();
    debugPrint('🔄 All rate limits reset');
  }
}

class AIChatResponse {
  final bool success;
  final String message;
  final String? error;
  final int? cooldownSeconds; // Time to wait before retrying
  
  AIChatResponse({
    required this.success,
    required this.message,
    this.error,
    this.cooldownSeconds,
  });
  
  /// Check if response indicates rate limiting
  bool get isRateLimited => 
      error == 'RATE_LIMIT' || 
      error == 'ALL_KEYS_LIMITED' || 
      error == 'GLOBAL_COOLDOWN' ||
      error == 'CLIENT_RATE_LIMIT' ||
      error == 'CUSTOM_KEY_RATE_LIMITED';
}
