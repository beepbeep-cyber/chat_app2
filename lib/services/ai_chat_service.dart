import 'dart:collection';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'remote_config_service.dart';

/// AI Chat Service using Google Gemini API
/// Hỗ trợ chat thông minh với AI, có memory và context
/// Tự động lấy API key từ Firebase Remote Config
/// ✅ FIXED: Client-side rate limiting để tránh server busy
class AIChatService {
  // Google Gemini API configuration
  static String? _apiKey;
  static String? _customApiKey;
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta';
  static String _model = 'gemini-2.0-flash';
  
  // Conversation history for context
  static final List<Map<String, String>> _conversationHistory = [];
  static const int _maxHistoryLength = 20;
  
  // ========== CLIENT-SIDE RATE LIMITING ==========
  // Gemini Free Tier: ~10-15 requests per minute
  static final Queue<DateTime> _requestTimestamps = Queue<DateTime>();
  static const int _maxRequestsPerMinute = 8; // Conservative limit (under 10)
  static const Duration _rateLimitWindow = Duration(minutes: 1);
  static DateTime? _lastRateLimitTime;
  static const int _cooldownSeconds = 60; // Increased to 60 seconds
  
  // List of valid/supported Gemini models
  static const List<String> _validModels = [
    'gemini-2.0-flash',
    'gemini-2.0-flash-exp',
    'gemini-1.5-flash',
    'gemini-1.5-flash-latest',
    'gemini-1.5-pro',
    'gemini-1.5-pro-latest',
    'gemini-pro',
  ];
  
  static const String _defaultModel = 'gemini-2.0-flash';

  /// Initialize with API key (manual)
  static void initialize(String apiKey) {
    _customApiKey = apiKey;
    _apiKey = apiKey;
    debugPrint('✅ AIChatService: Initialized with custom API key');
  }

