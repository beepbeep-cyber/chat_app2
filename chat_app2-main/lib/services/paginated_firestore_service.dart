import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service for paginated Firestore queries to improve performance
class PaginatedFirestoreService {
  static final PaginatedFirestoreService _instance = PaginatedFirestoreService._internal();
  factory PaginatedFirestoreService() => _instance;
  PaginatedFirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Default page size
  static const int defaultPageSize = 20;
  static const int maxMessagePageSize = 50;

  /// Get paginated messages for a chat room
  /// Returns a stream that only fetches the latest messages
  Stream<QuerySnapshot> getPaginatedMessages({
    required String chatRoomId,
    required String collection, // 'chatroom' or 'groups'
    int limit = maxMessagePageSize,
  }) {
    return _firestore
        .collection(collection)
        .doc(chatRoomId)
        .collection('chats')
        .orderBy('timeStamp', descending: true)
        .limit(limit)
        .snapshots();
  }

  /// Load more messages (pagination)
  Future<List<QueryDocumentSnapshot>> loadMoreMessages({
    required String chatRoomId,
    required String collection,
    required DocumentSnapshot lastDocument,
    int limit = maxMessagePageSize,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(collection)
          .doc(chatRoomId)
          .collection('chats')
          .orderBy('timeStamp', descending: true)
          .startAfterDocument(lastDocument)
          .limit(limit)
          .get();

      return snapshot.docs;
    } catch (e) {
      if (kDebugMode) print('Error loading more messages: $e');
      return [];
    }
  }

  /// Get paginated chat history
  Stream<QuerySnapshot> getPaginatedChatHistory({
    required String userId,
    int limit = defaultPageSize,
  }) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('chatHistory')
        .orderBy('timeStamp', descending: true)
        .limit(limit)
        .snapshots();
  }

  /// Get paginated users for search
  Future<List<QueryDocumentSnapshot>> searchUsers({
    required String query,
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query<Map<String, dynamic>> queryRef = _firestore
          .collection('users')
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThan: '${query}z')
          .limit(limit);

      if (startAfter != null) {
        queryRef = queryRef.startAfterDocument(startAfter);
      }

      final snapshot = await queryRef.get();
      return snapshot.docs;
    } catch (e) {
      if (kDebugMode) print('Error searching users: $e');
      return [];
    }
  }

  /// Get paginated groups
  Stream<QuerySnapshot> getPaginatedGroups({
    required String userId,
    int limit = defaultPageSize,
  }) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('groups')
        .orderBy('time', descending: true)
        .limit(limit)
        .snapshots();
  }
}

/// Controller for managing paginated list state
class PaginationController<T> {
  final List<T> _items = [];
  bool _hasMore = true;
  bool _isLoading = false;
  DocumentSnapshot? _lastDocument;

  List<T> get items => List.unmodifiable(_items);
  bool get hasMore => _hasMore;
  bool get isLoading => _isLoading;

  void setItems(List<T> newItems, {DocumentSnapshot? lastDoc}) {
    _items.clear();
    _items.addAll(newItems);
    _lastDocument = lastDoc;
    _hasMore = newItems.isNotEmpty;
  }

  void addItems(List<T> moreItems, {DocumentSnapshot? lastDoc}) {
    _items.addAll(moreItems);
    _lastDocument = lastDoc;
    _hasMore = moreItems.isNotEmpty;
  }

  void setLoading(bool loading) {
    _isLoading = loading;
  }

  void reset() {
    _items.clear();
    _hasMore = true;
    _isLoading = false;
    _lastDocument = null;
  }

  DocumentSnapshot? get lastDocument => _lastDocument;
}

// Note: PaginationMixin removed - use PaginationController directly with ScrollController in widgets
// Example usage:
// final _scrollController = ScrollController();
// final _paginationController = PaginationController<MyDataType>();
// 
// void initState() {
//   _scrollController.addListener(() {
//     if (_scrollController.position.pixels >= 
//         _scrollController.position.maxScrollExtent * 0.8) {
//       _loadMore();
//     }
//   });
// }
