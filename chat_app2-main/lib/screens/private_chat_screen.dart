import 'package:my_porject/configs/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_porject/services/private_chat_service.dart';
import 'package:my_porject/screens/chat_screen.dart';
import 'package:my_porject/widgets/page_transitions.dart';
import 'package:my_porject/widgets/animated_avatar.dart';

/// Private Chat Screen - Hiển thị các đoạn chat được bảo mật bằng mật khẩu
class PrivateChatScreen extends StatefulWidget {
  final User user;
  final bool isDeviceConnected;

  const PrivateChatScreen({
    Key? key,
    required this.user,
    required this.isDeviceConnected,
  }) : super(key: key);

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  bool _isAuthenticated = false;
  bool _isLoading = true;
  bool _hasPassword = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final hasPassword = await PrivateChatService.hasPassword();
    final sessionValid = await PrivateChatService.isSessionValid();
    
    setState(() {
      _hasPassword = hasPassword;
      _isAuthenticated = sessionValid;
      _isLoading = false;
    });

    if (!hasPassword) {
      // Show setup password dialog
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSetupPasswordDialog();
      });
    } else if (!sessionValid) {
      // Show verify password dialog
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showVerifyPasswordDialog();
      });
    }
  }

  void _showSetupPasswordDialog() {
    final TextEditingController passwordController = TextEditingController();
    final TextEditingController confirmController = TextEditingController();
    bool obscurePassword = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.lock_outline, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                'Set Up Private Lock',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Create a password to protect your private chats',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.gray600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Password field
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter password (min 4 chars)',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Confirm password field
              TextField(
                controller: confirmController,
                obscureText: obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  hintText: 'Re-enter password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context); // Go back from private screen
              },
              child: Text('Cancel', style: TextStyle(color: AppTheme.gray600)),
            ),
            ElevatedButton(
              onPressed: () async {
                final password = passwordController.text;
                final confirm = confirmController.text;
                
                if (password.length < 4) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password must be at least 4 characters')),
                  );
                  return;
                }
                
                if (password != confirm) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Passwords do not match')),
                  );
                  return;
                }
                
                final success = await PrivateChatService.setPassword(password);
                if (success) {
                  await PrivateChatService.verifyPassword(password);
                  Navigator.pop(context);
                  setState(() {
                    _hasPassword = true;
                    _isAuthenticated = true;
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Set Password'),
            ),
          ],
        ),
      ),
    );
  }

  void _showVerifyPasswordDialog() {
    final TextEditingController passwordController = TextEditingController();
    bool obscurePassword = true;
    int attempts = 0;
    const maxAttempts = 5;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.lock, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                'Private Chats',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your password to access private chats',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.gray600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: TextField(
            controller: passwordController,
            obscureText: obscurePassword,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Enter your password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
              ),
            ),
            onSubmitted: (value) async {
              final isValid = await PrivateChatService.verifyPassword(value);
              if (isValid) {
                Navigator.pop(context);
                setState(() => _isAuthenticated = true);
              } else {
                attempts++;
                HapticFeedback.heavyImpact();
                if (attempts >= maxAttempts) {
                  Navigator.pop(context);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Too many failed attempts. Try again later.'),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                } else {
                  passwordController.clear();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Incorrect password. ${maxAttempts - attempts} attempts remaining.'),
                      backgroundColor: Colors.red[400],
                    ),
                  );
                }
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: Text('Cancel', style: TextStyle(color: AppTheme.gray600)),
            ),
            ElevatedButton(
              onPressed: () async {
                final isValid = await PrivateChatService.verifyPassword(passwordController.text);
                if (isValid) {
                  Navigator.pop(context);
                  setState(() => _isAuthenticated = true);
                } else {
                  attempts++;
                  HapticFeedback.heavyImpact();
                  if (attempts >= maxAttempts) {
                    Navigator.pop(context);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Too many failed attempts. Try again later.'),
                        backgroundColor: AppTheme.error,
                      ),
                    );
                  } else {
                    passwordController.clear();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Incorrect password. ${maxAttempts - attempts} attempts remaining.'),
                        backgroundColor: Colors.red[400],
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Unlock'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.gray50,
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF6366F1)),
        ),
      );
    }

    if (!_isAuthenticated) {
      return Scaffold(
        backgroundColor: AppTheme.gray50,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppTheme.gray800),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Private Chats',
            style: TextStyle(
              color: AppTheme.primaryDark,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 80, color: AppTheme.gray400),
              const SizedBox(height: 20),
              Text(
                'Authentication Required',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.gray700,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _hasPassword ? _showVerifyPasswordDialog : _showSetupPasswordDialog,
                icon: const Icon(Icons.lock_open),
                label: Text(_hasPassword ? 'Enter Password' : 'Set Up Password'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.gray50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.gray800),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.lock, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Text(
              'Private Chats',
              style: TextStyle(
                color: AppTheme.primaryDark,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: AppTheme.gray700),
            onSelected: (value) async {
              switch (value) {
                case 'change_password':
                  _showChangePasswordDialog();
                  break;
                case 'lock':
                  await PrivateChatService.clearSession();
                  setState(() => _isAuthenticated = false);
                  _showVerifyPasswordDialog();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'change_password',
                child: Row(
                  children: [
                    Icon(Icons.key, size: 20),
                    SizedBox(width: 12),
                    Text('Change Password'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'lock',
                child: Row(
                  children: [
                    Icon(Icons.lock_outline, size: 20),
                    SizedBox(width: 12),
                    Text('Lock Now'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: PrivateChatService.getPrivateChatsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF6366F1)),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          final privateChats = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: privateChats.length,
            itemBuilder: (context, index) {
              final chat = privateChats[index].data() as Map<String, dynamic>;
              return _buildPrivateChatTile(chat, privateChats[index].id);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_outline,
              size: 50,
              color: Color(0xFF6366F1),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Private Chats',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryDark,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Move important conversations here to keep them protected with a password',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.gray600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.symmetric(horizontal: 40),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.amber[700], size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Long press on any chat and select "Move to Private" to add it here',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.amber[900],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivateChatTile(Map<String, dynamic> chat, String chatRoomId) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openPrivateChat(chat, chatRoomId),
          onLongPress: () => _showRemoveDialog(chat, chatRoomId),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar with lock badge
                Stack(
                  children: [
                    AnimatedAvatar(
                      imageUrl: chat['chatAvatar'] ?? '',
                      name: chat['chatName'] ?? 'Private',
                      size: 56,
                      showStatus: false,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.lock, color: Colors.white, size: 10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                // Chat info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chat['chatName'] ?? 'Private Chat',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              chat['chatType'] == 'group' ? 'Group' : 'Private',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF6366F1),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.shield, size: 14, color: Colors.green[600]),
                          const SizedBox(width: 4),
                          Text(
                            'Protected',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Arrow
                Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.gray400),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openPrivateChat(Map<String, dynamic> chat, String chatRoomId) async {
    // Get chat details from Firestore
    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      
      if (chat['chatType'] == 'p2p') {
        // Get user info
        final userDoc = await firestore
            .collection('users')
            .where('name', isEqualTo: chat['chatName'])
            .limit(1)
            .get();
        
        if (userDoc.docs.isNotEmpty) {
          final userMap = userDoc.docs.first.data();
          if (mounted) {
            Navigator.push(
              context,
              SlideRightRoute(
                page: ChatScreen(
                  chatRoomId: chatRoomId,
                  userMap: userMap,
                  user: widget.user,
                  isDeviceConnected: widget.isDeviceConnected,
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      // Error logged
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open chat: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _showRemoveDialog(Map<String, dynamic> chat, String chatRoomId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Remove from Private?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryDark,
          ),
        ),
        content: Text(
          'This chat will be moved back to your regular chat list.',
          style: TextStyle(color: AppTheme.gray600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppTheme.gray600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await PrivateChatService.removeFromPrivate(chatRoomId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Chat removed from Private'),
                    backgroundColor: AppTheme.success,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final oldController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    bool obscureOld = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.key, color: Color(0xFF6366F1)),
              const SizedBox(width: 12),
              Text(
                'Change Password',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryDark,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: oldController,
                obscureText: obscureOld,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(obscureOld ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setDialogState(() => obscureOld = !obscureOld),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newController,
                obscureText: obscureNew,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmController,
                obscureText: obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: AppTheme.gray600)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (newController.text != confirmController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('New passwords do not match')),
                  );
                  return;
                }
                
                if (newController.text.length < 4) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password must be at least 4 characters')),
                  );
                  return;
                }
                
                final success = await PrivateChatService.changePassword(
                  oldController.text,
                  newController.text,
                );
                
                if (success) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password changed successfully'),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Current password is incorrect'),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Change'),
            ),
          ],
        ),
      ),
    );
  }
}
