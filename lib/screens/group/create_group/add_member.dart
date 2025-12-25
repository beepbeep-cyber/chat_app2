import 'package:my_porject/configs/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:my_porject/screens/group/create_group/create_group.dart';
import 'package:my_porject/widgets/page_transitions.dart';
import 'package:my_porject/widgets/animated_avatar.dart';

class AddMember extends StatefulWidget {
  final User user;
  final bool isDeviceConnected;
  const AddMember({Key? key, required this.user, required this.isDeviceConnected})
      : super(key: key);

  @override
  State<AddMember> createState() => _AddMemberState();
}

class _AddMemberState extends State<AddMember> {
  List<Map<String, dynamic>> memberList = [];
  bool isLoading = false;
  // Map<String, dynamic>? userMap;
  String query = "";

  FirebaseFirestore _firestore = FirebaseFirestore.instance;
  FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    getCurrentUserDetail();
  }

  void getCurrentUserDetail() async {
    await _firestore
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .get()
        .then((map) {
      setState(() {
        memberList.add({
          "name": map['name'],
          "email": map['email'],
          "uid": map['uid'],
          "isAdmin": true,
          "avatar": map['avatar'],
        });
      });
    });
  }

  void addMemberToList(Map<String, dynamic> userMap) async {
    bool isAlreadyExist = false;

    for (int i = 0; i < memberList.length; i++) {
      if (memberList[i]['uid'] == userMap['uid']) {
        isAlreadyExist = true;
      }
    }
    if (!isAlreadyExist) {
      setState(() {
        memberList.add({
          'name': userMap['name'],
          'email': userMap['email'],
          'uid': userMap['uid'],
          'isAdmin': false,
          'avatar': userMap['avatar'],
        });
      });
    }
  }

  Widget onResultTap(String query) {
    return Expanded(
      child: SingleChildScrollView(
        child: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('users')
                .where('uid', isNotEqualTo: _auth.currentUser!.uid)
                .snapshots(),
            builder: (context, snapshots) {
              return (snapshots.connectionState == ConnectionState.waiting)
                  ? Center(
                      child: CircularProgressIndicator(),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: snapshots.data!.docs.length,
                      itemBuilder: (context, index) {
                        var map = snapshots.data!.docs[index].data()
                            as Map<String, dynamic>;
                        if (query.isEmpty) {
                          return Container();
                        }
                        if (map['name']
                                .toString()
                                .contains(query.toLowerCase()) ||
                            map['email']
                                .toString()
                                .contains(query.toLowerCase())) {
                          return Container(
                            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                            child: ListTile(
                              onTap: () async {
                                addMemberToList(map);
                              },
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              title: Text(
                                map['name'],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              subtitle: Text(
                                map['email'],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppTheme.gray600,
                                  fontSize: 13,
                                ),
                              ),
                              leading: AnimatedAvatar(
                                imageUrl: map['avatar'],
                                name: map['name'],
                                size: 48,
                                isOnline: map['status'] == 'Online',
                                showStatus: true,
                              ),
                              trailing: Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.add,
                                  color: AppTheme.accent,
                                  size: 20,
                                ),
                              ),
                            ),
                          );
                        }
                        return Container();
                      });
            }),
      ),
    );
  }

  void removeMember(int index) async {
    if (memberList[index]['uid'] != _auth.currentUser!.uid) {
      await _firestore
          .collection("users")
          .doc(memberList[index]['uid'])
          .update({
        'isTap': false,
      });
      setState(() {
        memberList.removeAt(index);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppTheme.primaryDark,
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.3),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppTheme.gray100),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            "Add Members",
            style: TextStyle(
              color: AppTheme.gray100,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: EdgeInsets.all(16),
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
              child: TextField(
                decoration: InputDecoration(
                  hintText: "Search members...",
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.grey.shade600,
                    size: 22,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: AppTheme.accent,
                      width: 2,
                    ),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    query = value;
                  });
                },
              ),
            ),
            SizedBox(height: 8),
            Container(
              height: 120,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: List.generate(memberList.length, (index) {
                    bool isCurrentUser = memberList[index]['uid'] == _auth.currentUser!.uid;
                    return GestureDetector(
                      onTap: () {
                        if (!isCurrentUser) {
                          removeMember(index);
                        }
                      },
                      child: Container(
                        width: 80,
                        margin: EdgeInsets.symmetric(horizontal: 6),
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                Container(
                                  height: 64,
                                  width: 64,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isCurrentUser ? Colors.blue : Colors.grey.shade300,
                                      width: 2,
                                    ),
                                    image: DecorationImage(
                                      image: NetworkImage(
                                        memberList[index]['avatar'] ?? widget.user.photoURL,
                                      ),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    height: 24,
                                    width: 24,
                                    decoration: BoxDecoration(
                                      color: isCurrentUser ? Colors.blue : AppTheme.error,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: Icon(
                                      isCurrentUser ? Icons.person : Icons.close,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                  ),
                                )
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              memberList[index]['name'],
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isCurrentUser ? FontWeight.w600 : FontWeight.normal,
                                color: AppTheme.gray800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
            Container(
              height: 5,
              // decoration: const BoxDecoration(
              //     border: Border(
              //         bottom: BorderSide(
              //           color: Colors.grey,
              //           width: 0.5,
              //         )
              //     )
              // ),
            ),
            onResultTap(query),
          ],
        ),
        floatingActionButton: memberList.length >= 2
            ? FloatingActionButton.extended(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                elevation: 4,
                icon: Icon(Icons.arrow_forward),
                label: Text(
                  'Next',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    SlideRightRoute(
                      page: CreateGroup(
                        memberList: memberList,
                        user: widget.user,
                        isDeviceConnected: widget.isDeviceConnected,
                      ),
                    ),
                  );
                },
              )
            : null,
      ),
    );
  }
}
