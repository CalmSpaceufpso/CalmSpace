import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../repositories/user_repository.dart';

/// State management for the admin user-list screen (HU-16-T2).
///
/// Mirrors the pattern used by [PsychologistProvider]:
///  isLoading / error / users — consumed by [UserListScreen] via [Consumer].
///
/// Uses a real-time Firestore [Stream] so the list updates automatically
/// when a new user registers without requiring a manual refresh.
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

  /// Currently-active role filter. Empty string = show all.
  String _roleFilter = '';
  String get roleFilter => _roleFilter;

  /// Search query (matches against [UserProfile.fullName]).
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
      result = result
          .where((u) => u.fullName.toLowerCase().contains(q))
          .toList();
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

  // ── Commands ─────────────────────────────────────────────────────────────────

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
}
