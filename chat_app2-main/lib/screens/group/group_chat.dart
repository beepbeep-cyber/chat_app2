import 'package:my_porject/configs/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:my_porject/screens/group/group_chat_room.dart';
import 'package:my_porject/screens/group/create_group/add_member.dart';
import 'package:my_porject/widgets/page_transitions.dart';

// ignore: must_be_immutable
class GroupChatHomeScreen extends StatefulWidget {
  User user;
  bool isDeviceConnected;
  GroupChatHomeScreen(
      {Key? key, required this.user, required this.isDeviceConnected})
      : super(key: key);

  @override
  State<GroupChatHomeScreen> createState() => _GroupChatHomeScreenState();
}

class _GroupChatHomeScreenState extends State<GroupChatHomeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool isLoading = true;
  List groupList = [];

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: EdgeInsets.only(top: 16, left: 16, bottom: 8),
          child: Text(
            'My Groups',
            style: TextStyle(
              color: AppTheme.gray800,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              SingleChildScrollView(
                child: StreamBuilder(
                  stream: _firestore
                      .collection('users')
                      .doc(_auth.currentUser!.uid)
                      .collection('groups')
                      .snapshots(),
                  builder: (BuildContext context,
                      AsyncSnapshot<QuerySnapshot> snapshot) {
                    if (snapshot.data != null) {
                      return ListView.builder(
                          itemCount: snapshot.data?.docs.length,
                          shrinkWrap: true,
                          padding: const EdgeInsets.only(top: 5),
                          physics: const NeverScrollableScrollPhysics(),
                          itemBuilder: (context, index) {
                            Map<String, dynamic> map =
                                snapshot.data?.docs[index].data()
                                    as Map<String, dynamic>;
                            return listGroup(
                                map: map, memberList: map['members'] ?? []);
                          });
                    } else {
                      return Container();
                    }
                  },
                ),
              ),
              Positioned(
                right: 20.0,
                bottom: 20.0,
                child: FloatingActionButton(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  onPressed: () {
                    if (widget.isDeviceConnected == false) {
                      showDialogInternetCheck();
                    } else {
                      Navigator.push(
                          context,
                          SlideRightRoute(
                              page: AddMember(
                                    user: widget.user,
                                    isDeviceConnected: widget.isDeviceConnected,
                                  )));
                    }
                  },
                  tooltip: "Create Group",
                  child: const Icon(Icons.create),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget listGroup(
      {required Map<String, dynamic> map, required List<dynamic> memberList}) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
            context,
            SlideRightRoute(
                page: GroupChatRoom(
                      groupChatId: map['id'],
                      groupName: map['name'],
                      user: widget.user,
                      isDeviceConnected: widget.isDeviceConnected,
                    )));
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: <Widget>[
              Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      backgroundImage: CachedNetworkImageProvider(
                          "https://firebasestorage.googleapis.com/v0/b/chatapptest2-93793.appspot.com/o/images%2F2a2c7410-7b06-11ed-aa52-c50d48cba6ef.jpg?alt=media&token=1b11fc5a-2294-4db8-94bf-7bd083f54b98"),
                      radius: 28,
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppTheme.accent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.group,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      map['name'].toString().length >= 30
                          ? '${map['name'].toString().substring(0, 30)}...'
                          : map['name'],
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.gray800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    StreamBuilder<DocumentSnapshot>(
                      stream: _firestore
                          .collection('groups')
                          .doc(map['id'])
                          .snapshots(),
                      builder: (BuildContext context,
                          AsyncSnapshot<DocumentSnapshot> snapshots) {
                        if (snapshots.hasData) {
                          List length = snapshots.data!['members'];
                          return Row(
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 14,
                                color: AppTheme.gray600,
                              ),
                              SizedBox(width: 4),
                              Text(
                                '${length.length} members',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.gray600,
                                ),
                              ),
                            ],
                          );
                        } else {
                          return Container();
                        }
                      },
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: AppTheme.gray400,
                size: 24,
              ),
            ],
          ),
        ),
      ),
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
