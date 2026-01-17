import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// CRITICAL: Test if API key actually works
/// This bypasses ALL app logic and tests the raw API key
class GeminiApiTester {
  static Future<void> testCurrentApiKey() async {
    if (kDebugMode) {
      debugPrint('');
      debugPrint('═══════════════════════════════════════════');
      debugPrint('🔬 GEMINI API KEY DIRECT TEST');
      debugPrint('═══════════════════════════════════════════');
      
      // Get API key from Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('❌ No user logged in');
        return;
      }
      
      debugPrint('✅ User: ${user.uid}');
      debugPrint('');
      
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (!doc.exists || doc.data() == null) {
          debugPrint('❌ User document not found');
          return;
        }
        
        final apiKey = doc.data()!['geminiApiKey'] as String?;
        
        if (apiKey == null || apiKey.isEmpty) {
          debugPrint('❌ No API key in Firestore');
          return;
        }
        
        debugPrint('📝 API Key found in Firestore:');
        debugPrint('   Preview: ${_maskKey(apiKey)}');
        debugPrint('   Length: ${apiKey.length}');
        debugPrint('   Starts with AIza: ${apiKey.startsWith('AIza')}');
        debugPrint('');
        
        // Test the API key directly with gemini-1.5-flash-latest first (more reliable)
        debugPrint('🚀 Testing API key with Google Gemini API...');
        debugPrint('   Model: gemini-1.5-flash-latest (Free Tier)');
        debugPrint('');
        
        bool firstTestFailed = false;
        String firstTestModel = 'gemini-1.5-flash-latest';
        
        var url = 'https://generativelanguage.googleapis.com/v1beta/models/$firstTestModel:generateContent?key=$apiKey';
        
        final requestBody = {
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': 'Hello! Just testing API key. Reply with OK.'}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 100,
          }
        };
        
        final startTime = DateTime.now();
        
