import 'package:my_porject/configs/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:my_porject/screens/group/group_chat_room.dart';
import 'package:my_porject/widgets/page_transitions.dart';
import 'package:uuid/uuid.dart';

import '../../../resources/methods.dart';

// ignore: must_be_immutable
class CreateGroup extends StatefulWidget {
  User user;
  bool isDeviceConnected;
  final List<Map<String, dynamic>> memberList;
  CreateGroup(
      {Key? key,
      required this.memberList,
      required this.user,
      required this.isDeviceConnected})
      : super(key: key);

  @override
  State<CreateGroup> createState() => _CreateGroupState();
}

class _CreateGroupState extends State<CreateGroup> {
  final TextEditingController _groupName = TextEditingController();
  bool isLoading = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
  }

  List<String> usersName = [];
  String makeGroupName() {
    for (int i = 0; i < widget.memberList.length; i++) {
      usersName.add(widget.memberList[i]['name']);
    }
    if (kDebugMode) { debugPrint(usersName.join(", ")); }
    return usersName.join(", ");
  }

  void createGroup(String groupName) async {
    setState(() {
      isLoading = true;
    });

    String groupId = Uuid().v1();

    await _firestore.collection('groups').doc(groupId).set({
      "members": widget.memberList,
      "id": groupId,
    });

    for (int i = 0; i < widget.memberList.length; i++) {
      String uid = widget.memberList[i]['uid'];
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('groups')
          .doc(groupId)
          .set({
        "name": groupName,
        "id": groupId,
        'members': widget.memberList,
      });
    }

    await _firestore.collection('groups').doc(groupId).collection('chats').add({
      "message": "${widget.user.displayName} Created This Group",
      "type": "notify",
      "time": timeForMessage(DateTime.now().toString()),
      'timeStamp': DateTime.now(),
    });

    for (int i = 0; i < widget.memberList.length; i++) {
      await _firestore
          .collection('users')
          .doc(widget.memberList[i]['uid'])
          .collection('chatHistory')
          .doc(groupId)
          .set({
        'lastMessage': "${widget.user.displayName} Created This Group",
        'type': "notify",
        'name': groupName,
        'time': timeForMessage(DateTime.now().toString()),
        'uid': groupId,
        'avatar':
            "https://firebasestorage.googleapis.com/v0/b/chatapptest2-93793.appspot.com/o/images%2F2a2c7410-7b06-11ed-aa52-c50d48cba6ef.jpg?alt=media&token=1b11fc5a-2294-4db8-94bf-7bd083f54b98",
        'status': "Online",
        'datatype': "group",
        'timeStamp': DateTime.now(),
        'isRead': false,
      });
      await _firestore
          .collection('users')
          .doc(widget.memberList[i]['uid'])
          .collection('location')
          .doc(groupId)
          .set({
        'isLocationed': false,
      });
    }

    Navigator.of(context).pushAndRemoveUntil(
        SlideRightRoute(
            page: GroupChatRoom(
                  groupChatId: groupId,
                  groupName: groupName,
                  user: widget.user,
                  isDeviceConnected: widget.isDeviceConnected,
                )),
        (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryDark,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.gray100),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "Create New Group",
          style: TextStyle(
            color: AppTheme.gray100,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: isLoading
          ? Container(
              height: size.height,
              width: size.width,
              alignment: Alignment.center,
              child: CircularProgressIndicator(),
            )
          : Column(
              children: [
                SizedBox(
                  height: 10,
                ),
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Group Name',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.gray800,
                          ),
                        ),
                        SizedBox(height: 12),
                        TextField(
                          controller: _groupName,
                          decoration: InputDecoration(
                            hintText: "Enter group name...",
                            hintStyle: TextStyle(color: Colors.grey.shade400),
                            prefixIcon: Icon(
                              Icons.group,
                              color: Colors.grey.shade600,
                              size: 20,
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade200,
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: AppTheme.accent,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Leave empty to auto-generate from member names',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.gray600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shadowColor: Colors.blue.withValues(alpha: 0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        if (_groupName.text == '') {
                          createGroup(makeGroupName());
                        } else {
                          createGroup(_groupName.text);
                        }
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.group_add, size: 20),
                          SizedBox(width: 8),
                          Text(
                            "Create Group",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
