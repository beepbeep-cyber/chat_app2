import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:my_porject/resources/firebase_options.dart';
import 'package:my_porject/screens/login_screen.dart';
import 'package:my_porject/provider/user_provider.dart';
import 'package:my_porject/configs/app_theme.dart';
import 'package:my_porject/services/biometric_auth_service.dart';
import 'package:my_porject/screens/biometric_lock_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
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
        title: 'Chat App',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppTheme.primaryDark,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          fontFamily: 'Inter',
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppTheme.primaryDark,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          fontFamily: 'Inter',
        ),
        themeMode: ThemeMode.system,
        home: const AppLauncher(),
      ),
    );
  }
}

/// App Launcher with Biometric Check
class AppLauncher extends StatefulWidget {
  const AppLauncher({super.key});

  @override
  State<AppLauncher> createState() => _AppLauncherState();
}

class _AppLauncherState extends State<AppLauncher> {
  final BiometricAuthService _biometricService = BiometricAuthService();
  bool _isLoading = true;
  bool _needsBiometric = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricRequirement();
  }

  Future<void> _checkBiometricRequirement() async {
    try {
      // Check if biometric is enabled and needed
      final needsAuth = await _biometricService.needsReAuthentication();
      
      if (mounted) {
        setState(() {
          _needsBiometric = needsAuth;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error checking biometric: $e');
      }
      if (mounted) {
        setState(() {
          _needsBiometric = false;
          _isLoading = false;
        });
      }
    }
  }

  void _onBiometricSuccess() {
    if (mounted) {
      setState(() {
        _needsBiometric = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/logo2.0.png',
                width: 100,
                height: 100,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.chat_bubble_rounded,
                    size: 80,
                    color: AppTheme.primaryDark,
                  );
                },
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      );
    }

    if (_needsBiometric) {
      return BiometricLockScreen(
        onAuthenticationSuccess: _onBiometricSuccess,
      );
    }

    return Login();
  }
}
