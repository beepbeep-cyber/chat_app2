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
        
        // Test the API key directly
        debugPrint('🚀 Testing API key with Google Gemini API...');
        debugPrint('');
        
        final url = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey';
        
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
          debugPrint('');
          
          final data = jsonDecode(response.body);
          if (data['candidates'] != null && data['candidates'].isNotEmpty) {
            final text = data['candidates'][0]['content']['parts'][0]['text'];
            debugPrint('🤖 AI Response: $text');
          }
          
          debugPrint('');
          debugPrint('💡 Result: Your API key is VALID and NOT rate limited!');
          debugPrint('💡 Problem must be in app logic, not the API key itself.');
          
        } else if (response.statusCode == 429) {
          debugPrint('🔴 RATE LIMITED (429)');
          debugPrint('');
          
          try {
            final errorData = jsonDecode(response.body);
            final errorMsg = errorData['error']?['message'] ?? 'Unknown';
            debugPrint('   Error message: $errorMsg');
            
            if (errorMsg.contains('quota') || errorMsg.contains('exceeded')) {
              debugPrint('');
              debugPrint('💡 Your API key HAS exceeded quota limits:');
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
