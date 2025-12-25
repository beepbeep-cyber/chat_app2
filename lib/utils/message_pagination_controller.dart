import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Controller for paginated message loading
/// Loads messages in chunks to improve performance
class MessagePaginationController extends ChangeNotifier {
  static const int PAGE_SIZE = 50;
  
  final String chatRoomId;
  final FirebaseFirestore _firestore;
  
  List<QueryDocumentSnapshot> _messages = [];
  DocumentSnapshot? _lastDocument;
  bool _isLoading = false;
  bool _hasMore = true;
  
  List<QueryDocumentSnapshot> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  
  MessagePaginationController({
    required this.chatRoomId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;
  
  /// Load initial batch of messages
  Future<void> loadInitialMessages() async {
    if (_isLoading) return;
    
    _isLoading = true;
    notifyListeners();
    
    try {
      final query = await _firestore
        .collection('chatroom')
        .doc(chatRoomId)
        .collection('chats')
        .orderBy('timeStamp', descending: true)
        .limit(PAGE_SIZE)
        .get();
      
      _messages = query.docs;
      _lastDocument = query.docs.isNotEmpty ? query.docs.last : null;
      _hasMore = query.docs.length == PAGE_SIZE;
      
      if (kDebugMode) {
        if (kDebugMode) { debugPrint('✅ Loaded ${_messages.length} messages, hasMore: $_hasMore'); }
      }
    } catch (e) {
      if (kDebugMode) {
        if (kDebugMode) { debugPrint('❌ Error loading messages: $e'); }
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Load next batch of messages (pagination)
  Future<void> loadMoreMessages() async {
    if (_isLoading || !_hasMore || _lastDocument == null) return;
    
    _isLoading = true;
    notifyListeners();
    
    try {
      final query = await _firestore
        .collection('chatroom')
        .doc(chatRoomId)
        .collection('chats')
        .orderBy('timeStamp', descending: true)
        .startAfterDocument(_lastDocument!)
        .limit(PAGE_SIZE)
        .get();
      
      _messages.addAll(query.docs);
      _lastDocument = query.docs.isNotEmpty ? query.docs.last : null;
      _hasMore = query.docs.length == PAGE_SIZE;
      
      if (kDebugMode) {
        if (kDebugMode) { debugPrint('✅ Loaded ${query.docs.length} more messages, total: ${_messages.length}, hasMore: $_hasMore'); }
      }
    } catch (e) {
      if (kDebugMode) {
        if (kDebugMode) { debugPrint('❌ Error loading more messages: $e'); }
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Add a new message to the beginning of the list
  void addNewMessage(QueryDocumentSnapshot message) {
    // Check if message already exists (prevent duplicates)
    if (_messages.isEmpty || _messages.first.id != message.id) {
      _messages.insert(0, message);
      notifyListeners();
    }
  }
  
  /// Update an existing message
  void updateMessage(String messageId, Map<String, dynamic> data) {
    final index = _messages.indexWhere((msg) => msg.id == messageId);
    if (index != -1) {
      // Create updated document snapshot
      // Note: This is a simplified version, actual implementation may vary
      notifyListeners();
    }
  }
  
  /// Remove a message
  void removeMessage(String messageId) {
    _messages.removeWhere((msg) => msg.id == messageId);
    notifyListeners();
  }
  
  /// Clear all messages and reset controller
  void clear() {
    _messages.clear();
    _lastDocument = null;
    _hasMore = true;
    _isLoading = false;
    notifyListeners();
  }
  
  /// Refresh messages (pull to refresh)
  Future<void> refresh() async {
    clear();
    await loadInitialMessages();
  }
}
