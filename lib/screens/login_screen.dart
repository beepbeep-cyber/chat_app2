import 'package:my_porject/screens/chathome_screen.dart';
import 'package:my_porject/provider/user_provider.dart';
import 'package:my_porject/screens/signup_screen.dart';
import 'package:my_porject/screens/email_verification_screen.dart';
import 'package:my_porject/screens/forgot_password_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:my_porject/screens/auth_screen.dart';
import 'package:my_porject/components/upside.dart';
import 'package:my_porject/configs/app_theme.dart';
import 'package:my_porject/widgets/page_transitions.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ignore: must_be_immutable
class Login extends StatefulWidget {
  String? email;
  String? password;
  Login({this.email, this.password});
  @override
  State<Login> createState() => LoginPage();
}

class LoginPage extends State<Login> {
  final TextEditingController? _email = TextEditingController();
  final TextEditingController? _password = TextEditingController();
  late final String imgUrl;
  bool isLoading = false;

  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    _email?.text = widget.email ?? "";
    _password?.text = widget.password ?? "";
  }

  @override
  void dispose() {
    super.dispose();
  }

  void updateStatus() {
    setState(() {
      _isVisible = !_isVisible;
    });
  }

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  void showLoginDialog(String errorMessage) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: AppTheme.error, size: 28),
            const SizedBox(width: 12),
            Text(
              'Login Failed',
              style: AppTheme.titleLarge,
            ),
          ],
        ),
        content: Text(
          errorMessage,
          style: AppTheme.bodyMedium.copyWith(height: 1.4),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                isLoading = false;
              });
            },
            style: AppTheme.primaryButtonStyle,
            child: const Text('Try Again', style: TextStyle(fontSize: 15)),
          ),
        ],
      ),
    );
  }

  void showEmailNotVerifiedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.mark_email_unread, color: AppTheme.warning, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Email Not Verified',
                style: AppTheme.titleLarge,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Please verify your email before logging in.',
              style: AppTheme.bodyMedium.copyWith(height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warningLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppTheme.warning, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Check your inbox for the verification link.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                isLoading = false;
              });
            },
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                SlideRightRoute(
                  page: EmailVerificationScreen(
                    email: _email?.text ?? '',
                    password: _password?.text ?? '',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.verified_user, size: 18),
            label: const Text('Verify Now'),
            style: AppTheme.accentButtonStyle,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: isLoading
          ? Center(
              child: SizedBox(
                height: MediaQuery.of(context).size.height / 20,
                width: MediaQuery.of(context).size.height / 20,
                child: const CircularProgressIndicator(),
              ),
            )
          : GestureDetector(
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              child: Scaffold(
                resizeToAvoidBottomInset: true,
                body: SingleChildScrollView(
                  child: SizedBox(
                    width: size.width,
                    height: size.height,
                    child: Stack(
                      children: [
                        const Upside(
                          imgUrl: "assets/images/logo.png",
                        ),
                        Positioned(
                          top: 230,
                          left: 0,
                          right: 0,
                          child: Container(
                            width: double.infinity,
                            height: 100,
                            decoration: BoxDecoration(
                                color: AppTheme.backgroundLight,
                                borderRadius: const BorderRadius.only(
                                  topRight: Radius.circular(50),
                                  topLeft: Radius.circular(50),
                                )),
                            child: Column(
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 15),
                                  child: Text(
                                    "Login to your account",
                                    textAlign: TextAlign.center,
                                    style: AppTheme.titleMedium.copyWith(
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 280,
                          left: 0,
                          right: 0,
                          child: SingleChildScrollView(
                            child: Container(
                              width: double.infinity,
                              constraints: BoxConstraints(
                                minHeight: size.height - 280,
                              ),
                              decoration: const BoxDecoration(
                                  color: AppTheme.surfaceLight,
                                  borderRadius: BorderRadius.only(
                                    topRight: Radius.circular(50),
                                    topLeft: Radius.circular(50),
                                  )),
                              child: Column(
                            children: [
                              const SizedBox(
                                height: 20,
                              ),
                              SizedBox(
                                height: 40,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    // SizedBox(
                                    //   height: 40,
                                    //   width: 40,
                                    //   child: IconButton(
                                    //     icon: Image.asset(
                                    //       "assets/images/facebook_icon.png",
                                    //     ),
                                    //     onPressed: () async {},
                                    //   ),
                                    // ),
                                    const SizedBox(width: 20),
                                    SizedBox(
                                      height: 40,
                                      width: 40,
                                      child: IconButton(
                                        iconSize: 20,
                                        icon: Image.asset(
                                          "assets/images/google_icon.png",
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            isLoading = true;
                                          });
                                          signInWithGoogle().then((user) {
                                            if (user != null) {
                                              setState(() {
                                                isLoading = false;
                                              });
                                              Navigator.of(context)
                                                  .pushAndRemoveUntil(
                                                      SlideRightRoute(
                                                          page: HomeScreen(user: user)),
                                                      (Route<dynamic> route) =>
                                                          false);
                                              if (kDebugMode) { debugPrint("Login Successful"); }
                                            } else {
                                              setState(() {
                                                isLoading = false;
                                              });
                                              showLoginDialog('Google sign in failed or was cancelled.');
                                              if (kDebugMode) { debugPrint("Login Failed"); }
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    // SizedBox(
                                    //   height: 40,
                                    //   width: 40,
                                    //   child: IconButton(
                                    //     iconSize: 1,
                                    //     icon: Image.asset(
                                    //       "assets/images/apple_icon.png",
                                    //     ),
                                    //     onPressed: () {},
                                    //   ),
                                    // ),
                                  ],
                                ),
                              ),
                              const SizedBox(
                                height: 5,
                              ),
                              Text(
                                'or use your email account',
                                style: AppTheme.bodySmall.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(
                                height: 10,
                              ),
                              Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    Container(
                                      width: 320,
                                      margin: const EdgeInsets.all(10.0),
                                      child: TextFormField(
                                        decoration: InputDecoration(
                                            prefixIcon: const Icon(Icons.email),
                                            hintText: "Email",
                                            border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(20))),
                                        controller: _email,
                                        validator: (value) {
                                          if (value != null &&
                                              value.isNotEmpty &&
                                              value.length < 10) {
                                            return "Phải lớn hơn 10 ký tự!";
                                          } else if (value == null ||
                                              value.isEmpty) {
                                            return "Không được để trống!";
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 5,
                                    ),
                                    Container(
                                      width: 320,
                                      margin: const EdgeInsets.all(5.0),
                                      child: TextFormField(
                                        obscureText: _isVisible ? false : true,
                                        decoration: InputDecoration(
                                            prefixIcon: const Padding(
                                              padding:
                                                  EdgeInsetsDirectional.only(
                                                      start: 12),
                                              child: Icon(Icons.password),
                                            ),
                                            hintText: "Password",
                                            border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(20)),
                                            suffixIcon: Padding(
                                              padding:
                                                  const EdgeInsetsDirectional
                                                      .only(end: 12),
                                              child: IconButton(
                                                onPressed: () => updateStatus(),
                                                icon: Icon(_isVisible
                                                    ? Icons.visibility
                                                    : Icons.visibility_off),
                                              ),
                                            )),
                                        controller: _password,
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return "Không được để trống!";
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Forgot Password Link
                              Align(
                                alignment: Alignment.centerRight,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 30),
                                  child: TextButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        SlideRightRoute(
                                          page: ForgotPasswordScreen(
                                            initialEmail: _email?.text,
                                          ),
                                        ),
                                      );
                                    },
                                    child: const Text(
                                      'Forgot Password?',
                                      style: TextStyle(
                                        color: AppTheme.accent,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(
                                height: 10,
                              ),
                              SizedBox(
                                width: 200,
                                height: 45,
                                child: ElevatedButton(
                                  onPressed: () {
                                    if (_formKey.currentState!.validate()) {
                                      if ((_email!.text.isNotEmpty &&
                                          _password!.text.isNotEmpty)) {
                                        setState(() {
                                          isLoading = true;
                                        });
                                        logIn(_email!.text, _password!.text)
                                            .then((result) async {
                                          if (result.isSuccess && result.user != null) {
                                            // Check if email is verified
                                            await result.user!.reload();
                                            final user = FirebaseAuth.instance.currentUser;
                                            
                                            if (user != null && !user.emailVerified) {
                                              // Email not verified - show dialog
                                              setState(() {
                                                isLoading = false;
                                              });
                                              showEmailNotVerifiedDialog();
                                              return;
                                            }
                                            
                                            // Email verified - update status and proceed
                                            await updateEmailVerifiedStatus(user!.uid);
                                            
                                            setState(() {
                                              isLoading = false;
                                            });
                                            Navigator.of(context)
                                                .pushAndRemoveUntil(
                                                    SlideRightRoute(
                                                        page: HomeScreen(user: result.user!)),
                                                    (Route<dynamic> route) =>
                                                        false);
                                            if (kDebugMode) { debugPrint("Login Successful"); }
                                          } else {
                                            showLoginDialog(result.errorMessage ?? 'Login failed. Please try again.');
                                            if (kDebugMode) { debugPrint("Login Failed: ${result.errorMessage}"); }
                                          }
                                        });
                                      } else {}
                                    }
                                  },
                                  style: AppTheme.primaryButtonStyle.copyWith(
                                    shape: WidgetStateProperty.all(
                                      RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(30.0),
                                      ),
                                    ),
                                  ),
                                  child: const Text("LOGIN",
                                      style: TextStyle(
                                        color: AppTheme.textWhite,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      )),
                                ),
                              ),
                              const SizedBox(
                                height: 1,
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  Text(
                                    "Don't have an account?",
                                    style: AppTheme.bodySmall.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(
                                    width: 5,
                                  ),
                                  TextButton(
                                      onPressed: () {
                                        Navigator.push(
                                            context,
                                            SlideRightRoute(
                                              page: const SignUp(),
                                            ));
                                      },
                                      child: const Text(
                                        "Register here",
                                        style: TextStyle(
                                            color: AppTheme.primaryDark,
                                            fontWeight: FontWeight.bold),
                                      ))
                                ],
                              ),
                            ],
                          ),
                        ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
