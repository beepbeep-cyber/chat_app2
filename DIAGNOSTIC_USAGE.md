# 🔍 API Key Diagnostic Tool - Usage Guide

## Overview
This tool helps debug API key synchronization issues between Profile screen, ChatBot screen, and AIChatService.

## How to Use

### Option 1: In ChatBot Screen (Recommended)
Add to `lib/screens/chat_bot/chat_bot.dart` in the `_initializeAI()` method:

```dart
import '../utils/api_key_diagnostic.dart';

Future<void> _initializeAI() async {
  setState(() {
    _isLoadingRemoteConfig = true;
  });

  try {
    await AIChatService.initializeFromRemoteConfig();
    await _syncApiKeyFromFirestore();
    
    setState(() {
      _isLoadingRemoteConfig = false;
    });
    
    // 🔍 RUN DIAGNOSTIC (only in debug mode)
    if (kDebugMode) {
      await ApiKeyDiagnostic.runDiagnostic();
    }
  } catch (e) {
    debugPrint('❌ ChatBot: Failed to initialize AI: $e');
    await _loadApiKey();
    setState(() {
      _isLoadingRemoteConfig = false;
    });
  }
}
```

### Option 2: In Profile Screen After Saving Key
Add to `lib/screens/setting.dart` in the `_saveApiKey()` method:

```dart
import '../utils/api_key_diagnostic.dart';

Future<void> _saveApiKey(String apiKey) async {
  // ... existing save logic ...
  
  // 🔍 RUN DIAGNOSTIC after saving
  if (kDebugMode) {
    await ApiKeyDiagnostic.runDiagnostic();
  }
}
```

### Option 3: Manual Test Button
Add a temporary test button in Settings screen:

```dart
// Add this button in the Settings UI (for testing only)
if (kDebugMode)
  ElevatedButton(
    onPressed: () async {
      await ApiKeyDiagnostic.runDiagnostic();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check debug console for report')),
      );
    },
    child: const Text('🔍 Run API Key Diagnostic'),
  ),
```

## Expected Output

### ✅ Success Case (Custom API Key):
```
═══════════════════════════════════════════
🔍 API KEY DIAGNOSTIC REPORT
═══════════════════════════════════════════

1️⃣ Firebase Authentication:
   ✅ User logged in: abc123xyz
   📧 Email: user@example.com

2️⃣ Firestore API Key:
   ✅ Key found in Firestore
   📝 Key preview: AIza...xyz9
   📏 Key length: 39
   🔑 Starts with AIza: true

3️⃣ SharedPreferences API Key:
   ✅ Key found in SharedPreferences
   📝 Key preview: AIza...xyz9
   📏 Key length: 39
   🔑 Starts with AIza: true

4️⃣ AIChatService Status:
   Is initialized: true
   Using Remote Config: false
   API key source: Custom (Your key)
   ✅ Active API key loaded
   📝 Key preview: AIza...xyz9
   📏 Key length: 39
   🔑 Starts with AIza: true

5️⃣ Detailed Service Status:
   Is ready: true
   Total keys: 1
   Available keys: 1
   Remaining requests: 8
   Global cooldown: 0s
   Using custom key: true
   Status text: 🟢 1/1 servers

📊 SUMMARY:
   ✅ AI ChatBot is ready to use!
   💡 Using your custom API key
═══════════════════════════════════════════
```

### ⚠️ No API Key Case:
```
═══════════════════════════════════════════
🔍 API KEY DIAGNOSTIC REPORT
═══════════════════════════════════════════

1️⃣ Firebase Authentication:
   ✅ User logged in: abc123xyz
   📧 Email: user@example.com

2️⃣ Firestore API Key:
   ⚠️ No API key in Firestore

3️⃣ SharedPreferences API Key:
   ⚠️ No API key in SharedPreferences

4️⃣ AIChatService Status:
   Is initialized: true
   Using Remote Config: true
   API key source: Server (5 keys available)
   ✅ Active API key loaded
   📝 Key preview: AIza...abc1
   📏 Key length: 39
   🔑 Starts with AIza: true

5️⃣ Detailed Service Status:
   Is ready: true
   Total keys: 5
   Available keys: 5
   Remaining requests: 8
   Global cooldown: 0s
   Using custom key: false
   Status text: 🟢 5/5 servers

📊 SUMMARY:
   ✅ AI ChatBot is ready to use!
   💡 Using server API keys
   💡 Tip: Add your own API key in Profile > AI Assistant
═══════════════════════════════════════════
```

### ❌ Error Case (No Keys Available):
```
═══════════════════════════════════════════
🔍 API KEY DIAGNOSTIC REPORT
═══════════════════════════════════════════

1️⃣ Firebase Authentication:
   ✅ User logged in: abc123xyz
   📧 Email: user@example.com

2️⃣ Firestore API Key:
   ⚠️ No API key in Firestore

3️⃣ SharedPreferences API Key:
   ⚠️ No API key in SharedPreferences

4️⃣ AIChatService Status:
   Is initialized: false
   Using Remote Config: false
   API key source: Not configured
   ⚠️ No active API key

5️⃣ Detailed Service Status:
   Is ready: false
   Total keys: 0
   Available keys: 0
   Remaining requests: 8
   Global cooldown: 0s
   Using custom key: false
   Status text: 🔴 All busy

📊 SUMMARY:
   ❌ AI ChatBot is NOT ready
   💡 Action required:
      1. Go to Profile screen
      2. Tap "Gemini API Key"
      3. Get free key: https://aistudio.google.com/app/apikey
      4. Enter and save your API key
═══════════════════════════════════════════
```

## Troubleshooting

### Issue: Keys don't match between storages
**Symptom**: Different keys in Firestore vs SharedPreferences
**Solution**: The sync is handled automatically when ChatBot screen loads. If still mismatched, manually trigger:
```dart
await _syncApiKeyFromFirestore();
```

### Issue: AIChatService not picking up custom key
**Symptom**: `Using custom key: false` when key exists in Firestore
**Solution**: Ensure `AIChatService.setApiKey()` is called after saving:
```dart
await _saveApiKey(apiKey);  // This should call setApiKey internally
```

### Issue: API key format invalid
**Symptom**: `Starts with AIza: false`
**Solution**: Verify the API key is correct:
- Must start with "AIza"
- Typically 39 characters long
- Get from: https://aistudio.google.com/app/apikey

## Integration Checklist

- [ ] Import `api_key_diagnostic.dart` in target file
- [ ] Add `if (kDebugMode)` guard
- [ ] Call `await ApiKeyDiagnostic.runDiagnostic()`
- [ ] Check debug console for output
- [ ] Remove or disable before production release

## Production Note
This diagnostic tool only runs in debug mode (`kDebugMode` check). It will NOT run in release builds.

## Support
If the diagnostic shows unexpected results, please:
1. Copy the full console output
2. Share with development team
3. Include steps to reproduce the issue
