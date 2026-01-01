import 'package:my_porject/configs/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_porject/services/auto_delete_service.dart';
import 'package:my_porject/widgets/loading_overlay.dart';

class ChatSettingsScreen extends StatefulWidget {
  final String chatRoomId;
  final Map<String, dynamic> userMap;

  const ChatSettingsScreen({
    super.key,
    required this.chatRoomId,
    required this.userMap,
  });

  @override
  State<ChatSettingsScreen> createState() => _ChatSettingsScreenState();
}

class _ChatSettingsScreenState extends State<ChatSettingsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _autoDeleteEnabled = false;
  int _selectedDuration = 0; // 0 = off, 1 = 1min, 5 = 5min, 60 = 1hour, 1440 = 24hours
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final doc = await _firestore
          .collection('chatroom')
          .doc(widget.chatRoomId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          _autoDeleteEnabled = data['autoDeleteEnabled'] ?? false;
          _selectedDuration = data['autoDeleteDuration'] ?? 0;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    try {
      // Get both user IDs from chatRoomId (format: uid1_uid2)
      final parts = widget.chatRoomId.split('_');
      List<String> userIds = [];
      if (parts.length >= 2) {
        userIds = [parts[0], parts[1]];
      } else {
        // Fallback: use current user and the other user
        userIds = [_auth.currentUser!.uid, widget.userMap['uid']];
      }
      
      await _firestore.collection('chatroom').doc(widget.chatRoomId).set({
        'autoDeleteEnabled': _autoDeleteEnabled,
        'autoDeleteDuration': _selectedDuration,
        'autoDeleteUpdatedBy': _auth.currentUser!.uid,
        'autoDeleteUpdatedAt': DateTime.now(),
        'users': userIds, // IMPORTANT: Store users list for auto-delete to update chat history
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully'),
            backgroundColor: AppTheme.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: AppTheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }



  Widget _buildDurationOption(int minutes, String label, IconData icon) {
    final isSelected = _selectedDuration == minutes && _autoDeleteEnabled;
    
    return GestureDetector(
      onTap: _autoDeleteEnabled
          ? () {
              setState(() {
                _selectedDuration = minutes;
              });
              _saveSettings();
            }
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.gray800
              : Colors.white,
          border: Border.all(
            color: isSelected ? AppTheme.gray700 : AppTheme.gray300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Colors.white
                  : _autoDeleteEnabled
                      ? AppTheme.gray800
                      : Colors.grey,
              size: 28,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : (_autoDeleteEnabled ? AppTheme.primaryDark : Colors.grey),
                    ),
                  ),
                  if (minutes > 0)
                    Text(
                      'Messages will be deleted after $label',
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected ? AppTheme.gray300 : (_autoDeleteEnabled
                            ? AppTheme.gray600
                            : Colors.grey),
                      ),
                    ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Colors.white,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        backgroundColor: AppTheme.gray50,
        appBar: AppBar(
          title: const Text('Chat Settings'),
          backgroundColor: AppTheme.primaryDark,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Section
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: AppTheme.gray800,
                          child: const Icon(
                            Icons.auto_delete,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Auto-Delete Messages',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Chat with ${widget.userMap['name']}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.gray600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Enable/Disable Toggle
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.gray300,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _autoDeleteEnabled
                                ? Icons.toggle_on
                                : Icons.toggle_off,
                            size: 48,
                            color: _autoDeleteEnabled
                                ? AppTheme.gray800
                                : Colors.grey,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Auto-Delete',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  _autoDeleteEnabled
                                      ? 'Messages will be deleted automatically'
                                      : 'Messages will not be deleted',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.gray600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _autoDeleteEnabled,
                            onChanged: (value) {
                              setState(() {
                                _autoDeleteEnabled = value;
                                if (!value) {
                                  _selectedDuration = 0;
                                }
                              });
                              _saveSettings();
                            },
                            activeTrackColor: AppTheme.gray700,
                            activeThumbColor: Colors.white,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Duration Options
                    if (_autoDeleteEnabled) ...[
                      const Text(
                        'Select Duration',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Choose how long messages should be kept',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.gray600,
                        ),
                      ),
                      const SizedBox(height: 16),

                      _buildDurationOption(1, '1 Minute', Icons.timer),
                      _buildDurationOption(5, '5 Minutes', Icons.timer_3),
                      _buildDurationOption(60, '1 Hour', Icons.hourglass_bottom),
                      _buildDurationOption(1440, '24 Hours', Icons.today),
                    ],

                    const SizedBox(height: 24),

                    // Information Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.amber[700],
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'How it works',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber[900],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Messages older than the selected duration will be automatically deleted from this chat. This setting applies to both users in this conversation.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.amber[900],
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Security Note
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.green.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.lock_outline,
                            color: AppTheme.success,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'All messages remain end-to-end encrypted. Auto-delete only removes messages from the database after the specified time.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.green[900],
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Delete All Messages Button
                    Container(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _showDeleteAllConfirmation,
                        icon: const Icon(Icons.delete_forever, color: Colors.white),
                        label: const Text(
                          'Delete All Messages',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.error,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
      ),
    );
  }

  /// Hiển thị dialog xác nhận xóa tất cả tin nhắn
  void _showDeleteAllConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.error, size: 28),
            const SizedBox(width: 12),
            const Text(
              'Delete All Messages?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will permanently delete ALL messages in this chat.',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.gray700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppTheme.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone!',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.error,
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
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.gray600),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteAllMessages();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }

  /// Xóa tất cả tin nhắn
  Future<void> _deleteAllMessages() async {
    // Save current settings before delete
    final savedEnabled = _autoDeleteEnabled;
    final savedDuration = _selectedDuration;
    
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Deleting messages...'),
          ],
        ),
      ),
    );

    try {
      final success = await AutoDeleteService().deleteAllMessages(widget.chatRoomId);

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (success && mounted) {
        // Reload settings from Firestore to ensure UI is in sync
        await _loadSettings();
        
        // If settings got lost somehow, restore them
        if (_autoDeleteEnabled != savedEnabled || _selectedDuration != savedDuration) {
          setState(() {
            _autoDeleteEnabled = savedEnabled;
            _selectedDuration = savedDuration;
          });
          // Re-save to ensure persistence
          await _saveSettings();
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  success ? Icons.check_circle : Icons.error,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    success 
                      ? 'All messages deleted! Auto-delete settings preserved.' 
                      : 'Failed to delete messages. Please try again.',
                  ),
                ),
              ],
            ),
            backgroundColor: success ? AppTheme.success : AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
