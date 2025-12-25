import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service class for handling biometric authentication
/// Supports fingerprint, face recognition, and PIN/password fallback
class BiometricAuthService {
  final LocalAuthentication _localAuth = LocalAuthentication();

  // SharedPreferences keys
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _lastAuthTimeKey = 'last_auth_time';
  
  // Track if user has authenticated in current app session
  static bool _hasAuthenticatedThisSession = false;
  
  /// Check if device supports biometric authentication
  Future<bool> isBiometricAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || 
                                   await _localAuth.isDeviceSupported();
      return canAuthenticate;
    } on PlatformException catch (e) {
      if (kDebugMode) { debugPrint('Error checking biometric availability: $e'); }
      return false;
    }
  }

  /// Get list of available biometric types
  /// Returns: [BiometricType.face, BiometricType.fingerprint, etc.]
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException catch (e) {
      if (kDebugMode) { debugPrint('Error getting available biometrics: $e'); }
      return <BiometricType>[];
    }
  }

  /// Check if biometric authentication is enabled in app settings
  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool(_biometricEnabledKey) ?? false;
    if (kDebugMode) { debugPrint('📦 [BiometricService] Read from storage - enabled: $isEnabled'); }
    return isEnabled;
  }

  /// Enable or disable biometric authentication
  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricEnabledKey, enabled);
    if (kDebugMode) { debugPrint('💾 [BiometricService] Saved to storage - enabled: $enabled'); }
  }

  /// Authenticate using biometric or device credentials
  /// Returns true if authentication successful, false otherwise
  Future<bool> authenticate({
    String localizedReason = 'Please authenticate to access the app',
    bool biometricOnly = false,
  }) async {
    if (kDebugMode) { debugPrint('🔐 [BiometricService] authenticate() called'); }
    if (kDebugMode) { debugPrint('🔐 [BiometricService] Reason: $localizedReason'); }
    if (kDebugMode) { debugPrint('🔐 [BiometricService] BiometricOnly: $biometricOnly'); }
    
    try {
      // Check if device supports biometric
      if (kDebugMode) { debugPrint('🔐 [BiometricService] Checking device availability...'); }
      final isAvailable = await isBiometricAvailable();
      if (kDebugMode) { debugPrint('🔐 [BiometricService] Device available: $isAvailable'); }
      
      if (!isAvailable) {
        if (kDebugMode) { debugPrint('❌ [BiometricService] Biometric authentication not available on this device'); }
        return false;
      }

      // Attempt authentication
      if (kDebugMode) { debugPrint('🔐 [BiometricService] Starting authentication dialog...'); }
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: localizedReason,
        options: AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: biometricOnly,
          useErrorDialogs: true,
          sensitiveTransaction: true,
        ),
      );

      if (kDebugMode) { debugPrint('🔐 [BiometricService] Authentication result: $didAuthenticate'); }

      // Save last authentication time if successful
      if (didAuthenticate) {
        if (kDebugMode) { debugPrint('✅ [BiometricService] Saving authentication time...'); }
        await _saveLastAuthTime();
      }

      return didAuthenticate;
    } on PlatformException catch (e) {
      if (kDebugMode) { debugPrint('❌ [BiometricService] PlatformException: ${e.code} - ${e.message}'); }
      
      // Handle specific error cases
      if (e.code == 'NotAvailable') {
        if (kDebugMode) { debugPrint('❌ [BiometricService] Biometric not available'); }
      } else if (e.code == 'NotEnrolled') {
        if (kDebugMode) { debugPrint('❌ [BiometricService] No biometrics enrolled'); }
      } else if (e.code == 'LockedOut' || e.code == 'PermanentlyLockedOut') {
        if (kDebugMode) { debugPrint('❌ [BiometricService] Biometric authentication locked'); }
      }
      
      return false;
    } catch (e) {
      if (kDebugMode) { debugPrint('❌ [BiometricService] Unexpected error: $e'); }
      return false;
    }
  }

  /// Check if app needs re-authentication
  /// Returns true if user needs to authenticate again
  Future<bool> needsReAuthentication({Duration timeout = const Duration(minutes: 5)}) async {
    final isEnabled = await isBiometricEnabled();
    if (kDebugMode) { debugPrint('🔐 [BiometricService] Biometric enabled: $isEnabled'); }
    
    if (!isEnabled) {
      return false; // Biometric not enabled, no need to authenticate
    }

    // If user hasn't authenticated in current app session, ALWAYS require auth
    // This ensures biometric shows up every time app is opened/restarted
    if (!_hasAuthenticatedThisSession) {
      if (kDebugMode) { debugPrint('🆕 [BiometricService] New app session - needs auth'); }
      return true;
    }

    // User already authenticated this session, now check timeout
    final prefs = await SharedPreferences.getInstance();
    final lastAuthTime = prefs.getInt(_lastAuthTimeKey);
    if (kDebugMode) { debugPrint('⏰ [BiometricService] Last auth time: $lastAuthTime'); }

    if (lastAuthTime == null) {
      if (kDebugMode) { debugPrint('🆕 [BiometricService] Never authenticated before - needs auth'); }
      return true; // Never authenticated before
    }

    final lastAuth = DateTime.fromMillisecondsSinceEpoch(lastAuthTime);
    final now = DateTime.now();
    final difference = now.difference(lastAuth);
    
    final needsAuth = difference > timeout;
    if (kDebugMode) { debugPrint('⏱️ [BiometricService] Time since last auth: ${difference.inMinutes}min - Needs auth: $needsAuth'); }

    return needsAuth;
  }

  /// Save the current time as last authentication time
  Future<void> _saveLastAuthTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastAuthTimeKey, DateTime.now().millisecondsSinceEpoch);
    
    // Mark that user has authenticated in current session
    _hasAuthenticatedThisSession = true;
    if (kDebugMode) { debugPrint('✅ [BiometricService] Session authenticated - flag set to true'); }
  }

  /// Clear last authentication time (useful when user logs out)
  Future<void> clearAuthenticationState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastAuthTimeKey);
    
    // Reset session authentication flag
    _hasAuthenticatedThisSession = false;
    if (kDebugMode) { debugPrint('🗑️ [BiometricService] Authentication state cleared'); }
  }

  /// Get user-friendly biometric type name
  String getBiometricTypeName(BiometricType type) {
    switch (type) {
      case BiometricType.face:
        return 'Face Recognition';
      case BiometricType.fingerprint:
        return 'Fingerprint';
      case BiometricType.iris:
        return 'Iris Scan';
      case BiometricType.strong:
        return 'Strong Biometric';
      case BiometricType.weak:
        return 'Weak Biometric';
    }
  }

  /// Get user-friendly message based on available biometrics
  Future<String> getBiometricMessage() async {
    final biometrics = await getAvailableBiometrics();
    
    if (biometrics.isEmpty) {
      return 'Please authenticate to continue';
    }
    
    if (biometrics.contains(BiometricType.face)) {
      return 'Scan your face to unlock';
    }
    
    if (biometrics.contains(BiometricType.fingerprint)) {
      return 'Touch fingerprint sensor to unlock';
    }
    
    return 'Use biometric authentication to unlock';
  }

  /// Stop authentication (cancel ongoing authentication)
  Future<void> stopAuthentication() async {
    try {
      await _localAuth.stopAuthentication();
    } catch (e) {
      if (kDebugMode) { debugPrint('Error stopping authentication: $e'); }
    }
  }
}
