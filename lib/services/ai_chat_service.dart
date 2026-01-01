import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'remote_config_service.dart';

/// AI Chat Service using Google Gemini API
/// Hỗ trợ chat thông minh với AI, có memory và context
/// Tự động lấy API key từ Firebase Remote Config
class AIChatService {
  // Google Gemini API configuration
  static String? _apiKey;
  static String? _customApiKey; // User's custom API key (priority over Remote Config)
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta';
  static String _model = 'gemini-2.0-flash'; // Can be updated from Remote Config
  
  // Conversation history for context
  static final List<Map<String, String>> _conversationHistory = [];
  static const int _maxHistoryLength = 20; // Keep last 20 messages for context
  
  /// Initialize with API key (manual)
  static void initialize(String apiKey) {
    _customApiKey = apiKey;
    _apiKey = apiKey;
    debugPrint('✅ AIChatService: Initialized with custom API key');
  }
  
  // List of valid/supported Gemini models
  static const List<String> _validModels = [
    'gemini-2.0-flash',
    'gemini-2.0-flash-exp',
    'gemini-1.5-pro',
    'gemini-1.5-pro-latest',
    'gemini-pro',
  ];
  
  // Default fallback model (always use this if remote config model is invalid)
  static const String _defaultModel = 'gemini-2.0-flash';

  /// Initialize from Remote Config (automatic)
  static Future<void> initializeFromRemoteConfig() async {
    final remoteConfig = RemoteConfigService();
    
    if (!remoteConfig.isInitialized) {
      await remoteConfig.initialize();
    }
    
    // Get API key from Remote Config (if no custom key set)
    if (_customApiKey == null || _customApiKey!.isEmpty) {
      final remoteApiKey = remoteConfig.geminiApiKey;
      if (remoteApiKey.isNotEmpty) {
        _apiKey = remoteApiKey;
        debugPrint('✅ AIChatService: Using API key from Remote Config');
      }
    }
    
    // Get model name from Remote Config
    final modelName = remoteConfig.aiModelName;
    if (modelName.isNotEmpty) {
      // Validate model name - check if it's a valid/supported model
      if (_validModels.contains(modelName)) {
        _model = modelName;
        debugPrint('📡 AIChatService: Using model from Remote Config: $_model');
      } else {
        // Model from Remote Config is invalid/deprecated, use default
        _model = _defaultModel;
        debugPrint('⚠️ AIChatService: Model "$modelName" from Remote Config is invalid/deprecated');
        debugPrint('📡 AIChatService: Falling back to default model: $_model');
      }
    } else {
      // No model in Remote Config, use default
      _model = _defaultModel;
      debugPrint('📡 AIChatService: No model in Remote Config, using default: $_model');
    }
  }
  
  /// Check if service is initialized
  static bool get isInitialized {
    // Priority: custom key > remote config key
    if (_customApiKey != null && _customApiKey!.isNotEmpty) return true;
    if (_apiKey != null && _apiKey!.isNotEmpty) return true;
    return false;
  }
  
  /// Check if using Remote Config key
  static bool get isUsingRemoteConfig {
    return (_customApiKey == null || _customApiKey!.isEmpty) && 
           (_apiKey != null && _apiKey!.isNotEmpty);
  }
  
  /// Set custom API key (user provided)
  static void setApiKey(String apiKey) {
    _customApiKey = apiKey;
    _apiKey = apiKey;
  }
  
  /// Clear custom API key (revert to Remote Config)
  static Future<void> clearCustomApiKey() async {
    _customApiKey = null;
    await initializeFromRemoteConfig();
  }
  
  /// Get current API key (masked for security)
  static String? get apiKey => _customApiKey ?? _apiKey;
  
  /// Get API key source
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
  
  // Rate limit handling - increased delays for Gemini API
  static int _rateLimitRetryCount = 0;
  static const int _maxRetries = 2; // Reduced retries, show message faster
  static DateTime? _lastRateLimitTime;
  static const int _rateLimitDelaySeconds = 15; // Increased from 5 to 15 seconds
  
