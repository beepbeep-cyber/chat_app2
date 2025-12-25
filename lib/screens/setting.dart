import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_porject/screens/login_screen.dart';
import 'package:my_porject/services/biometric_auth_service.dart';
import 'package:my_porject/services/fcm_service.dart';
import 'package:my_porject/services/user_presence_service.dart';
import 'package:my_porject/configs/app_theme.dart';
import 'package:my_porject/widgets/page_transitions.dart';
import 'package:uuid/uuid.dart';

// ignore: must_be_immutable
class Setting extends StatefulWidget {
  User user;
  bool isDeviceConnected;
  Setting({key, required this.user, required this.isDeviceConnected});

  @override
  State<Setting> createState() => _SettingState();
}

class _SettingState extends State<Setting> {
  FirebaseFirestore _firestore = FirebaseFirestore.instance;

  FirebaseAuth _auth = FirebaseAuth.instance;

  File? imageFile;

  bool isLoading = false;

  late Map<String, dynamic> userMap;
  
  // Biometric Authentication
  final BiometricAuthService _biometricService = BiometricAuthService();
  bool _isBiometricEnabled = false;
  bool _isBiometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
    _loadBiometricSetting();
  }
  
  Future<void> _checkBiometricAvailability() async {
    if (kDebugMode) { debugPrint('⚙️ [Settings] Checking biometric availability...'); }
    final isAvailable = await _biometricService.isBiometricAvailable();
    if (kDebugMode) { debugPrint('⚙️ [Settings] Biometric available: $isAvailable'); }
    if (mounted) {
      setState(() {
        _isBiometricAvailable = isAvailable;
      });
    }
  }
  
  Future<void> _loadBiometricSetting() async {
    if (kDebugMode) { debugPrint('⚙️ [Settings] Loading biometric setting...'); }
    final isEnabled = await _biometricService.isBiometricEnabled();
    if (kDebugMode) { debugPrint('⚙️ [Settings] Biometric enabled: $isEnabled'); }
    if (mounted) {
      setState(() {
        _isBiometricEnabled = isEnabled;
      });
    }
  }
  
  Future<void> _toggleBiometric(bool value) async {
    if (kDebugMode) { debugPrint('🔄 [Settings] Toggle biometric: $value'); }
    
    if (!_isBiometricAvailable) {
      if (kDebugMode) { debugPrint('❌ [Settings] Biometric not available on this device'); }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Biometric authentication is not available on this device'),
            backgroundColor: AppTheme.warning,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    
    if (value) {
      // Enable biometric - require authentication first
      if (kDebugMode) { debugPrint('🔐 [Settings] Requesting biometric authentication...'); }
      
      try {
        final authenticated = await _biometricService.authenticate(
          localizedReason: 'Authenticate to enable biometric lock',
        );
        
        if (kDebugMode) { debugPrint('🔐 [Settings] Authentication result: $authenticated'); }
        
        if (authenticated) {
          if (kDebugMode) { debugPrint('✅ [Settings] Enabling biometric lock...'); }
          await _biometricService.setBiometricEnabled(true);
          if (mounted) {
            setState(() {
              _isBiometricEnabled = true;
            });
            if (kDebugMode) { debugPrint('✅ [Settings] Biometric lock enabled!'); }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Biometric lock enabled successfully'),
                backgroundColor: AppTheme.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } else {
          if (kDebugMode) { debugPrint('❌ [Settings] Authentication failed'); }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Authentication failed. Please try again.'),
                backgroundColor: AppTheme.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      } catch (e) {
        if (kDebugMode) { debugPrint('❌ [Settings] Error during authentication: $e'); }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: AppTheme.error,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } else {
      // Disable biometric
      if (kDebugMode) { debugPrint('🔓 [Settings] Disabling biometric lock...'); }
      await _biometricService.setBiometricEnabled(false);
      await _biometricService.clearAuthenticationState();
      if (mounted) {
        setState(() {
          _isBiometricEnabled = false;
        });
        if (kDebugMode) { debugPrint('✅ [Settings] Biometric lock disabled!'); }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Biometric lock disabled'),
            backgroundColor: AppTheme.textSecondary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future getImage() async {
    ImagePicker _picker = ImagePicker();

    await _picker.pickImage(source: ImageSource.gallery).then((xFile) {
      if (xFile != null) {
        imageFile = File(xFile.path);
        uploadImage();
      }
    });
  }

  Future uploadImage() async {
    setState(() {
      isLoading = true;
    });

    String fileName = const Uuid().v1();

    int status = 1;

    var ref =
        FirebaseStorage.instance.ref().child('images').child("$fileName.jpg");

    var uploadTask = await ref.putFile(imageFile!).catchError((error) async {
      status = 0;
      throw error; // Re-throw to satisfy return type
    });

    if (status == 1) {
      String imageUrl = await uploadTask.ref.getDownloadURL();

      await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
        'avatar': imageUrl,
      });
      int? n;
      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('chatHistory')
          .get()
          .then((value) => {n = value.docs.length});
      for (int i = 0; i < n!; i++) {
        String? uId;
        await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .collection('chatHistory')
            .get()
            .then((value) {
          if (value.docs[i]['datatype'] == 'p2p' &&
              value.docs[i]['uid'] != _auth.currentUser!.uid) {
            uId = value.docs[i]['uid'];
            _firestore
                .collection('users')
                .doc(uId)
                .collection('chatHistory')
                .doc(_auth.currentUser!.uid)
                .update({
              'avatar': imageUrl,
            });
          }
        });
      }
    }
    setState(() {
      isLoading = false;
    });
  }

  Future<void> logOuttt() async {
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
            Icon(Icons.logout, color: Colors.red[700], size: 28),
            const SizedBox(width: 12),
            Text(
              'Confirm Logout',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[900],
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to log out?',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey[600], fontSize: 15),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() {
                isLoading = true;
              });
              await turnOffStatus();
              await logOut();
              setState(() {
                isLoading = false;
              });
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                    SlideRightRoute(page: Login()),
                    (Route<dynamic> route) => false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text('Logout', style: TextStyle(fontSize: 15)),
          ),
        ],
      ),
    );
  }

  Future<void> logOut() async {
    try {
      // 1. Clear FCM token from Firestore (prevent notifications to logged out user)
      await FCMService().clearToken();
      if (kDebugMode) { debugPrint('✅ [Logout] FCM token cleared'); }

      // 2. Clear biometric authentication state
      await _biometricService.clearAuthenticationState();
      await _biometricService.setBiometricEnabled(false);
      if (kDebugMode) { debugPrint('✅ [Logout] Biometric state cleared'); }

      // 3. Update user status to Offline before logout
      if (_auth.currentUser != null) {
        await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
          'status': 'Offline',
          'lastSeen': FieldValue.serverTimestamp(),
          'isStatusLocked': false,
        });
        if (kDebugMode) { debugPrint('✅ [Logout] User status set to Offline'); }
      }

      // 4. Set user offline via presence service
      await UserPresenceService().setUserOffline();
      if (kDebugMode) { debugPrint('✅ [Logout] User status set to offline via presence service'); }

      // 5. Sign out from Firebase Auth
      await _auth.signOut();
      if (kDebugMode) { debugPrint('✅ [Logout] Firebase signOut completed'); }
    } catch (e) {
      if (kDebugMode) { debugPrint('❌ [Logout] Error during logout: $e'); }
      // Still try to sign out even if other operations fail
      await _auth.signOut();
    }
  }

  showTurnOffStatus() {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              backgroundColor: AppTheme.surfaceLight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(Icons.visibility_off, color: Colors.grey[700], size: 28),
                  const SizedBox(width: 12),
                  Text(
                    "Turn Off Status?",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[900],
                    ),
                  ),
                ],
              ),
              content: Text(
                "Your online status will be hidden from others.",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.4,
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () async {
                    Navigator.maybePop(context);
                  },
                  child: Text(
                    "Cancel",
                    style: TextStyle(color: Colors.grey[600], fontSize: 15),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    turnOffStatus();
                    setState(() {
                      isLoading = false;
                    });
                    Navigator.maybePop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  child: const Text("Confirm", style: TextStyle(fontSize: 15)),
                ),
              ],
            ));
  }

  turnOffStatus() async {
    setState(() {
      isLoading = true;
    });
    // Update both isStatusLocked AND status in user's own document
    await _firestore.collection('users').doc(_auth.currentUser?.uid).update({
      "isStatusLocked": true,
      "status": "Offline",  // Force status to Offline when locked
    });
    
    int? n;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .collection('chatHistory')
        .get()
        .then((value) => {n = value.docs.length});
    for (int i = 0; i < n!; i++) {
      String? uId;
      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('chatHistory')
          .get()
          .then((value) {
        if (value.docs[i]['datatype'] == 'p2p' &&
            value.docs[i]['uid'] != _auth.currentUser!.uid) {
          uId = value.docs[i]['uid'];
          _firestore
              .collection('users')
              .doc(uId)
              .collection('chatHistory')
              .doc(_auth.currentUser!.uid)
              .update({
            'status': 'Offline',
          });
        }
      });
    }
    setState(() {
      isLoading = false;
    });
  }

  turnOnStatus() async {
    setState(() {
      isLoading = true;
    });
    // Update both isStatusLocked AND status to Online
    await _firestore.collection('users').doc(_auth.currentUser?.uid).update({
      "isStatusLocked": false,
      "status": "Online",  // Set status back to Online when unlocked
    });
    int? n;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .collection('chatHistory')
        .get()
        .then((value) => {n = value.docs.length});
    for (int i = 0; i < n!; i++) {
      String? uId;
      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('chatHistory')
          .get()
          .then((value) {
        if (value.docs[i]['datatype'] == 'p2p' &&
            value.docs[i]['uid'] != _auth.currentUser!.uid) {
          uId = value.docs[i]['uid'];
          _firestore
              .collection('users')
              .doc(uId)
              .collection('chatHistory')
              .doc(_auth.currentUser!.uid)
              .update({
            'status': 'Online',
          });
        }
      });
    }
    setState(() {
      isLoading = false;
    });
  }

  showTurnOnStatus() {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              backgroundColor: AppTheme.surfaceLight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(Icons.visibility, color: Colors.green[700], size: 28),
                  const SizedBox(width: 12),
                  Text(
                    "Turn On Status?",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[900],
                    ),
                  ),
                ],
              ),
              content: Text(
                "Your online status will be visible to others.",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.4,
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () async {
                    Navigator.maybePop(context);
                  },
                  child: Text(
                    "Cancel",
                    style: TextStyle(color: Colors.grey[600], fontSize: 15),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    turnOnStatus();
                    Navigator.maybePop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  child: const Text("Confirm", style: TextStyle(fontSize: 15)),
                ),
              ],
            ));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: isLoading
          ? Container(
              height: size.height,
              width: size.width,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(),
            )
          : StreamBuilder<DocumentSnapshot>(
              stream: _firestore
                  .collection('users')
                  .doc(widget.user.uid.isNotEmpty ? widget.user.uid : "0")
                  .snapshots(),
              builder: (BuildContext context,
                  AsyncSnapshot<DocumentSnapshot> snapshot) {
                if (snapshot.data != null) {
                  Map<String, dynamic> map =
                      snapshot.data?.data() as Map<String, dynamic>;
                  return CustomScrollView(
                    slivers: [
                      // App Bar
                      SliverAppBar(
                        backgroundColor: AppTheme.surfaceLight,
                        elevation: 0,
                        pinned: true,
                        expandedHeight: 0,
                        automaticallyImplyLeading: false,
                        title: Text(
                          "Profile",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[900],
                          ),
                        ),
                        centerTitle: true,
                      ),
                      
                      // Profile Content
                      SliverToBoxAdapter(
                        child: Column(
                          children: [
                            const SizedBox(height: 20),
                            
                            // Profile Avatar Section
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 20),
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withValues(alpha: 0.1),
                                    spreadRadius: 2,
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  // Avatar with Edit Button
                                  GestureDetector(
                                    onTap: () {
                                      if (widget.isDeviceConnected == false) {
                                        showDialogInternetCheck();
                                      } else {
                                        getImage();
                                      }
                                    },
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Container(
                                          width: 120,
                                          height: 120,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.grey[300]!,
                                              width: 3,
                                            ),
                                            image: DecorationImage(
                                              image: CachedNetworkImageProvider(
                                                map['avatar'] ??
                                                    widget.user.photoURL ??
                                                    '',
                                              ),
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: Colors.grey[800],
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 3,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.grey
                                                      .withValues(alpha: 0.3),
                                                  spreadRadius: 1,
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: const Icon(
                                              Icons.camera_alt,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  const SizedBox(height: 16),
                                  
                                  // User Name
                                  Text(
                                    map['name'] ?? 'User Name',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 24,
                                      color: Colors.grey[900],
                                    ),
                                  ),
                                  
                                  const SizedBox(height: 8),
                                  
                                  // Status Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: (map['isStatusLocked'] == true)
                                          ? Colors.grey.withValues(alpha: 0.1)
                                          : (map['status']
                                              .toLowerCase()
                                              .contains('online')
                                          ? Colors.green.withValues(alpha: 0.1)
                                          : Colors.grey.withValues(alpha: 0.1)),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: (map['isStatusLocked'] == true)
                                                ? Colors.grey[400]
                                                : (map['status']
                                                    .toLowerCase()
                                                    .contains('online')
                                                ? Colors.green
                                                : Colors.grey[400]),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          (map['isStatusLocked'] == true) 
                                              ? 'Offline' 
                                              : (map['status'] ?? 'Offline'),
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: (map['isStatusLocked'] == true)
                                                ? Colors.grey[600]
                                                : (map['status']
                                                    .toLowerCase()
                                                    .contains('online')
                                                ? Colors.green[700]
                                                : Colors.grey[600]),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Account Information Section
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withValues(alpha: 0.1),
                                    spreadRadius: 2,
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text(
                                      "Account Information",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                  ),
                                  Divider(height: 1, color: Colors.grey[200]),
                                  
                                  // Name Row
                                  _buildInfoRow(
                                    icon: Icons.person_outline,
                                    label: "Name",
                                    value: map['name'] ?? 'N/A',
                                    isLast: false,
                                  ),
                                  
                                  // Email Row
                                  _buildInfoRow(
                                    icon: Icons.email_outlined,
                                    label: "Email",
                                    value: map['email'] ?? 'N/A',
                                    isLast: false,
                                  ),
                                  
                                  // Status Row with Toggle
                                  _buildStatusRow(
                                    map: map,
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Privacy & Security Section
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withValues(alpha: 0.1),
                                    spreadRadius: 2,
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Icon(Icons.security, color: Colors.blue[700], size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          "Privacy & Security",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey[800],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Divider(height: 1, color: Colors.grey[200]),
                                  
                                  // Biometric Lock Toggle
                                  _buildBiometricToggle(),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Settings Section
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withValues(alpha: 0.1),
                                    spreadRadius: 2,
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  // Help Option
                                  _buildMenuOption(
                                    icon: Icons.help_outline,
                                    title: "Help & Support",
                                    subtitle: "Get help and contact support",
                                    onTap: () {
                                      // Navigate to help screen
                                    },
                                    isLast: true,
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Logout Button
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 20),
                              child: ElevatedButton(
                                onPressed: () {
                                  if (widget.isDeviceConnected == false) {
                                    showDialogInternetCheck();
                                  } else {
                                    logOuttt();
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red[50],
                                  foregroundColor: Colors.red[700],
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: Colors.red[200]!),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  minimumSize: const Size(double.infinity, 56),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.logout, color: Colors.red[700]),
                                    const SizedBox(width: 12),
                                    Text(
                                      "Log Out",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.red[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ],
                  );
                } else {
                  return Container();
                }
              }),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isLast,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(color: Colors.grey[200]!, width: 1),
              ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.grey[700], size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[900],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow({required Map<String, dynamic> map}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.online_prediction_outlined,
                color: Colors.grey[700], size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Online Status",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  map['isStatusLocked'] == true ? "Hidden" : "Visible",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[900],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: map['isStatusLocked'] != true,
            onChanged: (value) {
              if (value) {
                showTurnOnStatus();
              } else {
                showTurnOffStatus();
              }
            },
            activeTrackColor: Colors.green[600],
            activeThumbColor: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isLast,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(color: Colors.grey[200]!, width: 1),
                ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.blue[700], size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[900],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                color: Colors.grey[400], size: 16),
          ],
        ),
      ),
    );
  }
  
  Widget _buildBiometricToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.fingerprint, color: Colors.blue[700], size: 28),
          ),
          const SizedBox(width: 16),
          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Biometric Lock",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[900],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isBiometricAvailable 
                    ? (_isBiometricEnabled 
                        ? "App is locked with biometric" 
                        : "Lock app with fingerprint or face")
                    : "Biometric not available on this device",
                  style: TextStyle(
                    fontSize: 13,
                    color: _isBiometricAvailable ? Colors.grey[600] : Colors.red[400],
                  ),
                ),
              ],
            ),
          ),
          // Toggle Switch
          Switch(
            value: _isBiometricEnabled,
            onChanged: _isBiometricAvailable ? _toggleBiometric : null,
            activeColor: Colors.blue[700],
            activeTrackColor: Colors.blue[200],
            inactiveThumbColor: Colors.grey[400],
            inactiveTrackColor: Colors.grey[200],
          ),
        ],
      ),
    );
  }

  showDialogInternetCheck() => showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
            backgroundColor: AppTheme.surfaceLight,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.grey[700], size: 28),
                const SizedBox(width: 12),
                Text(
                  'No Connection',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[900],
                  ),
                ),
              ],
            ),
            content: Text(
              'Please check your internet connectivity and try again.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
            actions: <Widget>[
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context, 'OK');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('OK', style: TextStyle(fontSize: 15)),
              ),
            ],
          ));
}
