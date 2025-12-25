import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
// Google Sign In 7.x: Use GoogleSignIn.instance.authenticate() API
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_porject/services/key_manager.dart';

// Auth result class to return user and error message
class AuthResult {
  final User? user;
  final String? errorMessage;
  
  AuthResult({this.user, this.errorMessage});
  
  bool get isSuccess => user != null;
}

// Helper function to get user-friendly error messages
String getAuthErrorMessage(FirebaseAuthException e) {
  switch (e.code) {
    case 'user-not-found':
      return 'No account found with this email. Please sign up first.';
    case 'wrong-password':
      return 'Incorrect password. Please try again.';
    case 'email-already-in-use':
      return 'This email is already registered. Please login instead.';
    case 'invalid-email':
      return 'Invalid email format. Please check and try again.';
    case 'weak-password':
      return 'Password is too weak. Use at least 6 characters.';
    case 'user-disabled':
      return 'This account has been disabled. Please contact support.';
    case 'too-many-requests':
      return 'Too many failed attempts. Please try again later.';
    case 'operation-not-allowed':
      return 'Email/password accounts are not enabled. Please contact support.';
    case 'invalid-credential':
      return 'Invalid credentials. Please check your email and password.';
    case 'network-request-failed':
      return 'Network error. Please check your internet connection.';
    default:
      return e.message ?? 'An error occurred. Please try again.';
  }
}

Future<AuthResult> createAccount(String name, String email, String password) async {
  FirebaseAuth _auth = FirebaseAuth.instance;

  FirebaseFirestore _firestore = FirebaseFirestore.instance;

  try {
    UserCredential? userCredential = (await _auth
        .createUserWithEmailAndPassword(email: email, password: password));
    if (kDebugMode) { debugPrint("Account created Succesfull"); }
    await userCredential.user!.updateDisplayName(name);
    await _firestore.collection('users').doc(_auth.currentUser?.uid).set({
      "name": name,
      "email": email,
      "status": "Pending Verification",
      "uid": _auth.currentUser!.uid,
      "emailVerified": false,
      "avatar":
          "https://firebasestorage.googleapis.com/v0/b/chatapptest2-93793.appspot.com/o/images%2F5c1b8830-75fc-11ed-a92f-3d766ba9d8a3.jpg?alt=media&token=6160aa31-424d-42f6-871e-0ca425e937cb",
    });

    // Send email verification
    await userCredential.user!.sendEmailVerification();
    if (kDebugMode) { debugPrint("✅ Verification email sent to $email"); }

    // Initialize encryption keys for new user
    await KeyManager.initializeKeys();
    if (kDebugMode) { debugPrint("✅ Encryption keys initialized"); }

    return AuthResult(user: userCredential.user);
  } on FirebaseAuthException catch (e) {
    if (kDebugMode) { debugPrint('Firebase Auth Error: ${e.code}'); }
    return AuthResult(errorMessage: getAuthErrorMessage(e));
  } catch (e) {
    if (kDebugMode) { debugPrint('Unexpected error: $e'); }
    return AuthResult(errorMessage: 'An unexpected error occurred. Please try again.');
  }
}

// Update email verified status in Firestore
Future<void> updateEmailVerifiedStatus(String uid) async {
  FirebaseFirestore _firestore = FirebaseFirestore.instance;
  await _firestore.collection('users').doc(uid).update({
    "emailVerified": true,
    "status": "Online",
  });
}

Future<AuthResult> logIn(String email, String password) async {
  FirebaseAuth _auth = FirebaseAuth.instance;

  FirebaseFirestore _firestore = FirebaseFirestore.instance;

  try {
    User? user = (await _auth.signInWithEmailAndPassword(
            email: email, password: password))
        .user;

    await _firestore
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .get()
        .then((value) {
      user?.updateDisplayName(value['name']);
    });

    if (user != null) {
      if (kDebugMode) { debugPrint("Login Successful"); }

      // Initialize encryption keys if not already present
      await KeyManager.initializeKeys();
      if (kDebugMode) { debugPrint("✅ Encryption keys ready"); }

      return AuthResult(user: user);
    } else {
      if (kDebugMode) { debugPrint("Login Failed"); }
      return AuthResult(errorMessage: 'Login failed. Please try again.');
    }
  } on FirebaseAuthException catch (e) {
    if (kDebugMode) { debugPrint('Firebase Auth Error: ${e.code}'); }
    return AuthResult(errorMessage: getAuthErrorMessage(e));
  } catch (e) {
    if (kDebugMode) { debugPrint('Unexpected error: $e'); }
    return AuthResult(errorMessage: 'An unexpected error occurred. Please try again.');
  }
}

