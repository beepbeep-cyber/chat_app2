import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// In-memory cache service for better performance
/// Caches frequently accessed data to reduce Firestore reads
class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  // User cache with expiration
  final Map<String, _CacheEntry<Map<String, dynamic>>> _userCache = {};
  
  // Message cache for chat rooms
  final Map<String, List<Map<String, dynamic>>> _messageCache = {};
  
  // Chat history cache
  final Map<String, List<Map<String, dynamic>>> _chatHistoryCache = {};

  // Cache duration
  static const Duration _userCacheDuration = Duration(minutes: 5);
  static const Duration _messageCacheDuration = Duration(minutes: 2);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get user data with caching
  Future<Map<String, dynamic>?> getUser(String userId) async {
    // Check cache first
    final cached = _userCache[userId];
    if (cached != null && !cached.isExpired) {
      if (kDebugMode) print('📦 [Cache] User cache hit: $userId');
      return cached.data;
    }

    // Fetch from Firestore
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data()!;
        _userCache[userId] = _CacheEntry(data, _userCacheDuration);
        if (kDebugMode) print('📦 [Cache] User cached: $userId');
        return data;
      }
    } catch (e) {
      if (kDebugMode) print('❌ [Cache] Error fetching user: $e');
    }
    return null;
  }

  /// Get multiple users with caching
  Future<Map<String, Map<String, dynamic>>> getUsers(List<String> userIds) async {
    final result = <String, Map<String, dynamic>>{};
    final uncachedIds = <String>[];

    // Check cache for each user
    for (final userId in userIds) {
      final cached = _userCache[userId];
      if (cached != null && !cached.isExpired) {
        result[userId] = cached.data;
      } else {
        uncachedIds.add(userId);
      }
    }

    // Fetch uncached users in batch
    if (uncachedIds.isNotEmpty) {
      try {
        // Firestore 'in' query limit is 30
        for (var i = 0; i < uncachedIds.length; i += 30) {
          final batch = uncachedIds.skip(i).take(30).toList();
          final snapshot = await _firestore
              .collection('users')
              .where(FieldPath.documentId, whereIn: batch)
              .get();

          for (final doc in snapshot.docs) {
            final data = doc.data();
            result[doc.id] = data;
            _userCache[doc.id] = _CacheEntry(data, _userCacheDuration);
          }
        }
      } catch (e) {
        if (kDebugMode) print('❌ [Cache] Error batch fetching users: $e');
      }
    }

    return result;
  }

  /// Invalidate user cache
  void invalidateUser(String userId) {
    _userCache.remove(userId);
    if (kDebugMode) print('📦 [Cache] User invalidated: $userId');
  }

  /// Get cached messages for a chat room
  List<Map<String, dynamic>>? getCachedMessages(String chatRoomId) {
    return _messageCache[chatRoomId];
  }

  /// Cache messages for a chat room
  void cacheMessages(String chatRoomId, List<Map<String, dynamic>> messages) {
    _messageCache[chatRoomId] = messages;
    if (kDebugMode) print('📦 [Cache] Messages cached for: $chatRoomId (${messages.length} items)');
  }

  /// Add message to cache
  void addMessageToCache(String chatRoomId, Map<String, dynamic> message) {
    if (_messageCache.containsKey(chatRoomId)) {
      _messageCache[chatRoomId]!.add(message);
    }
  }

  /// Invalidate message cache
  void invalidateMessages(String chatRoomId) {
    _messageCache.remove(chatRoomId);
    if (kDebugMode) print('📦 [Cache] Messages invalidated for: $chatRoomId');
  }

  /// Cache chat history
  void cacheChatHistory(String oderId, List<Map<String, dynamic>> history) {
    _chatHistoryCache[oderId] = history;
  }

  /// Get cached chat history
  List<Map<String, dynamic>>? getCachedChatHistory(String userId) {
    return _chatHistoryCache[userId];
  }

  /// Clear all caches
  void clearAll() {
    _userCache.clear();
    _messageCache.clear();
    _chatHistoryCache.clear();
    if (kDebugMode) print('📦 [Cache] All caches cleared');
  }

  /// Get cache stats (for debugging)
  Map<String, int> getCacheStats() {
    return {
      'users': _userCache.length,
      'chatRooms': _messageCache.length,
      'chatHistory': _chatHistoryCache.length,
    };
  }
}

/// Cache entry with expiration
class _CacheEntry<T> {
  final T data;
  final DateTime expireAt;

  _CacheEntry(this.data, Duration duration)
      : expireAt = DateTime.now().add(duration);

  bool get isExpired => DateTime.now().isAfter(expireAt);
}

/// Extension to make cache service easily accessible
extension CacheServiceExtension on CacheService {
  /// Prefetch common data for better UX
  Future<void> prefetchUserData(String currentUserId) async {
    try {
      // Prefetch current user
      await getUser(currentUserId);
      
      // Prefetch chat history users
      final chatHistory = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('chatHistory')
          .limit(20)
          .get();
      
      final userIds = chatHistory.docs
          .map((doc) => doc.data()['uid'] as String?)
          .whereType<String>()
          .toList();
      
      if (userIds.isNotEmpty) {
        await getUsers(userIds);
      }
      
      if (kDebugMode) print('📦 [Cache] Prefetch complete');
    } catch (e) {
      if (kDebugMode) print('❌ [Cache] Prefetch error: $e');
    }
  }
}
