import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../repositories/user_repository.dart';

/// State management for the admin user-list screen (HU-16 / HU-19).
class UserListProvider extends ChangeNotifier {
  final UserRepository _repo;

  UserListProvider({UserRepository? repository})
      : _repo = repository ?? UserRepository() {
    _subscribe();
  }

  // ── State ────────────────────────────────────────────────────────────────────

  List<UserProfile> _users = [];
  List<UserProfile> get users => List.unmodifiable(_users);

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  /// UIDs currently being acted on (ban or delete in progress).
  /// Used to show a per-card loading indicator and disable the menu.
  final Set<String> _actingOn = {};
  bool isActingOn(String uid) => _actingOn.contains(uid);

  String _roleFilter = '';
  String get roleFilter => _roleFilter;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  StreamSubscription<List<UserProfile>>? _sub;

  // ── Filtered view ────────────────────────────────────────────────────────────

  List<UserProfile> get filteredUsers {
    var result = _users;
    if (_roleFilter.isNotEmpty) {
      result = result.where((u) => u.role == _roleFilter).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((u) => u.fullName.toLowerCase().contains(q)).toList();
    }
    return result;
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  void _subscribe() {
    _sub = _repo.usersStream().listen(
      (list) {
        _users = list;
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // ── Filters ──────────────────────────────────────────────────────────────────

  void setRoleFilter(String role) {
    _roleFilter = role;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void clearFilters() {
    _roleFilter = '';
    _searchQuery = '';
    notifyListeners();
  }

  // ── HU-19: Moderation actions ─────────────────────────────────────────────────

  /// Bans [targetUserId] and logs the action under [adminId].
  /// Returns `true` on success, `false` on failure.
  Future<bool> banUser({
    required String targetUserId,
    required String adminId,
  }) async {
    _actingOn.add(targetUserId);
    notifyListeners();
    try {
      await _repo.banUser(targetUserId: targetUserId, adminId: adminId);
      return true;
    } catch (_) {
      return false;
    } finally {
      _actingOn.remove(targetUserId);
      notifyListeners();
    }
  }

  /// Deletes [targetUserId] and logs the action under [adminId].
  /// Returns `true` on success, `false` on failure.
  Future<bool> deleteUser({
    required String targetUserId,
    required String adminId,
  }) async {
    _actingOn.add(targetUserId);
    notifyListeners();
    try {
      await _repo.deleteUser(targetUserId: targetUserId, adminId: adminId);
      return true;
    } catch (_) {
      return false;
    } finally {
      _actingOn.remove(targetUserId);
      notifyListeners();
    }
  }
}
