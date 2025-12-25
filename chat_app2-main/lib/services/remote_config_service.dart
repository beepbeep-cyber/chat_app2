import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// Firebase Remote Config Service
/// Quản lý cấu hình từ xa, bao gồm API keys cho AI Bot
class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._internal();

  late final FirebaseRemoteConfig _remoteConfig;
  bool _isInitialized = false;

  // Remote Config keys
  static const String _geminiApiKey = 'gemini_api_key';
  static const String _aiModelName = 'ai_model_name';
  static const String _aiEnabled = 'ai_enabled';
  static const String _aiWelcomeMessage = 'ai_welcome_message';

  // Default values
  static const Map<String, dynamic> _defaults = {
    _geminiApiKey: '', // Empty by default, set in Firebase Console
    _aiModelName: 'gemini-2.0-flash',
    _aiEnabled: true,
    _aiWelcomeMessage: 'Hi! I\'m your AI Assistant. How can I help you today?',
  };

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Initialize Remote Config
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _remoteConfig = FirebaseRemoteConfig.instance;

      // Set default values
      await _remoteConfig.setDefaults(_defaults);

      // Configure fetch settings
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1), // Cache for 1 hour
      ));

      // Fetch and activate
      await _remoteConfig.fetchAndActivate();

      _isInitialized = true;
      debugPrint('✅ RemoteConfigService: Initialized successfully');
      
      // Log current values (hide sensitive data in production)
      if (kDebugMode) {
        debugPrint('📡 Remote Config Values:');
        debugPrint('   - AI Enabled: ${isAIEnabled}');
        debugPrint('   - AI Model: ${aiModelName}');
        debugPrint('   - API Key Set: ${geminiApiKey.isNotEmpty}');
      }
    } catch (e) {
      debugPrint('❌ RemoteConfigService: Initialization error: $e');
      // Service will work with default values
      _isInitialized = true;
    }
  }

  /// Refresh config from server
  Future<bool> refresh() async {
    try {
      final updated = await _remoteConfig.fetchAndActivate();
      debugPrint('🔄 RemoteConfigService: Config refreshed, updated: $updated');
      return updated;
    } catch (e) {
      debugPrint('❌ RemoteConfigService: Refresh error: $e');
      return false;
    }
  }

  /// Get Gemini API Key
  String get geminiApiKey {
    if (!_isInitialized) return '';
    return _remoteConfig.getString(_geminiApiKey);
  }

  /// Get AI Model Name
  String get aiModelName {
    if (!_isInitialized) return _defaults[_aiModelName] as String;
    return _remoteConfig.getString(_aiModelName);
  }

  /// Check if AI is enabled
  bool get isAIEnabled {
    if (!_isInitialized) return _defaults[_aiEnabled] as bool;
    return _remoteConfig.getBool(_aiEnabled);
  }

  /// Get AI Welcome Message
  String get aiWelcomeMessage {
    if (!_isInitialized) return _defaults[_aiWelcomeMessage] as String;
    return _remoteConfig.getString(_aiWelcomeMessage);
  }

  /// Check if API key is configured
  bool get hasApiKey => geminiApiKey.isNotEmpty;

  /// Listen for real-time config updates
  Stream<RemoteConfigUpdate> get onConfigUpdated => 
      _remoteConfig.onConfigUpdated;

  /// Activate fetched config
  Future<bool> activate() async {
    try {
      return await _remoteConfig.activate();
    } catch (e) {
      debugPrint('❌ RemoteConfigService: Activate error: $e');
      return false;
    }
  }
}
