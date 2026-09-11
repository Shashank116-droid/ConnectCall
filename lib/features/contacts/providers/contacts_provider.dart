import 'package:flutter/material.dart';
import '../../../../models/user_model.dart';
import '../../../../services/user_service.dart';

class ContactsProvider extends ChangeNotifier {
  final UserService _userService;
  
  List<UserModel> _allUsers = [];
  List<UserModel> _filteredUsers = [];
  Map<String, bool> _presenceMap = {};
  String _searchQuery = '';
  bool _isLoading = true;

  List<UserModel> get users => _filteredUsers;
  bool isUserOnline(String uid) => _presenceMap[uid] ?? false;
  bool get isLoading => _isLoading;

  ContactsProvider(this._userService) {
    _init();
  }

  void _init() {
    _userService.getUsersStream().listen((users) {
      _allUsers = users;
      _applySearch();
      _isLoading = false;
      notifyListeners();
    });

    _userService.getPresenceStream().listen((presenceData) {
      _presenceMap = presenceData;
      notifyListeners();
    });
  }

  void search(String query) {
    _searchQuery = query;
    _applySearch();
    notifyListeners();
  }

  void _applySearch() {
    if (_searchQuery.isEmpty) {
      _filteredUsers = List.from(_allUsers);
    } else {
      _filteredUsers = _allUsers
          .where((user) =>
              user.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              user.email.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }
  }

  Future<void> toggleBlockUser(String currentUid, String targetUid, bool isCurrentlyBlocked) async {
    try {
      if (isCurrentlyBlocked) {
        await _userService.unblockUser(currentUid, targetUid);
      } else {
        await _userService.blockUser(currentUid, targetUid);
      }
    } catch (e) {
      debugPrint('Error toggling block status: $e');
      rethrow;
    }
  }
}
