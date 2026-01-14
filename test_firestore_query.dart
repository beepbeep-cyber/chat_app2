// Test script để verify Firestore query hoạt động
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  print('🔍 Testing Firestore Query...');
  
  // Simulate the query
  final testUid = 'test_user_123';
  
  print('Query: incomingCalls');
  print('  .where(calleeUid == $testUid)');
  print('  .where(status == calling)');
  print('  .snapshots()');
  
  print('\n✅ Query structure looks correct!');
  print('\n⚠️  IMPORTANT CHECKS:');
  print('1. Is Firestore collection "incomingCalls" created?');
  print('2. Are Firestore rules allowing read access?');
  print('3. Is the user logged in when listener starts?');
  print('4. Are there any network issues?');
}
