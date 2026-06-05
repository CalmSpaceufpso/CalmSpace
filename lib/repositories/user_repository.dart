import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';

/// Firestore operations for the admin user-management feature (HU-16 / HU-19).
///
/// Reads from the top-level [users] collection and maps each document
/// safely to [UserProfile] via the existing [UserProfile.fromMap] factory,
/// which already handles every null / missing field.
class UserRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Queries ─────────────────────────────────────────────────────────────────

  /// Fetches all registered users ordered by display name.
  Future<List<UserProfile>> getAllUsers() async {
    final snap = await _db.collection('users').orderBy('name').get();
    return snap.docs.map((doc) {
      try {
        return UserProfile.fromMap(doc.id, doc.data());
      } catch (_) {
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

  // ── HU-19: Moderation actions ────────────────────────────────────────────────

  /// Sets the target user's [status] to 'baneado' and writes an audit log.
  ///
  /// Uses a [WriteBatch] — status update and log entry are committed
  /// atomically: either both succeed or both fail.
  Future<void> banUser({
    required String targetUserId,
    required String adminId,
  }) async {
    final batch = _db.batch();
    batch.update(
      _db.collection('users').doc(targetUserId),
      {'status': 'baneado'},
    );
    _addLogToBatch(
      batch: batch,
      adminId: adminId,
      targetUserId: targetUserId,
      actionType: 'ban',
    );
    await batch.commit();
  }

  /// Permanently deletes the target user document and writes an audit log.
  ///
  /// Note: Auth record deletion requires Firebase Admin SDK (Cloud Function).
  Future<void> deleteUser({
    required String targetUserId,
    required String adminId,
  }) async {
    final batch = _db.batch();
    batch.delete(_db.collection('users').doc(targetUserId));
    _addLogToBatch(
      batch: batch,
      adminId: adminId,
      targetUserId: targetUserId,
      actionType: 'delete',
    );
    await batch.commit();
  }

  // ── Private helpers ──────────────────────────────────────────────────────────

  void _addLogToBatch({
    required WriteBatch batch,
    required String adminId,
    required String targetUserId,
    required String actionType,
  }) {
    final logRef = _db.collection('admin_logs').doc();
    batch.set(logRef, {
      'adminId':      adminId,
      'targetUserId': targetUserId,
      'actionType':   actionType,
      'timestamp':    FieldValue.serverTimestamp(),
    });
  }
}
