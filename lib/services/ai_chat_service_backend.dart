import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Production-ready AI Chat Service using Backend Proxy
/// 
/// ✅ ADVANTAGES:
/// - Secure API keys (not exposed in client)
/// - Smart rate limiting per user
/// - Response caching (faster + cheaper)
/// - Support unlimited API keys on backend
/// - Easy to scale and monitor
/// - Can switch API providers easily
class AIChatServiceBackend {
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;
  static final List<Map<String, String>> _conversationHistory = [];
  static const int _maxHistoryLength = 20;
  
  // Client-side rate limit UI feedback
  static int _requestsThisMinute = 0;
  static DateTime _minuteStart = DateTime.now();
  static const int _maxRequestsPerMinute = 20; // Match backend limit
  
  /// Initialize service
  static Future<void> initialize() async {
    debugPrint('🔧 AI Chat Service (Backend Mode) initialized');
    
    // Optional: Configure Functions region if needed
    // _functions.useFunctionsEmulator('localhost', 5001);
  }
  
  /// Send message to AI
  static Future<Map<String, dynamic>> sendMessage(String message) async {
    try {
      // Check client-side rate limit
      final now = DateTime.now();
      if (now.difference(_minuteStart).inMinutes >= 1) {
        _requestsThisMinute = 0;
        _minuteStart = now;
      }
      
      if (_requestsThisMinute >= _maxRequestsPerMinute) {
        debugPrint('⚠️ Client-side rate limit reached');
        return {
          'success': false,
          'error': 'CLIENT_RATE_LIMIT',
          'message': '⏰ Bạn đang gửi tin quá nhanh. Vui lòng đợi 1 phút.',
        };
      }
      
      _requestsThisMinute++;
      
      // Check authentication
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return {
          'success': false,
          'error': 'UNAUTHENTICATED',
          'message': '🔐 Vui lòng đăng nhập để sử dụng AI Chat.',
        };
      }
      
      debugPrint('🚀 [Backend] Sending message to Cloud Function...');
      debugPrint('   User: ${user.uid}');
      debugPrint('   Message length: ${message.length}');
      debugPrint('   History length: ${_conversationHistory.length}');
      
      // Call Cloud Function
      final HttpsCallable callable = _functions.httpsCallable('geminiProxy');
      
      final result = await callable.call({
        'message': message,
        'conversationHistory': _conversationHistory,
      }).timeout(
        const Duration(seconds: 35),
        onTimeout: () {
          throw TimeoutException('Request timeout after 35 seconds');
        },
      );
      
      final data = result.data as Map<String, dynamic>;
      final aiResponse = data['response'] as String;
      final cached = data['cached'] as bool? ?? false;
      
      if (cached) {
        debugPrint('✅ [Backend] Response from cache');
      } else {
        debugPrint('✅ [Backend] Response from API');
      }
      debugPrint('   Response length: ${aiResponse.length}');
      
      // Update conversation history
      _conversationHistory.add({'role': 'user', 'content': message});
      _conversationHistory.add({'role': 'assistant', 'content': aiResponse});
      
      // Keep only recent history
      if (_conversationHistory.length > _maxHistoryLength * 2) {
        _conversationHistory.removeRange(0, 2);
      }
      
      return {
        'success': true,
        'response': aiResponse,
        'cached': cached,
      };
      
    } on FirebaseFunctionsException catch (e) {
      debugPrint('❌ [Backend] Firebase Functions Error');
      debugPrint('   Code: ${e.code}');
      debugPrint('   Message: ${e.message}');
      debugPrint('   Details: ${e.details}');
      
      String userMessage;
      
      switch (e.code) {
        case 'unauthenticated':
          userMessage = '🔐 Vui lòng đăng nhập để sử dụng AI Chat.';
          break;
        case 'resource-exhausted':
          userMessage = e.message ?? '⏰ Server đang bận. Vui lòng thử lại sau ít phút.';
          break;
        case 'invalid-argument':
          userMessage = '❌ Tin nhắn không hợp lệ.';
          break;
        case 'permission-denied':
          userMessage = '🚫 Bạn không có quyền sử dụng tính năng này.';
          break;
        default:
          userMessage = '❌ Lỗi kết nối. Vui lòng thử lại.';
      }
      
      return {
        'success': false,
        'error': e.code,
        'message': userMessage,
      };
      
    } on TimeoutException catch (e) {
      debugPrint('⏱️ [Backend] Timeout: ${e.message}');
      return {
        'success': false,
        'error': 'TIMEOUT',
        'message': '⏱️ Yêu cầu hết thời gian. Vui lòng thử lại.',
      };
      
    } catch (e) {
      debugPrint('❌ [Backend] Unexpected error: $e');
      return {
        'success': false,
        'error': 'UNKNOWN',
        'message': '❌ Đã có lỗi xảy ra. Vui lòng thử lại.',
      };
    }
  }
  
  /// Clear conversation history
  static void clearHistory() {
    _conversationHistory.clear();
    debugPrint('🧹 Conversation history cleared');
  }
  
  /// Get conversation history
  static List<Map<String, String>> getHistory() {
    return List.unmodifiable(_conversationHistory);
  }
  
  /// Get remaining requests this minute
  static int getRemainingRequests() {
    final now = DateTime.now();
    if (now.difference(_minuteStart).inMinutes >= 1) {
      return _maxRequestsPerMinute;
    }
    return _maxRequestsPerMinute - _requestsThisMinute;
  }
  
  /// Check if rate limited
  static bool isRateLimited() {
    return getRemainingRequests() <= 0;
  }
}
