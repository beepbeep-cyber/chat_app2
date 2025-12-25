import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';

// Firebase config
import 'package:my_porject/resources/firebase_options.dart';

// Theme
import 'package:my_porject/configs/app_theme.dart';

// Providers
import 'package:my_porject/provider/user_provider.dart';

// Screens
import 'package:my_porject/screens/login_screen.dart';
import 'package:my_porject/screens/chathome_screen.dart';
import 'package:my_porject/screens/biometric_lock_screen.dart';

// Services
import 'package:my_porject/services/fcm_service.dart';
import 'package:my_porject/services/biometric_auth_service.dart';
import 'package:my_porject/services/user_presence_service.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (kDebugMode) {
    debugPrint('🔔 [FCM] Background message: ${message.messageId}');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize FCM Service for Android
  await FCMService().initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: MaterialApp(
        title: 'SecureChat',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light, // Force light theme for consistency
        home: const AuthWrapper(),
      ),
    );
  }
}

/// Wrapper widget to handle authentication state
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> with WidgetsBindingObserver {
  final BiometricAuthService _biometricService = BiometricAuthService();
  final UserPresenceService _presenceService = UserPresenceService();
  bool _isCheckingBiometric = true;
  bool _needsBiometric = false;
  User? _previousUser; // Track previous user to detect logout

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkBiometric();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    switch (state) {
      case AppLifecycleState.resumed:
        // App came to foreground - set online
        _presenceService.setUserOnline();
        // Check if biometric needed
        _checkBiometricOnResume();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // App went to background - set offline
        _presenceService.setUserOffline();
        break;
    }
  }

  Future<void> _checkBiometric() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isCheckingBiometric = false;
        _needsBiometric = false;
      });
      return;
    }

    final needsAuth = await _biometricService.needsReAuthentication();
    setState(() {
      _isCheckingBiometric = false;
      _needsBiometric = needsAuth;
    });
  }

  Future<void> _checkBiometricOnResume() async {
    final needsAuth = await _biometricService.needsReAuthentication(
      timeout: const Duration(minutes: 1),
    );
    
    if (needsAuth && mounted) {
      setState(() {
        _needsBiometric = true;
      });
    }
  }

  void _onBiometricSuccess() {
    setState(() {
      _needsBiometric = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while checking
    if (_isCheckingBiometric) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Still loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Detect logout: previous user existed but current is null
        final currentUser = snapshot.data;
        if (_previousUser != null && currentUser == null) {
          // User just logged out - reset biometric state
          _needsBiometric = false;
          _isCheckingBiometric = false;
        }
        _previousUser = currentUser;

        // User logged in
        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;
          
          // Check email verification
          if (!user.emailVerified && 
              user.providerData.any((p) => p.providerId == 'password')) {
            // Email/password user not verified - go to login
            return Login();
          }

          // Check biometric
          if (_needsBiometric) {
            return BiometricLockScreen(
              onAuthenticationSuccess: _onBiometricSuccess,
            );
          }

          // All checks passed - show home
          return HomeScreen(user: user);
        }

        // User not logged in
        return Login();
      },
    );
  }
}
