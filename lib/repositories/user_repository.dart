import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';

/// Firestore operations for the admin user-management feature (HU-16).
///
/// Reads from the top-level [users] collection and maps each document
/// safely to [UserProfile] via the existing [UserProfile.fromMap] factory,
/// which already handles every null / missing field.
class UserRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Queries ─────────────────────────────────────────────────────────────────

  /// Fetches all registered users ordered by display name.
  ///
  /// Returns an empty list on any error — callers should propagate errors
  /// through the provider's [error] field instead of letting them crash.
  Future<List<UserProfile>> getAllUsers() async {
    final snap = await _db
        .collection('users')
        .orderBy('name')
        .get();

    return snap.docs.map((doc) {
      try {
        return UserProfile.fromMap(doc.id, doc.data());
      } catch (_) {
        // Defensive: if one document is malformed, skip it gracefully.
        return null;
      }
    }).whereType<UserProfile>().toList();
  }

  /// Real-time stream of all registered users (ordered by name).
  ///
  /// Powers the live list in [UserListScreen].
  Stream<List<UserProfile>> usersStream() {
    return _db
        .collection('users')
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              try {
                return UserProfile.fromMap(doc.id, doc.data());
              } catch (_) {
                return null;
              }
            }).whereType<UserProfile>().toList());
  }

  /// Verifies whether [uid] has the 'Admin' role in Firestore.
  /// Used as the T3 guard before rendering the admin screen.
  Future<bool> isAdmin(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return false;
      final role = doc.data()?['role'] as String? ?? '';
      return role == 'Admin';
    } catch (_) {
      return false;
    }
  }
}
