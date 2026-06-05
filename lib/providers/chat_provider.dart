import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message_model.dart';
import '../repositories/chat_repository.dart';

/// State management for a single chat conversation.
///
/// Responsibilities:
///  • Subscribes to the real-time message stream for [appointmentId].
///  • Handles optimistic UI updates for sent messages (shows the message
///    immediately before Firestore confirms it).
///  • Exposes [isOffline] when a send fails due to connectivity issues.
class ChatProvider extends ChangeNotifier {
  final ChatRepository _repo;
  final String appointmentId;
  final String currentUserId;
  final String currentUserName;

  ChatProvider({
    ChatRepository? repository,
    required this.appointmentId,
    required this.currentUserId,
    required this.currentUserName,
  }) : _repo = repository ?? ChatRepository() {
    _subscribeToMessages();
  }

  // ── State ────────────────────────────────────────────────────────────────────

  List<MessageModel> _messages = [];
  List<MessageModel> get messages => List.unmodifiable(_messages);

  bool _isSending = false;
  bool get isSending => _isSending;

  bool _isOffline = false;
  bool get isOffline => _isOffline;

  String? _error;
  String? get error => _error;

  StreamSubscription<List<MessageModel>>? _sub;

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  void _subscribeToMessages() {
    _sub = _repo.messagesStream(appointmentId).listen(
      (msgs) {
        _messages = msgs;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
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

  /// Sends [text] as a new message.
  ///
  /// An optimistic copy is inserted locally first; on failure the copy is
  /// removed and [isOffline] is set to true.
  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isSending) return;

    final optimistic = MessageModel(
      id: 'pending_${DateTime.now().millisecondsSinceEpoch}',
      senderId: currentUserId,
      senderName: currentUserName,
      text: trimmed,
      sentAt: DateTime.now(),
      isPending: true,
    );

    // Optimistic insert
    _messages = [..._messages, optimistic];
    _isSending = true;
    _isOffline = false;
    notifyListeners();

    try {
      final message = MessageModel(
        id: '',
        senderId: currentUserId,
        senderName: currentUserName,
        text: trimmed,
        sentAt: DateTime.now(),
      );
      await _repo.sendMessage(appointmentId: appointmentId, message: message);
      // The stream will deliver the confirmed message and replace the optimistic one.
    } catch (_) {
      // Remove optimistic message on error and flag offline state.
      _messages = _messages.where((m) => m.id != optimistic.id).toList();
      _isOffline = true;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  void clearOfflineFlag() {
    _isOffline = false;
    notifyListeners();
  }

  // ── Factory ──────────────────────────────────────────────────────────────────

  /// Convenience factory that reads the current Firebase user automatically.
  static ChatProvider forCurrentUser({
    required String appointmentId,
    required String displayName,
  }) {
    final user = FirebaseAuth.instance.currentUser!;
    return ChatProvider(
      appointmentId: appointmentId,
      currentUserId: user.uid,
      currentUserName: displayName,
    );
  }
}
