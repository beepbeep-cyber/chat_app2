import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service to manage user online/offline presence
/// Automatically sets user offline when app is killed or loses connection
class PresenceService {
  static final PresenceService _instance = PresenceService._internal();
  factory PresenceService() => _instance;
  PresenceService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Initialize presence system
  /// Sets up automatic offline detection when app is killed
  Future<void> initialize() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Get user's status lock preference
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final isStatusLocked = userDoc.data()?['isStatusLocked'] ?? false;

      // Don't change status if user has locked it to offline
      if (isStatusLocked) return;

      // Set user online when app starts
      await _setOnline();

      if (kDebugMode) {
        debugPrint('✅ [Presence] User set to Online');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [Presence] Error initializing: $e');
      }
    }
  }

  /// Set user online
  Future<void> _setOnline() async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).update({
      'status': 'Online',
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  /// Set user offline
  /// Called when app goes to background or is killed
  Future<void> setOffline() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Check if status is locked
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final isStatusLocked = userDoc.data()?['isStatusLocked'] ?? false;

      // Always update lastSeen, but only change status if not locked
      final Map<String, dynamic> updates = {
        'lastSeen': FieldValue.serverTimestamp(),
      };

      if (!isStatusLocked) {
        updates['status'] = 'Offline';
      }

      await _firestore.collection('users').doc(user.uid).update(updates);

      // Update status in contacts' chatHistory
      if (!isStatusLocked) {
        await _updateContactsStatus('Offline');
      }

      if (kDebugMode) {
        debugPrint('✅ [Presence] User set to Offline');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [Presence] Error setting offline: $e');
      }
    }
  }

  /// Update status in all contacts' chatHistory
  Future<void> _updateContactsStatus(String status) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final chatHistorySnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('chatHistory')
          .where('datatype', isEqualTo: 'p2p')
          .get();

      if (chatHistorySnapshot.docs.isEmpty) return;

      WriteBatch batch = _firestore.batch();
      int operationCount = 0;

      for (final doc in chatHistorySnapshot.docs) {
        final contactUid = doc.data()['uid'];
        if (contactUid != null) {
          final ref = _firestore
              .collection('users')
              .doc(contactUid)
              .collection('chatHistory')
              .doc(user.uid);

          batch.update(ref, {'status': status});
          operationCount++;

          // Firestore batch limit is 500 operations
          if (operationCount >= 500) {
            await batch.commit();
            batch = _firestore.batch();
            operationCount = 0;
          }
        }
      }

      if (operationCount > 0) {
        await batch.commit();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [Presence] Error updating contacts: $e');
      }
    }
  }

  /// Cleanup when user logs out
  Future<void> cleanup() async {
    await setOffline();
  }
}
