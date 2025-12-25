import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:my_porject/screens/auth_screen.dart';
import 'package:my_porject/screens/login_screen.dart';
import 'package:my_porject/screens/chathome_screen.dart';
import 'package:my_porject/screens/email_verification_screen.dart';
import 'package:my_porject/components/upside_signup.dart';
import 'package:my_porject/configs/app_theme.dart';
import 'package:my_porject/widgets/page_transitions.dart';

class SignUp extends StatefulWidget {
  const SignUp({key});

  @override
  State createState() => _SignUpScreen();
}

class _SignUpScreen extends State<SignUp> {
  TextEditingController name = TextEditingController();
  TextEditingController email = TextEditingController();
  TextEditingController password = TextEditingController();
  TextEditingController passwordAgain = TextEditingController();
  bool isLoading = false;

  bool _isVisible = false;
  void updateStatus() {
    setState(() {
      _isVisible = !_isVisible;
    });
  }

  void showRegisterSuccessDialog() {
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
            Icon(Icons.mark_email_read, color: AppTheme.accent, size: 28),
            const SizedBox(width: 12),
            Text(
              'Verify Your Email',
              style: AppTheme.titleLarge,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Account created successfully!',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.success,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'A verification email has been sent to:',
              style: AppTheme.bodyMedium.copyWith(height: 1.4),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.backgroundLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.email, size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      email.text,
                      style: AppTheme.bodyMedium.copyWith(
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Please verify your email to complete registration.',
              style: AppTheme.bodySmall.copyWith(height: 1.4),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  SlideRightRoute(
                    page: EmailVerificationScreen(
                      email: email.text,
                      password: password.text,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.verified_user),
              label: const Text('Continue to Verify', style: TextStyle(fontSize: 15)),
              style: AppTheme.accentButtonStyle,
            ),
          ),
        ],
      ),
    );
  }

  void showRegisterFailedDialog(String errorMessage) {
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
              'Registration Failed',
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

  String? validatePassword(String value) {
    RegExp regex = RegExp(r'^(?=.*?[a-z])(?=.*?[0-9])(?=.*?[!@#\$&*~]).{8,}$');
    if (!regex.hasMatch(value)) {
      return 'Phải có tối thiểu 1 chữ cái, 1 số và 1 ký tự đặc biệt';
    } else {
      return null;
    }
  }

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return isLoading
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
                                  "Create New Account",
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
                              height: 7,
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
                                  //     onPressed: () async {
                                  //       // signInWithFacebook();
                                  //       setState(() {
                                  //         isLoading = true;
                                  //       });
                                  //       signInWithFacebook().then((user) {
                                  //         if(user != null) {
                                  //           setState(() {
                                  //             isLoading = false;
                                  //           });
                                  //           Navigator.push(
                                  //               context,
                                  //               MaterialPageRoute(
                                  //                 builder: (context) => HomeScreen(user: user,),
                                  //               ));
                                  //           print("Login Successfull");
                                  //         } else {
                                  //           print("Login Failed");
                                  //         }
                                  //       });
                                  //     },
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
                                                        page: HomeScreen(
                                                                user: user)),
                                                    (Route<dynamic> route) =>
                                                        false);
                                            if (kDebugMode) { debugPrint("Login Successfully"); }
                                          } else {
                                            setState(() {
                                              isLoading = false;
                                            });
                                            showRegisterFailedDialog('Google sign in failed or was cancelled.');
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
                                      margin: const EdgeInsets.only(bottom: 5),
                                      child: TextFormField(
                                        decoration: InputDecoration(
                                            prefixIcon: const Padding(
                                              padding:
                                                  EdgeInsetsDirectional.only(
                                                      start: 12),
                                              child: Icon(Icons.account_circle),
                                            ),
                                            hintText: "Name",
                                            border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(20))),
                                        controller: name,
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return "Không được để trống!";
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    Container(
                                      width: 320,
                                      margin: const EdgeInsets.all(5.0),
                                      child: TextFormField(
                                        decoration: InputDecoration(
                                            prefixIcon: const Padding(
                                              padding:
                                                  EdgeInsetsDirectional.only(
                                                      start: 12),
                                              child: Icon(Icons.email),
                                            ),
                                            hintText: "Email",
                                            border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(20))),
                                        controller: email,
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return "Không được để trống!";
                                          }
                                          return null;
                                        },
                                      ),
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
                                        controller: password,
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return "Không được để trống!";
                                          } else if (value.length < 6) {
                                            return "Mật khẩu phải dài hơn 6 ký tự";
                                          } else {
                                            return validatePassword(value);
                                          }
                                        },
                                      ),
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
                                            hintText: "Confirm Password",
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
                                        controller: passwordAgain,
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return "Không được để trống!";
                                          } else if (value != password.text) {
                                            return "Không trùng với mật khẩu vừa nhập";
                                          } else {
                                            return null;
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                )),
                            const SizedBox(
                              height: 10,
                            ),
                            SizedBox(
                              width: 200,
                              height: 45,
                              child: ElevatedButton(
                                onPressed: () {
                                  if (_formKey.currentState!.validate()) {
                                    if (name.text.isNotEmpty &&
                                        email.text.isNotEmpty &&
                                        password.text.isNotEmpty) {
                                      setState(() {
                                        isLoading = true;
                                      });
                                      createAccount(name.text, email.text,
                                              password.text)
                                          .then((result) {
                                        if (result.isSuccess && result.user != null) {
                                          setState(() {
                                            isLoading = false;
                                          });
                                          showRegisterSuccessDialog();
                                          if (kDebugMode) { debugPrint("Registration Successful"); }
                                        } else {
                                          showRegisterFailedDialog(result.errorMessage ?? 'Registration failed. Please try again.');
                                          if (kDebugMode) { debugPrint("Registration Failed: ${result.errorMessage}"); }
                                        }
                                      });
                                    }
                                  }
                                },
                                style: AppTheme.primaryButtonStyle.copyWith(
                                  shape: WidgetStateProperty.all(
                                    RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30.0),
                                    ),
                                  ),
                                ),
                                child: const Text("REGISTER",
                                    style: TextStyle(
                                      color: AppTheme.textWhite,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    )),
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Text(
                                  "Already have an account?",
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
                                            page: Login(
                                              email: email.text,
                                              password: password.text,
                                            ),
                                          ));
                                    },
                                    child: const Text(
                                      "Login here",
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
          );
  }
}
