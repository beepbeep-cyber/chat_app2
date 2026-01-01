import 'package:my_porject/configs/app_theme.dart';

import 'package:my_porject/widgets/page_transitions.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:my_porject/screens/chathome_screen.dart';
import 'package:my_porject/screens/group/add_members_group.dart';

import '../../resources/methods.dart';

// ignore: must_be_immutable
class GroupInfo extends StatefulWidget {
  User user;
  List memberListt;
  bool isDeviceConnected;
  final String groupName, groupId;

  GroupInfo(
      {Key? key,
      required this.groupName,
      required this.groupId,
      required this.user,
      required this.memberListt,
      required this.isDeviceConnected})
      : super(key: key);

  @override
  State<GroupInfo> createState() => _GroupInfoState();
}

class _GroupInfoState extends State<GroupInfo> {
  FirebaseAuth _auth = FirebaseAuth.instance;
  FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List membersList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    getGroupMembers();
  }

  bool checkAdmin() {
    bool isAdmin = false;

    membersList.forEach((element) {
      if (element['uid'] == _auth.currentUser!.uid) {
        isAdmin = element['isAdmin'];
      }
    });

    return isAdmin;
  }

  void getGroupMembers() async {
    await _firestore
        .collection('groups')
        .doc(widget.groupId)
        .get()
        .then((value) {
      setState(() {
        membersList = value['members'];
        isLoading = false;
      });
    });
  }

  void showRemoveDialog(int index) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.person_remove_outlined, color: AppTheme.error, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Remove Member',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryDark,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to remove ${membersList[index]['name']} from this group?',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.gray700,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.gray700,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text('Cancel', style: TextStyle(fontSize: 15)),
            ),
            ElevatedButton(
              onPressed: () {
                removeMember(index);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Remove', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }

  void removeMember(int index) async {
    if (checkAdmin()) {
      if (_auth.currentUser!.uid != membersList[index]['uid']) {
        setState(() {
          isLoading = true;
        });

        await _firestore
            .collection('groups')
            .doc(widget.groupId)
            .collection('chats')
            .add({
          "message":
              "${widget.user.displayName} removed ${membersList[index]['name']}",
          "type": "notify",
          "time": timeForMessage(DateTime.now().toString()),
          'timeStamp': DateTime.now(),
        });
        await _firestore
            .collection('users')
            .doc(membersList[index]['uid'])
            .collection('groups')
            .doc(widget.groupId)
            .delete();
        await _firestore
            .collection('users')
            .doc(widget.user.uid)
            .collection('chatHistory')
            .doc(widget.groupId)
            .update({
          'lastMessage': "Bạn removed ${membersList[index]['name']}",
          'type': "notify",
          'time': timeForMessage(DateTime.now().toString()),
          'timeStamp': DateTime.now(),
          'isRead': true,
        });

        for (int i = 1; i < membersList.length; i++) {
          await _firestore
              .collection('users')
              .doc(membersList[i]['uid'])
              .collection('chatHistory')
              .doc(widget.groupId)
              .update({
            'lastMessage':
                "${widget.user.displayName} removed ${membersList[index]['name']}",
            'type': "notify",
            'time': timeForMessage(DateTime.now().toString()),
            'timeStamp': DateTime.now(),
            'isRead': false,
          });
        }
        await _firestore
            .collection('users')
            .doc(membersList[index]['uid'])
            .collection('chatHistory')
            .doc(widget.groupId)
            .delete();
        membersList.removeAt(index);

        await _firestore.collection('groups').doc(widget.groupId).update({
          "members": membersList,
        });
        // await _firestore.collection('users').doc(uid).collection('chatHistory').doc(widget.groupId).delete();
        setState(() {
          isLoading = false;
        });
      }
    } else {
      if (kDebugMode) { debugPrint("Cant remove"); }
    }
  }

  void _showAutoDeleteSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppTheme.gray300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.auto_delete, color: AppTheme.warning, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Auto-delete Messages',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryDark,
                        ),
                      ),
                      Text(
                        'Automatically delete old messages',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.gray600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Auto-delete options
            _buildAutoDeleteOption('Off', 'Messages will not be deleted', Icons.block, null),
            _buildAutoDeleteOption('1 Minute', 'Delete after 1 minute', Icons.timer, 1),
            _buildAutoDeleteOption('5 Minutes', 'Delete after 5 minutes', Icons.timer_3, 5),
            _buildAutoDeleteOption('1 Hour', 'Delete after 1 hour', Icons.schedule, 60),
            _buildAutoDeleteOption('1 Day', 'Delete after 24 hours', Icons.calendar_today, 1440),
            _buildAutoDeleteOption('1 Week', 'Delete after 7 days', Icons.calendar_month, 10080),
            const SizedBox(height: 16),
            // Delete All Messages Button
            Container(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showDeleteAllMessagesConfirmation();
                },
                icon: const Icon(Icons.delete_forever, color: Colors.white),
                label: const Text(
                  'Delete All Messages',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.error,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoDeleteOption(String title, String subtitle, IconData icon, int? minutes) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.gray200 ?? Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: () {
          _saveAutoDeleteSetting(minutes);
          Navigator.pop(context);
        },
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.gray100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.gray700, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppTheme.primaryDark,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.gray600,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
      ),
    );
  }

  Future<void> _saveAutoDeleteSetting(int? minutes) async {
    try {
      // Get member UIDs for auto-delete service
      List<String> memberUids = membersList.map((m) => m['uid'].toString()).toList();
      
      await _firestore.collection('groups').doc(widget.groupId).set({
        'autoDeleteEnabled': minutes != null,
        'autoDeleteDuration': minutes ?? 0,
        'autoDeleteUpdatedBy': _auth.currentUser!.uid,
        'autoDeleteUpdatedAt': DateTime.now(),
        'memberUids': memberUids, // Store member UIDs for auto-delete to update chat history
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(minutes == null 
              ? 'Auto-delete disabled' 
              : 'Auto-delete set to ${_getDurationText(minutes)}'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  /// Show confirmation dialog for deleting all messages
  void _showDeleteAllMessagesConfirmation() {
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
            const Expanded(
              child: Text(
                'Delete All Messages?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will permanently delete ALL messages in this group chat for everyone.',
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
              await _deleteAllGroupMessages();
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

  /// Delete all messages in group chat
  Future<void> _deleteAllGroupMessages() async {
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
            Text('Deleting all messages...'),
          ],
        ),
      ),
    );

    try {
      // Get all messages in group chat
      final messagesSnapshot = await _firestore
          .collection('groups')
          .doc(widget.groupId)
          .collection('chats')
          .get();

      // Delete in batches
      final batch = _firestore.batch();
      int count = 0;
      for (var doc in messagesSnapshot.docs) {
        batch.delete(doc.reference);
        count++;
        // Commit batch every 450 documents
        if (count % 450 == 0) {
          await batch.commit();
        }
      }
      await batch.commit();

      // Update chat history for all members
      for (var member in membersList) {
        await _firestore
            .collection('users')
            .doc(member['uid'])
            .collection('chatHistory')
            .doc(widget.groupId)
            .update({
          'lastMessage': 'All messages have been deleted',
          'time': timeForMessage(DateTime.now().toString()),
          'timeStamp': DateTime.now(),
        });
      }

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('All messages deleted successfully!'),
              ],
            ),
            backgroundColor: AppTheme.success,
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
            content: Text('Error deleting messages: $e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _getDurationText(int minutes) {
    if (minutes < 60) return '$minutes minutes';
    if (minutes < 1440) return '${minutes ~/ 60} hour${minutes >= 120 ? "s" : ""}';
    return '${minutes ~/ 1440} day${minutes >= 2880 ? "s" : ""}';
  }

  void onLeaveGroup() async {
    if (!checkAdmin()) {
      setState(() {
        isLoading = true;
      });

      String uid = _auth.currentUser!.uid;

      await _firestore
          .collection('groups')
          .doc(widget.groupId)
          .collection('chats')
          .add({
        "message": "${widget.user.displayName} has left the group",
        "type": "notify",
        "time": timeForMessage(DateTime.now().toString()),
        'timeStamp': DateTime.now(),
      });
      for (int i = 0; i < membersList.length; i++) {
        await _firestore
            .collection('users')
            .doc(membersList[i]['uid'])
            .collection('chatHistory')
            .doc(widget.groupId)
            .update({
          'lastMessage': "${widget.user.displayName} has left the group",
          'type': "notify",
          'time': timeForMessage(DateTime.now().toString()),
          'timeStamp': DateTime.now(),
          'isRead': false,
        });
      }
      for (int i = 0; i < membersList.length; i++) {
        if (membersList[i]['uid'] == uid) {
          membersList.removeAt(i);
        }
      }

      await _firestore.collection('groups').doc(widget.groupId).update({
        "members": membersList,
      });
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('groups')
          .doc(widget.groupId)
          .delete();
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('chatHistory')
          .doc(widget.groupId)
          .delete();
      Navigator.push(
        context,
        SlideRightRoute(
            page: HomeScreen(
                  user: widget.user,
                )),
      );
    } else {
      if (kDebugMode) { debugPrint("Cant leave group!"); }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.gray50,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryDark,
        elevation: 2,
        shadowColor: Colors.black.withAlpha(76),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: AppTheme.gray100, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Group Info',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.gray100,
          ),
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: AppTheme.primaryDark))
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Group Header Card
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withValues(alpha: 0.1),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Group Avatar
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.gray300!, width: 2),
                          ),
                          child: const CircleAvatar(
                            backgroundImage: CachedNetworkImageProvider(
                              "https://firebasestorage.googleapis.com/v0/b/chatapptest2-93793.appspot.com/o/images%2F2a2c7410-7b06-11ed-aa52-c50d48cba6ef.jpg?alt=media&token=1b11fc5a-2294-4db8-94bf-7bd083f54b98",
                            ),
                            radius: 38,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Group Name
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            widget.groupName,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryDark,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Member Count
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.gray100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${membersList.length} Members',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.gray700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Add Member Button
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withValues(alpha: 0.1),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: ListTile(
                      onTap: () {
                        if (widget.isDeviceConnected == false) {
                          showDialogInternetCheck();
                        } else {
                          Navigator.push(
                            context,
                            SlideRightRoute(
                              page: AddMemberInGroup(
                                groupName: widget.groupName,
                                groupId: widget.groupId,
                                membersList: membersList,
                                user: widget.user,
                              ),
                            ),
                          );
                        }
                      },
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.person_add_outlined, color: AppTheme.accent, size: 22),
                      ),
                      title: Text(
                        'Add Member',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.primaryDark,
                        ),
                      ),
                      trailing: Icon(Icons.chevron_right, color: AppTheme.gray400),
                    ),
                  ),

                  // Auto-delete Messages Section
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withValues(alpha: 0.1),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: ListTile(
                      onTap: () {
                        if (widget.isDeviceConnected == false) {
                          showDialogInternetCheck();
                        } else if (checkAdmin()) {
                          _showAutoDeleteSettings();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Only admins can change auto-delete settings'),
                              backgroundColor: AppTheme.warning,
                            ),
                          );
                        }
                      },
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.auto_delete_outlined, color: AppTheme.warning, size: 22),
                      ),
                      title: Text(
                        'Auto-delete Messages',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.primaryDark,
                        ),
                      ),
                      subtitle: Text(
                        'Automatically delete old messages',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.gray600,
                        ),
                      ),
                      trailing: Icon(Icons.chevron_right, color: AppTheme.gray400),
                    ),
                  ),

                  // Members List Section
                  Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withValues(alpha: 0.1),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Members',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.gray800,
                            ),
                          ),
                        ),
                        Divider(height: 1, color: AppTheme.gray200),
                        ListView.builder(
                          itemCount: membersList.length,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemBuilder: (context, index) {
                            bool isAdmin = membersList[index]['isAdmin'] ?? false;
                            bool isCurrentUser = membersList[index]['uid'] == _auth.currentUser!.uid;
                            
                            return ListTile(
                              onTap: () {
                                if (widget.isDeviceConnected == false) {
                                  showDialogInternetCheck();
                                } else if (checkAdmin() && !isCurrentUser) {
                                  showRemoveDialog(index);
                                }
                              },
                              leading: Stack(
                                children: [
                                  CircleAvatar(
                                    backgroundImage: CachedNetworkImageProvider(
                                      membersList[index]['avatar'],
                                    ),
                                    radius: 22,
                                  ),
                                  if (isAdmin)
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        width: 16,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          color: AppTheme.accent,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2),
                                        ),
                                        child: const Icon(
                                          Icons.star,
                                          color: Colors.white,
                                          size: 10,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              title: Text(
                                membersList[index]['name'],
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.primaryDark,
                                ),
                              ),
                              subtitle: Text(
                                membersList[index]['email'],
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.gray600,
                                ),
                              ),
                              trailing: isAdmin
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.accent.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Admin',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.accent,
                                        ),
                                      ),
                                    )
                                  : (checkAdmin() && !isCurrentUser)
                                      ? Icon(Icons.more_vert, color: AppTheme.gray400, size: 20)
                                      : null,
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  // Leave Group Button
                  Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withValues(alpha: 0.1),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: ListTile(
                      onTap: () {
                        if (widget.isDeviceConnected == false) {
                          showDialogInternetCheck();
                        } else {
                          onLeaveGroup();
                        }
                      },
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.logout, color: AppTheme.error, size: 22),
                      ),
                      title: Text(
                        'Leave Group',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.error,
                        ),
                      ),
                      trailing: Icon(Icons.chevron_right, color: AppTheme.gray400),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            )
    );
  }

  showDialogInternetCheck() => showCupertinoDialog<String>(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
            title: const Text(
              'No Connection',
              style: TextStyle(
                letterSpacing: 0.5,
              ),
            ),
            content: const Text(
              'Please check your internet connectivity',
              style: TextStyle(letterSpacing: 0.5, fontSize: 12),
            ),
            actions: <Widget>[
              TextButton(
                  onPressed: () async {
                    Navigator.pop(context, 'Cancel');
                  },
                  child: const Text(
                    'OK',
                    style: TextStyle(letterSpacing: 0.5, fontSize: 15),
                  ))
            ],
          ));
}