Future logOut() async {
  FirebaseAuth _auth = FirebaseAuth.instance;

  try {
    // Google Sign In 7.x API - use static instance
    await GoogleSignIn.instance.signOut();
    await _auth.signOut();
  } catch (e) {
    if (kDebugMode) { debugPrint("error"); }
  }
}

Future<User?> signInWithGoogle() async {
  FirebaseAuth _auth = FirebaseAuth.instance;

  FirebaseFirestore _firestore = FirebaseFirestore.instance;

  try {
    // Google Sign In 7.x API - initialize and authenticate
    await GoogleSignIn.instance.initialize();
    
    final GoogleSignInAccount googleUser;
    try {
      googleUser = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      // User cancelled or error occurred
      if (kDebugMode) { debugPrint('Google Sign In cancelled or failed: $e'); }
      return null;
    }

    // Get authorization tokens for Firebase
    final GoogleSignInClientAuthorization? auth = 
        await googleUser.authorizationClient.authorizationForScopes([]);
    
    if (auth == null) {
      if (kDebugMode) { debugPrint('Failed to get authorization tokens'); }
      return null;
    }

    // Get authentication tokens (idToken from authentication getter)
    final GoogleSignInAuthentication googleAuth = googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) {
      if (kDebugMode) { debugPrint('Failed to get ID token'); }
      return null;
    }

    final credential = GoogleAuthProvider.credential(
      accessToken: auth.accessToken,
      idToken: idToken,
    );

    await _auth.signInWithCredential(credential);
    User? user = (await _auth.signInWithCredential(credential)).user;
    if (user != null) {
      await _firestore.collection('users').doc(_auth.currentUser?.uid).set({
        "name": googleUser.displayName,
        "email": googleUser.email,
        "status": "Online",
        "uid": _auth.currentUser!.uid,
        "avatar": googleUser.photoUrl,
      });

      // Initialize encryption keys
      await KeyManager.initializeKeys();
      if (kDebugMode) { debugPrint("✅ Encryption keys initialized"); }

      if (kDebugMode) { debugPrint("Login Successful"); }
      return user;
    } else {
      if (kDebugMode) { debugPrint("Login Failed"); }
      return user;
    }
  } catch (e) {
    if (kDebugMode) { debugPrint('$e'); }
    return null;
  }
}

Future<User?> signInWithFacebook() async {
  FirebaseAuth _auth = FirebaseAuth.instance;

  FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final LoginResult loginResult = await FacebookAuth.instance
      .login(permissions: ['email', 'public_profile']);

  if (loginResult == LoginStatus.success) {
    final OAuthCredential oAuthCredential =
        FacebookAuthProvider.credential(loginResult.accessToken!.tokenString);

    User? user =
        (await FirebaseAuth.instance.signInWithCredential(oAuthCredential))
            .user;

    if (user != null) {
      await _firestore.collection('users').doc(_auth.currentUser?.uid).set({
        "name": user.displayName,
        "email": user.email,
        "status": "Online",
        "uid": _auth.currentUser!.uid,
        "avatar": user.photoURL,
      });

      // Initialize encryption keys
      await KeyManager.initializeKeys();
      if (kDebugMode) { debugPrint("✅ Encryption keys initialized"); }

      if (kDebugMode) { debugPrint("Login Successful"); }
      return user;
    } else {
      if (kDebugMode) { debugPrint("Login Failed"); }
      return user;
    }
  } else {
    if (kDebugMode) { debugPrint('${loginResult.message}'); }
  }
  return null;
}

Future<User?> getCurrentUser() async {
  FirebaseAuth _auth = FirebaseAuth.instance;

  User? currentUser;
  currentUser = _auth.currentUser;
  return currentUser;
}
