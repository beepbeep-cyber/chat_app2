import 'package:flutter/foundation.dart';
import 'dart:convert';

/// Debug tool để kiểm tra API keys parsing
class DebugApiKeys {
  static void testParsing(String rawInput) {
    debugPrint('═══════════════════════════════════════');
    debugPrint('🔍 DEBUG API KEYS PARSING');
    debugPrint('═══════════════════════════════════════');
    debugPrint('');
    debugPrint('📝 Raw input:');
    debugPrint('   Length: ${rawInput.length}');
    debugPrint('   First 50 chars: "${rawInput.length > 50 ? rawInput.substring(0, 50) : rawInput}"');
    debugPrint('   Last 50 chars: "${rawInput.length > 50 ? rawInput.substring(rawInput.length - 50) : rawInput}"');
    debugPrint('');
    
    // Test JSON array parsing
    debugPrint('🧪 Test 1: JSON Array Parsing');
    try {
      final List<dynamic> keysList = jsonDecode(rawInput);
      debugPrint('   ✅ Valid JSON array');
      debugPrint('   📊 Array length: ${keysList.length}');
      
      for (int i = 0; i < keysList.length; i++) {
        final rawKey = keysList[i].toString();
        final trimmedKey = rawKey.trim();
        debugPrint('');
        debugPrint('   Key $i:');
        debugPrint('      Raw: "$rawKey"');
        debugPrint('      Length: ${rawKey.length}');
        debugPrint('      Trimmed: "$trimmedKey"');
        debugPrint('      Trimmed length: ${trimmedKey.length}');
        debugPrint('      First 10 chars: "${trimmedKey.length >= 10 ? trimmedKey.substring(0, 10) : trimmedKey}"');
        debugPrint('      Valid format: ${trimmedKey.startsWith('AIza') ? '✅' : '❌'}');
        
        // Check for hidden characters
        if (rawKey != trimmedKey) {
          debugPrint('      ⚠️ Has whitespace/newlines!');
        }
      }
    } catch (e) {
      debugPrint('   ❌ Not valid JSON: $e');
      
      // Test comma-separated
      debugPrint('');
      debugPrint('🧪 Test 2: Comma-Separated Parsing');
      final parts = rawInput.split(',');
      debugPrint('   📊 Parts count: ${parts.length}');
      
      for (int i = 0; i < parts.length; i++) {
        final rawKey = parts[i];
        final trimmedKey = rawKey.trim();
        // Remove quotes if present
        final cleanKey = trimmedKey.replaceAll('"', '').replaceAll("'", '').trim();
        
        debugPrint('');
        debugPrint('   Part $i:');
        debugPrint('      Raw: "$rawKey"');
        debugPrint('      Trimmed: "$trimmedKey"');
        debugPrint('      Clean: "$cleanKey"');
        debugPrint('      Length: ${cleanKey.length}');
        debugPrint('      Valid format: ${cleanKey.startsWith('AIza') ? '✅' : '❌'}');
      }
    }
    
    debugPrint('');
    debugPrint('═══════════════════════════════════════');
  }
  
  static List<String> parseApiKeys(String rawInput) {
    final List<String> keys = [];
    
    if (rawInput.isEmpty) return keys;
    
    // Try JSON array first
    try {
      final List<dynamic> keysList = jsonDecode(rawInput);
      for (var k in keysList) {
        final cleanKey = k.toString()
            .trim()
            .replaceAll('"', '')
            .replaceAll("'", '')
            .replaceAll('\n', '')
            .replaceAll('\r', '')
            .replaceAll('\t', '');
        if (cleanKey.isNotEmpty && cleanKey.startsWith('AIza')) {
          keys.add(cleanKey);
        }
      }
      debugPrint('✅ Parsed ${keys.length} valid keys from JSON array');
      return keys;
    } catch (_) {
      // Not JSON, try comma-separated
    }
    
    // Fallback: comma-separated
    final parts = rawInput.split(',');
    for (var part in parts) {
      final cleanKey = part
          .trim()
          .replaceAll('"', '')
          .replaceAll("'", '')
          .replaceAll('[', '')
          .replaceAll(']', '')
          .replaceAll('\n', '')
          .replaceAll('\r', '')
          .replaceAll('\t', '');
      if (cleanKey.isNotEmpty && cleanKey.startsWith('AIza')) {
        keys.add(cleanKey);
      }
    }
    
    debugPrint('✅ Parsed ${keys.length} valid keys from comma-separated');
    return keys;
  }
}
