import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message_model.dart';

/// All Firestore operations for the chat feature (HU-12).
///
/// Data structure:
///   appointments/{appointmentId}          ← existing document
///     /messages/{messageId}               ← sub-collection (new)
///
/// The appointment document is also updated with [lastMessage] and
/// [lastMessageAt] fields so that the conversation list can show a preview.
class ChatRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Helpers ─────────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _messagesRef(String appointmentId) =>
      _db.collection('appointments').doc(appointmentId).collection('messages');

  DocumentReference<Map<String, dynamic>> _appointmentRef(String appointmentId) =>
      _db.collection('appointments').doc(appointmentId);

  // ── Queries ─────────────────────────────────────────────────────────────────

  /// Returns a real-time stream of all messages in a conversation,
  /// ordered chronologically (oldest first).
  Stream<List<MessageModel>> messagesStream(String appointmentId) {
    return _messagesRef(appointmentId)
        .orderBy('sentAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => MessageModel.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  /// Returns a stream of all active (scheduled) appointments that belong to
  /// [userId] — used to build the conversation list.
  Stream<QuerySnapshot<Map<String, dynamic>>> conversationsStream({
    required String userId,
    required bool isPsychologist,
  }) {
    return _db
        .collection('appointments')
        .where(
          isPsychologist ? 'psychologistId' : 'patientId',
          isEqualTo: userId,
        )
        .where('status', isEqualTo: 'scheduled')
        .snapshots();
  }

  // ── Commands ─────────────────────────────────────────────────────────────────

  /// Sends a message and updates the conversation preview fields on the
  /// appointment document in a single batch write.
  Future<void> sendMessage({
    required String appointmentId,
    required MessageModel message,
  }) async {
    final batch = _db.batch();

    // Add the message to the sub-collection.
    final msgRef = _messagesRef(appointmentId).doc();
    batch.set(msgRef, message.toMap());

    // Update the conversation preview on the appointment document.
    batch.update(_appointmentRef(appointmentId), {
      'lastMessage': message.text,
      'lastMessageAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Returns [true] if there is at least one scheduled appointment between
  /// [patientId] and [psychologistId].  Used to gate chat access.
  Future<bool> hasActiveAppointment({
    required String patientId,
    required String psychologistId,
  }) async {
    final snap = await _db
        .collection('appointments')
        .where('patientId', isEqualTo: patientId)
        .where('psychologistId', isEqualTo: psychologistId)
        .where('status', isEqualTo: 'scheduled')
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }
}
