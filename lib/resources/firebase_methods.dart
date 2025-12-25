import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/user_model.dart';

class FirebaseMethods {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Future<FirebaseUser> getCurrentUser() async {
  //   FirebaseUser currentUser;
  //   Firebas
  //   currentUser = await _auth.currentUser;
  //   return currentUser;
  //   return _auth.currentUser;
  // }

  Future<Userr> getUserDetails() async {
    User? currentUser = _auth.currentUser;

    final documentSnapshot =
        await _firestore.collection('users').doc(currentUser!.uid).get();

    if (kDebugMode) { debugPrint('${documentSnapshot.data()}'); }

    return Userr.fromMap(documentSnapshot.data()!);
  }
}
