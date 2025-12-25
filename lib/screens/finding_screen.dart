import 'package:my_porject/configs/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:my_porject/screens/chat_screen.dart';
import 'package:my_porject/resources/methods.dart';
import 'package:my_porject/widgets/page_transitions.dart';
import 'package:my_porject/widgets/animated_avatar.dart';

class CustomSearch extends SearchDelegate {
  User user;
  bool isDeviceConnected;
  CustomSearch({required this.user, required this.isDeviceConnected})
      : super(
          searchFieldLabel: 'Search users...',
          searchFieldStyle: TextStyle(
            color: AppTheme.gray100,
            fontSize: 16,
          ),
        );

  FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  ThemeData appBarTheme(BuildContext context) {
    return ThemeData(
      appBarTheme: AppBarTheme(
        backgroundColor: AppTheme.primaryDark,
        elevation: 2,
        iconTheme: IconThemeData(color: AppTheme.gray100),
        titleTextStyle: TextStyle(
          color: AppTheme.gray100,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: AppTheme.gray400),
        border: InputBorder.none,
      ),
      scaffoldBackgroundColor: AppTheme.gray50,
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        onPressed: () {
          query = '';
        },
        icon: Icon(Icons.clear),
      )
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () {
        close(context, null);
      },
      icon: Icon(Icons.arrow_back),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return SingleChildScrollView(
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
                    if (map['name'].toString().contains(query.toLowerCase()) ||
                        map['email'].toString().contains(query.toLowerCase())) {
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
                            String roomId = ChatRoomId()
                                .chatRoomId(user.displayName, map['name']);
                            Navigator.push(
                                context,
                                SlideRightRoute(
                                    page: ChatScreen(
                                          chatRoomId: roomId,
                                          userMap: map,
                                          user: user,
                                          isDeviceConnected: isDeviceConnected,
                                        )));
                          },
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                          trailing: Icon(
                            Icons.chat_bubble_outline,
                            color: AppTheme.accent,
                            size: 20,
                          ),
                        ),
                      );
                    }
                    return Container();
                  });
        },
      ),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return SingleChildScrollView(
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
                    if (map['name'].toString().contains(query.toLowerCase()) ||
                        map['email'].toString().contains(query.toLowerCase())) {
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
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                          trailing: Icon(
                            Icons.chat_bubble_outline,
                            color: AppTheme.accent,
                            size: 20,
                          ),
                          onTap: () async {
                            String roomId = ChatRoomId().chatRoomId(
                                _auth.currentUser!.displayName, map['name']);
                            Navigator.push(
                                context,
                                SlideRightRoute(
                                    page: ChatScreen(
                                          chatRoomId: roomId,
                                          userMap: map,
                                          user: user,
                                          isDeviceConnected: isDeviceConnected,
                                        )));
                          },
                        ),
                      );
                    }
                    return Container();
                  });
        },
      ),
    );
  }
}
