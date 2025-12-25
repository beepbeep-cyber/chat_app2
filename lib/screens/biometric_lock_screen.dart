import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import '../services/biometric_auth_service.dart';
import '../configs/app_theme.dart';

/// Biometric Lock Screen
/// Shows when app launches if biometric authentication is enabled
class BiometricLockScreen extends StatefulWidget {
  final VoidCallback onAuthenticationSuccess;

  const BiometricLockScreen({
    super.key,
    required this.onAuthenticationSuccess,
  });

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen>
    with SingleTickerProviderStateMixin {
  final BiometricAuthService _biometricService = BiometricAuthService();
  
  bool _isAuthenticating = false;
  String _errorMessage = '';
  List<BiometricType> _availableBiometrics = [];
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
    _checkBiometricAvailability();
    _authenticateUser();
  }

  void _setupAnimation() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _animationController.repeat(reverse: true);
  }

  Future<void> _checkBiometricAvailability() async {
    if (kDebugMode) { debugPrint('📱 [BiometricLockScreen] Checking biometric availability...'); }
    final biometrics = await _biometricService.getAvailableBiometrics();
    if (kDebugMode) { debugPrint('📱 [BiometricLockScreen] Available biometrics: $biometrics'); }
    if (mounted) {
      setState(() {
        _availableBiometrics = biometrics;
      });
    }
  }

  Future<void> _authenticateUser() async {
    if (_isAuthenticating) {
      if (kDebugMode) { debugPrint('📱 [BiometricLockScreen] Already authenticating...'); }
      return;
    }

    if (kDebugMode) { debugPrint('📱 [BiometricLockScreen] Starting authentication...'); }
    setState(() {
      _isAuthenticating = true;
      _errorMessage = '';
    });

    try {
      final message = await _biometricService.getBiometricMessage();
      if (kDebugMode) { debugPrint('📱 [BiometricLockScreen] Auth message: $message'); }
      
      final authenticated = await _biometricService.authenticate(
        localizedReason: message,
        biometricOnly: false,
      );

      if (kDebugMode) { debugPrint('📱 [BiometricLockScreen] Authentication result: $authenticated'); }
      
      if (mounted) {
        if (authenticated) {
          if (kDebugMode) { debugPrint('✅ [BiometricLockScreen] Authentication successful!'); }
          widget.onAuthenticationSuccess();
        } else {
          if (kDebugMode) { debugPrint('❌ [BiometricLockScreen] Authentication failed'); }
          setState(() {
            _errorMessage = 'Authentication failed. Please try again.';
            _isAuthenticating = false;
          });
        }
      }
    } catch (e) {
      if (kDebugMode) { debugPrint('❌ [BiometricLockScreen] Error: $e'); }
      if (mounted) {
        setState(() {
          _errorMessage = 'An error occurred. Please try again.';
          _isAuthenticating = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  IconData _getBiometricIcon() {
    if (_availableBiometrics.contains(BiometricType.face)) {
      return Icons.face;
    } else if (_availableBiometrics.contains(BiometricType.fingerprint)) {
      return Icons.fingerprint;
    }
    return Icons.lock;
  }

  String _getBiometricTitle() {
    if (_availableBiometrics.contains(BiometricType.face)) {
      return 'Face Recognition';
    } else if (_availableBiometrics.contains(BiometricType.fingerprint)) {
      return 'Fingerprint';
    }
    return 'Biometric Authentication';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.headerGradient,
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Logo or Icon
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chat_bubble,
                    size: 60,
                    color: AppTheme.accent,
                  ),
                ),
                const SizedBox(height: 40),

                // App Name
                Text(
                  'Secure Chat',
                  style: AppTheme.headlineLarge.copyWith(
                    color: AppTheme.textWhite,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Private & Secure Messaging',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textHint,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 60),

                // Biometric Icon (Animated)
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _isAuthenticating ? _pulseAnimation.value : 1.0,
                      child: Container(
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.accent.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          _getBiometricIcon(),
                          size: 80,
                          color: AppTheme.accentLight,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 30),

                // Biometric Type Title
                Text(
                  _getBiometricTitle(),
                  style: AppTheme.headlineSmall.copyWith(
                    color: AppTheme.textWhite,
                  ),
                ),
                const SizedBox(height: 12),

                // Instruction Text
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    _isAuthenticating
                        ? 'Please authenticate to unlock'
                        : 'Tap the button below to authenticate',
                    textAlign: TextAlign.center,
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textHint,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // Error Message
                if (_errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: AppTheme.error.withValues(alpha: 0.7), size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage,
                              style: TextStyle(
                                color: AppTheme.error.withValues(alpha: 0.8),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 20),

                // Authenticate Button
                if (!_isAuthenticating)
                  ElevatedButton.icon(
                    onPressed: _authenticateUser,
                    style: AppTheme.accentButtonStyle.copyWith(
                      padding: WidgetStateProperty.all(
                        const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 16,
                        ),
                      ),
                      shape: WidgetStateProperty.all(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                    icon: Icon(_getBiometricIcon(), size: 24),
                    label: const Text(
                      'Unlock',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),

                // Loading Indicator
                if (_isAuthenticating)
                  Column(
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.accentLight,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Authenticating...',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textHint,
                        ),
                      ),
                    ],
                  ),
                
                const SizedBox(height: 60),

                // Security Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.success.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        color: AppTheme.success,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'End-to-End Encrypted',
                        style: TextStyle(
                          color: AppTheme.success,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
