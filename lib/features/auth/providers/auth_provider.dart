import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../models/user_model.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/user_service.dart';

enum AuthStatus { uninitialized, authenticated, unauthenticated, authenticating }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  
  AuthStatus _status = AuthStatus.uninitialized;
  UserModel? _user;
  String? _errorMessage;

  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get errorMessage => _errorMessage;

  AuthProvider(this._authService) {
    _init();
  }

  void _init() {
    _authService.authStateChanges.listen((firebaseUser) {
      if (firebaseUser == null) {
        _status = AuthStatus.unauthenticated;
        _user = null;
      } else {
        // Just relying on auth state for basic routing. 
        // Real app would fetch full user data here.
        _status = AuthStatus.authenticated;
        // Construct a partial user to avoid null checks, proper fetching happens in login/register
        _user ??= UserModel(uid: firebaseUser.uid, email: firebaseUser.email ?? '', name: 'User');
        
        // Setup RTDB presence
        _authService.setupPresence(firebaseUser.uid);
        // Setup FCM
        _authService.setupFCM(firebaseUser.uid);
      }
      notifyListeners();
    });
  }

  Future<bool> login(String email, String password) async {
    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await _authService.login(email, password);
      if (_user != null) {
        _status = AuthStatus.authenticated;
        notifyListeners();
        return true;
      }
      _errorMessage = 'Login failed. User profile not found.';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String name, String email, String password) async {
    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await _authService.register(name, email, password);
      if (_user != null) {
        _status = AuthStatus.authenticated;
        notifyListeners();
        return true;
      }
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _authService.logout();
    } catch (e) {
      // Ignore errors during logout
    } finally {
      _status = AuthStatus.unauthenticated;
      _user = null;
      notifyListeners();
    }
  }

  Future<void> updateUserName(String newName) async {
    if (_user != null) {
      await UserService().updateUserName(_user!.uid, newName);
      _user = _user!.copyWith(name: newName);
      notifyListeners();
    }
  }

  Future<void> updateProfilePicture(File imageFile) async {
    if (_user != null) {
      final downloadUrl = await UserService().uploadProfilePicture(_user!.uid, imageFile);
      _user = _user!.copyWith(profileImageUrl: downloadUrl);
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void updateUser(UserModel updatedUser) {
    _user = updatedUser;
    notifyListeners();
  }
}