  /// Initialize from Remote Config (automatic)
  static Future<void> initializeFromRemoteConfig() async {
    final remoteConfig = RemoteConfigService();
    
    if (!remoteConfig.isInitialized) {
      await remoteConfig.initialize();
    }
    
    // Priority 1: Check user's custom API key from Firestore
    await _loadUserApiKey();
    
    // Priority 2: Get API key from Remote Config
    if (_customApiKey == null || _customApiKey!.isEmpty) {
      final remoteApiKey = remoteConfig.geminiApiKey;
      if (remoteApiKey.isNotEmpty) {
        _apiKey = remoteApiKey;
        debugPrint('✅ AIChatService: Using API key from Remote Config');
      }
    }
    
    // Get model name from Remote Config
    final modelName = remoteConfig.aiModelName;
    if (modelName.isNotEmpty && _validModels.contains(modelName)) {
      _model = modelName;
      debugPrint('📡 AIChatService: Using model: $_model');
    } else {
      _model = _defaultModel;
      debugPrint('📡 AIChatService: Using default model: $_model');
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
          _apiKey = apiKey;
          debugPrint('✅ AIChatService: Using user\'s custom API key');
        }
      }
    } catch (e) {
      debugPrint('⚠️ AIChatService: Error loading user API key: $e');
    }
  }
  
  /// Check if service is initialized
  static bool get isInitialized {
    if (_customApiKey != null && _customApiKey!.isNotEmpty) return true;
    if (_apiKey != null && _apiKey!.isNotEmpty) return true;
    return false;
  }
  
  /// Check if using Remote Config key
  static bool get isUsingRemoteConfig {
    return (_customApiKey == null || _customApiKey!.isEmpty) && 
           (_apiKey != null && _apiKey!.isNotEmpty);
  }
  
  /// Set custom API key
  static void setApiKey(String apiKey) {
    _customApiKey = apiKey;
    _apiKey = apiKey;
  }
  
  /// Clear custom API key
  static Future<void> clearCustomApiKey() async {
    _customApiKey = null;
    await initializeFromRemoteConfig();
  }
  
  static String? get apiKey => _customApiKey ?? _apiKey;
  
  static String get apiKeySource {
    if (_customApiKey != null && _customApiKey!.isNotEmpty) {
      return 'Custom (User provided)';
    } else if (_apiKey != null && _apiKey!.isNotEmpty) {
      return 'Remote Config (Server)';
    }
    return 'Not configured';
  }
  
  /// Clear conversation history
  static void clearHistory() {
    _conversationHistory.clear();
    debugPrint('🗑️ AIChatService: Conversation history cleared');
  }
  
  // ========== RATE LIMIT HELPERS ==========
  
  /// Clean up old timestamps outside the rate limit window
  static void _cleanupOldTimestamps() {
    final now = DateTime.now();
    while (_requestTimestamps.isNotEmpty &&
        now.difference(_requestTimestamps.first) > _rateLimitWindow) {
      _requestTimestamps.removeFirst();
    }
  }
  
  /// Check if we can make a request (client-side check)
  static bool _canMakeRequest() {
    _cleanupOldTimestamps();
    return _requestTimestamps.length < _maxRequestsPerMinute;
  }
  
  /// Get remaining requests in current window
  static int get remainingRequests {
    _cleanupOldTimestamps();
    return _maxRequestsPerMinute - _requestTimestamps.length;
  }
  
  /// Get wait time until next request is allowed
  static Duration _getWaitTime() {
    if (_requestTimestamps.isEmpty) return Duration.zero;
    
    _cleanupOldTimestamps();
    
    if (_requestTimestamps.length < _maxRequestsPerMinute) {
      return Duration.zero;
    }
    
    final oldestRequest = _requestTimestamps.first;
    final waitUntil = oldestRequest.add(_rateLimitWindow);
    final now = DateTime.now();
    
    if (waitUntil.isAfter(now)) {
      return waitUntil.difference(now);
    }
    return Duration.zero;
  }
  
  /// Check cooldown from server rate limit
  static bool _isInCooldown() {
    if (_lastRateLimitTime == null) return false;
    
    final elapsed = DateTime.now().difference(_lastRateLimitTime!).inSeconds;
    return elapsed < _cooldownSeconds;
  }
  
  static int _getCooldownRemaining() {
    if (_lastRateLimitTime == null) return 0;
    
    final elapsed = DateTime.now().difference(_lastRateLimitTime!).inSeconds;
    final remaining = _cooldownSeconds - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  /// Send message to AI with rate limiting
  static Future<AIChatResponse> sendMessage(String message) async {
    if (!isInitialized) {
      return AIChatResponse(
        success: false,
        message: '⚠️ AI Service chưa được cấu hình.\n\nVui lòng thiết lập API key trong Settings.',
        error: 'NO_API_KEY',
      );
    }
    
    // Check 1: Server cooldown (from previous 429 error)
    if (_isInCooldown()) {
      final remaining = _getCooldownRemaining();
      return AIChatResponse(
        success: false,
        message: '⏳ Server đang nghỉ ngơi.\n\nVui lòng chờ $remaining giây nữa.\n\n💡 Mẹo: Gemini Free chỉ cho ~10 tin nhắn/phút.',
        error: 'RATE_LIMIT_COOLDOWN',
      );
    }
    
    // Check 2: Client-side rate limit
    if (!_canMakeRequest()) {
      final waitTime = _getWaitTime();
      return AIChatResponse(
        success: false,
        message: '⏳ Bạn đang gửi quá nhanh!\n\nChờ ${waitTime.inSeconds} giây nữa.\n\n📊 Còn $remainingRequests/$_maxRequestsPerMinute tin nhắn trong phút này.',
        error: 'CLIENT_RATE_LIMIT',
      );
    }
    
    try {
      // Record this request timestamp
      _requestTimestamps.add(DateTime.now());
      
      // Add user message to history
      _conversationHistory.add({
        'role': 'user',
        'parts': message,
      });
      
      // Trim history if too long
      if (_conversationHistory.length > _maxHistoryLength * 2) {
        _conversationHistory.removeRange(0, 2);
      }
      
      // Build request body
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
      
      final url = '$_baseUrl/models/$_model:generateContent?key=$_apiKey';
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        // Success - clear any cooldown
        _lastRateLimitTime = null;
        
        final data = jsonDecode(response.body);
        String aiMessage = '';
        
        if (data['candidates'] != null && data['candidates'].isNotEmpty) {
          final candidate = data['candidates'][0];
          if (candidate['content'] != null && 
              candidate['content']['parts'] != null &&
              candidate['content']['parts'].isNotEmpty) {
            aiMessage = candidate['content']['parts'][0]['text'] ?? '';
          }
        }
        
        if (aiMessage.isEmpty) {
          if (data['candidates']?[0]?['finishReason'] == 'SAFETY') {
            _removeLastUserMessage();
            return AIChatResponse(
              success: false,
              message: '🛡️ Tin nhắn bị chặn do chính sách an toàn.',
              error: 'SAFETY_BLOCK',
            );
          }
          
          _removeLastUserMessage();
          return AIChatResponse(
            success: false,
            message: '❓ Không nhận được phản hồi. Thử lại nhé!',
            error: 'EMPTY_RESPONSE',
          );
        }
        
        // Add AI response to history
        _conversationHistory.add({
          'role': 'model',
          'parts': aiMessage,
        });
        
        return AIChatResponse(
          success: true,
          message: aiMessage,
        );
        
      } else if (response.statusCode == 429) {
        // Rate limit from server - set cooldown
        _lastRateLimitTime = DateTime.now();
        _removeLastUserMessage();
        
        return AIChatResponse(
          success: false,
          message: '🔴 Server quá tải (Rate Limit)\n\n'
              '⏳ Vui lòng chờ $_cooldownSeconds giây.\n\n'
              '💡 Gemini Free Tier chỉ cho phép ~10-15 requests/phút.\n\n'
              '🔧 Giải pháp:\n'
              '• Chờ 1 phút rồi thử lại\n'
              '• Hoặc dùng API key riêng của bạn',
          error: 'RATE_LIMIT',
        );
        
      } else {
        // Other API errors
        final errorData = jsonDecode(response.body);
        String errorMessage = 'Unknown error';
        
        if (errorData['error'] != null) {
          errorMessage = errorData['error']['message'] ?? 'API Error';
          
          if (errorMessage.contains('API key')) {
            _removeLastUserMessage();
            return AIChatResponse(
              success: false,
              message: '🔑 API key không hợp lệ.\n\nVui lòng kiểm tra lại trong Settings.',
              error: 'INVALID_API_KEY',
            );
          }
        }
        
        debugPrint('❌ AIChatService: API Error: ${response.statusCode} - $errorMessage');
        _removeLastUserMessage();
        
        return AIChatResponse(
          success: false,
          message: '❌ Lỗi: $errorMessage',
          error: 'API_ERROR',
        );
      }
    } catch (e) {
      debugPrint('❌ AIChatService: Error: $e');
      _removeLastUserMessage();
      
      if (e.toString().contains('TimeoutException')) {
        return AIChatResponse(
          success: false,
          message: '⏱️ Timeout - Server phản hồi quá lâu.\n\nThử lại nhé!',
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
  
  /// Remove last user message from history (on error)
  static void _removeLastUserMessage() {
    if (_conversationHistory.isNotEmpty && 
        _conversationHistory.last['role'] == 'user') {
      _conversationHistory.removeLast();
    }
  }
  
  /// Get suggested prompts
  static List<String> getSuggestedPrompts() {
    return [
      '💡 Cho tôi một ý tưởng hay',
      '📝 Giúp tôi viết văn bản',
      '🧮 Giải bài toán',
      '🌍 Kể về một đất nước',
      '📚 Giải thích khái niệm',
      '🎯 Cho tôi lời khuyên',
      '💻 Hỗ trợ lập trình',
      '🇬🇧 Dịch sang tiếng Anh',
    ];
  }
  
  /// Get conversation history
  static List<Map<String, String>> get conversationHistory => 
      List.unmodifiable(_conversationHistory);
      
  /// Get rate limit status for UI display
  static String get rateLimitStatus {
    if (_isInCooldown()) {
      return '🔴 Cooldown: ${_getCooldownRemaining()}s';
    }
    return '🟢 $remainingRequests/$_maxRequestsPerMinute';
  }
}

/// Response model for AI Chat
class AIChatResponse {
  final bool success;
  final String message;
  final String? error;
  
  AIChatResponse({
    required this.success,
    required this.message,
    this.error,
  });
}
