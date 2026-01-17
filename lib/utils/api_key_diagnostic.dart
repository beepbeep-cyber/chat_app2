import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ai_chat_service.dart';

/// Diagnostic tool to check API key synchronization status
/// Usage: await ApiKeyDiagnostic.runDiagnostic();
class ApiKeyDiagnostic {
  static Future<void> runDiagnostic() async {
    if (kDebugMode) {
      debugPrint('');
      debugPrint('═══════════════════════════════════════════');
      debugPrint('🔍 API KEY DIAGNOSTIC REPORT');
      debugPrint('═══════════════════════════════════════════');
      
      // 1. Check Firebase Auth
      final user = FirebaseAuth.instance.currentUser;
      debugPrint('');
      debugPrint('1️⃣ Firebase Authentication:');
      if (user != null) {
        debugPrint('   ✅ User logged in: ${user.uid}');
        debugPrint('   📧 Email: ${user.email}');
      } else {
        debugPrint('   ❌ No user logged in');
        debugPrint('═══════════════════════════════════════════');
        return;
      }
      
      // 2. Check Firestore
      debugPrint('');
      debugPrint('2️⃣ Firestore API Key:');
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (doc.exists && doc.data() != null) {
          final apiKey = doc.data()!['geminiApiKey'] as String?;
          if (apiKey != null && apiKey.isNotEmpty) {
            debugPrint('   ✅ Key found in Firestore');
            debugPrint('   📝 Key preview: ${_maskApiKey(apiKey)}');
            debugPrint('   📏 Key length: ${apiKey.length}');
            debugPrint('   🔑 Starts with AIza: ${apiKey.startsWith('AIza')}');
          } else {
            debugPrint('   ⚠️ No API key in Firestore');
          }
        } else {
          debugPrint('   ❌ User document not found in Firestore');
        }
      } catch (e) {
        debugPrint('   ❌ Error reading Firestore: $e');
      }
      
      // 3. Check SharedPreferences
      debugPrint('');
      debugPrint('3️⃣ SharedPreferences API Key:');
      try {
        final prefs = await SharedPreferences.getInstance();
        final apiKey = prefs.getString('gemini_api_key');
        if (apiKey != null && apiKey.isNotEmpty) {
          debugPrint('   ✅ Key found in SharedPreferences');
          debugPrint('   📝 Key preview: ${_maskApiKey(apiKey)}');
          debugPrint('   📏 Key length: ${apiKey.length}');
          debugPrint('   🔑 Starts with AIza: ${apiKey.startsWith('AIza')}');
        } else {
          debugPrint('   ⚠️ No API key in SharedPreferences');
        }
      } catch (e) {
        debugPrint('   ❌ Error reading SharedPreferences: $e');
      }
      
      // 4. Check AIChatService
      debugPrint('');
      debugPrint('4️⃣ AIChatService Status:');
      debugPrint('   Is initialized: ${AIChatService.isInitialized}');
      debugPrint('   Using Remote Config: ${AIChatService.isUsingRemoteConfig}');
      debugPrint('   API key source: ${AIChatService.apiKeySource}');
      
      final activeKey = AIChatService.apiKey;
      if (activeKey != null && activeKey.isNotEmpty) {
        debugPrint('   ✅ Active API key loaded');
        debugPrint('   📝 Key preview: ${_maskApiKey(activeKey)}');
        debugPrint('   📏 Key length: ${activeKey.length}');
        debugPrint('   🔑 Starts with AIza: ${activeKey.startsWith('AIza')}');
      } else {
        debugPrint('   ⚠️ No active API key');
      }
      
      // 5. Detailed Status
      debugPrint('');
      debugPrint('5️⃣ Detailed Service Status:');
      final status = AIChatService.detailedStatus;
      debugPrint('   Is ready: ${status['isReady']}');
      debugPrint('   Total keys: ${status['totalKeys']}');
      debugPrint('   Available keys: ${status['availableKeys']}');
      debugPrint('   Remaining requests: ${status['remainingRequests']}');
      debugPrint('   Global cooldown: ${status['globalCooldown']}s');
      debugPrint('   Using custom key: ${status['isUsingCustomKey']}');
      debugPrint('   Status text: ${status['statusText']}');
      
      // 6. Summary
      debugPrint('');
      debugPrint('📊 SUMMARY:');
      if (AIChatService.isInitialized) {
        debugPrint('   ✅ AI ChatBot is ready to use!');
        if (AIChatService.isUsingRemoteConfig) {
          debugPrint('   💡 Using server API keys');
          debugPrint('   💡 Tip: Add your own API key in Profile > AI Assistant');
        } else {
          debugPrint('   💡 Using your custom API key');
        }
      } else {
        debugPrint('   ❌ AI ChatBot is NOT ready');
        debugPrint('   💡 Action required:');
        debugPrint('      1. Go to Profile screen');
        debugPrint('      2. Tap "Gemini API Key"');
        debugPrint('      3. Get free key: https://aistudio.google.com/app/apikey');
        debugPrint('      4. Enter and save your API key');
      }
      
      debugPrint('═══════════════════════════════════════════');
      debugPrint('');
    }
  }
  
  static String _maskApiKey(String apiKey) {
    if (apiKey.length <= 8) return '****';
    return '${apiKey.substring(0, 4)}...${apiKey.substring(apiKey.length - 4)}';
  }
}