  /// Send message to AI and get response with retry logic for rate limits
  static Future<AIChatResponse> sendMessage(String message, {int retryCount = 0}) async {
    if (!isInitialized) {
      return AIChatResponse(
        success: false,
        message: 'AI Service not initialized. Please set your API key in Settings.',
        error: 'NO_API_KEY',
      );
    }
    
    // Check if we need to wait due to previous rate limit (30 second cooldown)
    if (_lastRateLimitTime != null) {
      final cooldownSeconds = 30;
      final elapsed = DateTime.now().difference(_lastRateLimitTime!).inSeconds;
      if (elapsed < cooldownSeconds) {
        final remaining = cooldownSeconds - elapsed;
        return AIChatResponse(
          success: false,
          message: '⏳ Please wait $remaining seconds before trying again.\n\nThe server needs time to reset.',
          error: 'RATE_LIMIT_WAIT',
        );
      } else {
        // Cooldown finished, reset
        _lastRateLimitTime = null;
      }
    }
    
    try {
      // Add user message to history
      _conversationHistory.add({
        'role': 'user',
        'parts': message,
      });
      
      // Trim history if too long
      if (_conversationHistory.length > _maxHistoryLength * 2) {
        _conversationHistory.removeRange(0, 2);
      }
      
      // Build request body with conversation history
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
          {
            'category': 'HARM_CATEGORY_HARASSMENT',
            'threshold': 'BLOCK_ONLY_HIGH',
          },
          {
            'category': 'HARM_CATEGORY_HATE_SPEECH',
            'threshold': 'BLOCK_ONLY_HIGH',
          },
          {
            'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
            'threshold': 'BLOCK_ONLY_HIGH',
          },
          {
            'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
            'threshold': 'BLOCK_ONLY_HIGH',
          },
        ],
      };
      
      final url = '$_baseUrl/models/$_model:generateContent?key=$_apiKey';
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );
      
      if (response.statusCode == 200) {
        // Reset rate limit tracking on success
        _rateLimitRetryCount = 0;
        _lastRateLimitTime = null;
        
        final data = jsonDecode(response.body);
        
        // Extract response text
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
          // Check for safety block
          if (data['candidates']?[0]?['finishReason'] == 'SAFETY') {
            return AIChatResponse(
              success: false,
              message: 'I cannot respond to that message due to safety guidelines.',
              error: 'SAFETY_BLOCK',
            );
          }
          
          return AIChatResponse(
            success: false,
            message: 'I couldn\'t generate a response. Please try again.',
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
      } else {
        // Handle API errors
        final errorData = jsonDecode(response.body);
        String errorMessage = 'Unknown error';
        
        if (errorData['error'] != null) {
          errorMessage = errorData['error']['message'] ?? 'API Error';
          
          // Check for specific errors
          if (errorMessage.contains('API key')) {
            // Remove last user message since request failed
            if (_conversationHistory.isNotEmpty && 
                _conversationHistory.last['role'] == 'user') {
              _conversationHistory.removeLast();
            }
            return AIChatResponse(
              success: false,
              message: 'Invalid API key. Please check your API key in Settings.',
              error: 'INVALID_API_KEY',
            );
          }
          
          // Handle rate limit with exponential backoff retry
          if (response.statusCode == 429) {
            _lastRateLimitTime = DateTime.now();
            _rateLimitRetryCount++;
            
            // Remove last user message for retry
            if (_conversationHistory.isNotEmpty && 
                _conversationHistory.last['role'] == 'user') {
              _conversationHistory.removeLast();
            }
            
            // Don't auto-retry, let user know immediately
            // Auto-retry causes confusion and long waits
            return AIChatResponse(
              success: false,
              message: '⏳ Server is busy (rate limit). Please wait 30-60 seconds and try again.\n\n💡 Tip: Get your own FREE API key from Google AI Studio for unlimited usage:\nhttps://aistudio.google.com/app/apikey',
              error: 'RATE_LIMIT',
            );
          }
        }
        
        debugPrint('❌ AIChatService: API Error: ${response.statusCode} - $errorMessage');
        
        // Remove last user message since request failed
        if (_conversationHistory.isNotEmpty && 
            _conversationHistory.last['role'] == 'user') {
          _conversationHistory.removeLast();
        }
        
        return AIChatResponse(
          success: false,
          message: 'Failed to get response: $errorMessage',
          error: 'API_ERROR',
        );
      }
    } catch (e) {
      debugPrint('❌ AIChatService: Error: $e');
      
      // Remove last user message since request failed
      if (_conversationHistory.isNotEmpty && 
          _conversationHistory.last['role'] == 'user') {
        _conversationHistory.removeLast();
      }
      
      return AIChatResponse(
        success: false,
        message: 'Network error. Please check your internet connection.',
        error: 'NETWORK_ERROR',
      );
    }
  }
  
  /// Get suggested prompts for quick actions
  static List<String> getSuggestedPrompts() {
    return [
      '💡 Give me a creative idea',
      '📝 Help me write something',
      '🧮 Solve a math problem',
      '🌍 Tell me about a country',
      '📚 Explain a concept',
      '🎯 Give me advice',
      '🎨 Describe an image idea',
      '💻 Help with coding',
    ];
  }
  
  /// Get conversation history
  static List<Map<String, String>> get conversationHistory => 
      List.unmodifiable(_conversationHistory);
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
