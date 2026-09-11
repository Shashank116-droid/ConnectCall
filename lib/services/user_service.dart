import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/user_model.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;
  StreamSubscription? _presenceSubscription;
  // Create or update user in Firestore
  Future<void> saveUser(UserModel user) async {
    await _firestore.collection('users').doc(user.uid).set(user.toJson());
  }

  // Get user by UID
  Future<UserModel?> getUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return UserModel.fromJson(doc.data()!);
    }
    return null;
  }

  // Stream of all users (for contacts list)
  Stream<List<UserModel>> getUsersStream() {
    return _firestore.collection('users').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => UserModel.fromJson(doc.data())).toList();
    });
  }

  // Update user online status
  Future<void> updateUserStatus(String uid, bool isOnline) async {
    await _firestore.collection('users').doc(uid).update({
      'isOnline': isOnline,
      'lastSeen': DateTime.now().toIso8601String(),
    });
  }

  // Update FCM token
  Future<void> updateFcmToken(String uid, String token) async {
    await _firestore.collection('users').doc(uid).update({
      'fcmToken': token,
    });
  }

  // Update user name
  Future<void> updateUserName(String uid, String newName) async {
    await _firestore.collection('users').doc(uid).update({
      'name': newName,
    });
  }

  // Upload profile picture and update Firestore
  Future<String> uploadProfilePicture(String uid, File imageFile) async {
    final storageRef = FirebaseStorage.instance.ref().child('profile_pictures').child('$uid.jpg');
    
    // Upload file
    final uploadTask = await storageRef.putFile(imageFile);
    final downloadUrl = await uploadTask.ref.getDownloadURL();
    
    // Update user document
    await _firestore.collection('users').doc(uid).update({
      'profileImageUrl': downloadUrl,
    });
    
    return downloadUrl;
  }

  // Block a user
  Future<void> blockUser(String currentUid, String blockedUid) async {
    await _firestore.collection('users').doc(currentUid).update({
      'blockedUsers': FieldValue.arrayUnion([blockedUid]),
    });
  }

  // Unblock a user
  Future<void> unblockUser(String currentUid, String blockedUid) async {
    await _firestore.collection('users').doc(currentUid).update({
      'blockedUsers': FieldValue.arrayRemove([blockedUid]),
    });
  }

  // ---------------------------------------------------------------------------
  // Realtime Database Presence
  // ---------------------------------------------------------------------------

  void setupPresence(String uid) {
    // Cancel any previous presence listener (e.g., from a different account)
    _presenceSubscription?.cancel();

    final connectedRef = _rtdb.ref('.info/connected');
    final userStatusRef = _rtdb.ref('status/$uid');

    _presenceSubscription = connectedRef.onValue.listen((event) {
      final isConnected = event.snapshot.value as bool? ?? false;
      if (isConnected) {
        userStatusRef.onDisconnect().set({
          'isOnline': false,
          'lastSeen': ServerValue.timestamp,
        }).then((_) {
          userStatusRef.set({
            'isOnline': true,
            'lastSeen': ServerValue.timestamp,
          });
        });
      }
    });
  }

  /// Explicitly set user offline in RTDB.
  /// Must be called on logout because onDisconnect only fires
  /// when the app physically disconnects, not on a logical sign-out.
  Future<void> clearPresence(String uid) async {
    // Stop the listener so it doesn't re-set online status
    await _presenceSubscription?.cancel();
    _presenceSubscription = null;

    final userStatusRef = _rtdb.ref('status/$uid');
    // Cancel the onDisconnect hook for this user
    await userStatusRef.onDisconnect().cancel();
    // Explicitly set offline
    await userStatusRef.set({
      'isOnline': false,
      'lastSeen': ServerValue.timestamp,
    });
  }

  Stream<Map<String, bool>> getPresenceStream() {
    return _rtdb.ref('status').onValue.map((event) {
      final Map<String, bool> presenceMap = {};
      final data = event.snapshot.value;
      if (data != null && data is Map) {
        data.forEach((key, value) {
          if (value is Map && value['isOnline'] != null) {
            presenceMap[key.toString()] = value['isOnline'] as bool;
          }
        });
      }
      return presenceMap;
    });
  }
}
