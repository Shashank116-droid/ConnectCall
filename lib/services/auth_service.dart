import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/user_model.dart';
import 'user_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserService _userService = UserService();

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  void setupPresence(String uid) {
    _userService.setupPresence(uid);
  }

  Future<void> setupFCM(String uid) async {
    final messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      String? token = await messaging.getToken();
      if (token != null) {
        await _userService.updateFcmToken(uid, token);
      }
      
      // Listen to token refresh
      messaging.onTokenRefresh.listen((newToken) {
        _userService.updateFcmToken(uid, newToken);
      });
    }
  }

  // Login with email and password
  Future<UserModel?> login(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      User? user = result.user;
      if (user != null) {
        // Fetch user data from firestore
        UserModel? userModel = await _userService.getUser(user.uid);
        if (userModel == null) {
          // Document might have failed to create during registration, create it now
          userModel = UserModel(
            uid: user.uid,
            email: user.email ?? '',
            name: user.displayName ?? 'User',
            isOnline: true,
          );
          await _userService.saveUser(userModel);
        } else {
          // Update online status
          await _userService.updateUserStatus(user.uid, true);
        }
        return userModel;
      }
      return null;
    } catch (e) {
      throw Exception(_handleAuthException(e));
    }
  }

  // Register with email and password
  Future<UserModel?> register(String name, String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = result.user;
      if (user != null) {
        // Create user model
        UserModel newUser = UserModel(
          uid: user.uid,
          email: email,
          name: name,
          isOnline: true,
        );
        
        // Save to Firestore
        await _userService.saveUser(newUser);
        return newUser;
      }
      return null;
    } catch (e) {
      throw Exception(_handleAuthException(e));
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      if (currentUser != null) {
        final uid = currentUser!.uid;
        // Clear both Firestore status AND RTDB presence
        await Future.wait([
          _userService.updateUserStatus(uid, false),
          _userService.clearPresence(uid),
        ]);
      }
    } catch (e) {
      // Ignore firestore errors on logout to ensure user can still sign out locally
    } finally {
      await _auth.signOut();
    }
  }

  String _handleAuthException(dynamic e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
          return 'No user found for that email.';
        case 'wrong-password':
          return 'Wrong password provided.';
        case 'email-already-in-use':
          return 'The account already exists for that email.';
        default:
          return e.message ?? 'An unknown error occurred.';
      }
    }
    return e.toString();
  }
}