        final response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(requestBody),
        ).timeout(const Duration(seconds: 10));
        
        final duration = DateTime.now().difference(startTime);
        
        debugPrint('📡 Response received:');
        debugPrint('   HTTP Status: ${response.statusCode}');
        debugPrint('   Response Time: ${duration.inMilliseconds}ms');
        debugPrint('');
        
        if (response.statusCode == 200) {
          debugPrint('✅ API KEY WORKS PERFECTLY!');
          debugPrint('   Model: $firstTestModel');
          debugPrint('');
          
          final data = jsonDecode(response.body);
          if (data['candidates'] != null && data['candidates'].isNotEmpty) {
            final text = data['candidates'][0]['content']['parts'][0]['text'];
            debugPrint('🤖 AI Response: $text');
          }
          
          debugPrint('');
          debugPrint('💡 Result: Your API key is VALID and NOT rate limited!');
          debugPrint('💡 Model $firstTestModel works fine.');
          
        } else if (response.statusCode == 429) {
          firstTestFailed = true;
          debugPrint('🔴 RATE LIMITED (429) for $firstTestModel');
          debugPrint('');
          
          try {
            final errorData = jsonDecode(response.body);
            final errorMsg = errorData['error']?['message'] ?? 'Unknown';
            debugPrint('   Error message: $errorMsg');
            
            // Check if it's quota limit = 0
            if (errorMsg.contains('limit: 0') || errorMsg.contains('quota exceeded')) {
              debugPrint('');
              debugPrint('🚨 CRITICAL: Your API key has NO free tier quota!');
              debugPrint('   This means:');
              debugPrint('   - Model $firstTestModel is not available on free tier');
              debugPrint('   - Or your Google Account exceeded all free quotas');
              debugPrint('');
              debugPrint('🔧 Let\'s try gemini-2.0-flash-exp (experimental)...');
              debugPrint('');
              
              // Try gemini-2.0-flash-exp
              final expModel = 'gemini-2.0-flash-exp';
              final expUrl = 'https://generativelanguage.googleapis.com/v1beta/models/$expModel:generateContent?key=$apiKey';
              
              final expResponse = await http.post(
                Uri.parse(expUrl),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode(requestBody),
              ).timeout(const Duration(seconds: 10));
              
              debugPrint('📡 Response for $expModel:');
              debugPrint('   HTTP Status: ${expResponse.statusCode}');
              
              if (expResponse.statusCode == 200) {
                debugPrint('');
                debugPrint('✅ SUCCESS! Model $expModel WORKS!');
                debugPrint('');
                debugPrint('💡 Solution: Switch app to use $expModel');
                debugPrint('💡 This is a free experimental model.');
                
              } else if (expResponse.statusCode == 429) {
                debugPrint('');
                debugPrint('❌ Model $expModel also rate limited.');
                debugPrint('');
                debugPrint('🔧 Final Solutions:');
                debugPrint('   1. Create NEW Google Account');
                debugPrint('   2. Get API key from new account');
                debugPrint('   3. Or enable billing (paid tier)');
              }
              
            } else if (errorMsg.contains('quota') || errorMsg.contains('exceeded')) {
              debugPrint('');
              debugPrint('💡 Your API key exceeded temporary rate limits:');
              debugPrint('   - Free tier: 15 requests/minute');
              debugPrint('   - Daily: 1,500 requests/day');
              debugPrint('');
              debugPrint('🔧 Solutions:');
              debugPrint('   1. Wait 60 seconds and try again');
              debugPrint('   2. Create NEW API key at: https://aistudio.google.com/app/apikey');
              debugPrint('   3. Check quota at: https://aistudio.google.com/app/apikey');
            }
          } catch (e) {
            debugPrint('   Raw response: ${response.body}');
          }
          
        } else if (response.statusCode == 400) {
          debugPrint('🔴 BAD REQUEST (400)');
          debugPrint('');
          
          try {
            final errorData = jsonDecode(response.body);
            final errorMsg = errorData['error']?['message'] ?? 'Unknown';
            debugPrint('   Error: $errorMsg');
            
            if (errorMsg.contains('API key')) {
              debugPrint('');
              debugPrint('💡 Your API key is INVALID:');
              debugPrint('   - Check you copied the full key');
              debugPrint('   - Get new key: https://aistudio.google.com/app/apikey');
            }
          } catch (e) {
            debugPrint('   Raw response: ${response.body}');
          }
          
        } else if (response.statusCode == 404) {
          debugPrint('🔴 MODEL NOT FOUND (404)');
          debugPrint('');
          
          try {
            final errorData = jsonDecode(response.body);
            final errorMsg = errorData['error']?['message'] ?? 'Unknown';
            debugPrint('   Error: $errorMsg');
            debugPrint('');
            debugPrint('🔧 Trying alternative models...');
            
            // Try gemini-pro (stable fallback)
            final fallbackModel = 'gemini-pro';
            debugPrint('   Testing: $fallbackModel');
            
            final fallbackUrl = 'https://generativelanguage.googleapis.com/v1beta/models/$fallbackModel:generateContent?key=$apiKey';
            
            final fallbackResponse = await http.post(
              Uri.parse(fallbackUrl),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(requestBody),
            ).timeout(const Duration(seconds: 10));
            
            debugPrint('   HTTP Status: ${fallbackResponse.statusCode}');
            
            if (fallbackResponse.statusCode == 200) {
              debugPrint('');
              debugPrint('✅ SUCCESS! Model $fallbackModel WORKS!');
              debugPrint('');
              debugPrint('💡 Solution: Switch app to use $fallbackModel');
              
            } else {
              debugPrint('');
              debugPrint('❌ Model $fallbackModel also failed (${fallbackResponse.statusCode})');
              debugPrint('');
              debugPrint('💡 Your API key may not have access to any models.');
              debugPrint('💡 Try creating a new API key.');
            }
          } catch (e) {
            debugPrint('   Raw response: ${response.body}');
          }
          
        } else {
          debugPrint('❌ UNEXPECTED ERROR (${response.statusCode})');
          debugPrint('');
          debugPrint('   Response body:');
          debugPrint('   ${response.body}');
        }
        
      } catch (e) {
        debugPrint('❌ Test failed with exception:');
        debugPrint('   $e');
      }
      
      debugPrint('═══════════════════════════════════════════');
      debugPrint('');
    }
  }
  
  static String _maskKey(String key) {
    if (key.length <= 8) return '****';
    return '${key.substring(0, 10)}...${key.substring(key.length - 5)}';
  }
}
