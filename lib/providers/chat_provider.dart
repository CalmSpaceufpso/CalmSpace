import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message_model.dart';
import '../repositories/chat_repository.dart';

/// State management for a single chat conversation (HU-12).
///
/// Two-list architecture:
///  • [_streamMessages]  — confirmed messages delivered by the Firestore stream.
///  • [_localMessages]   — optimistic (pending) or failed messages that have
///                          not yet been confirmed by Firestore.
///
/// The merged [messages] getter removes any local message whose text+sender
/// already appears in [_streamMessages] (deduplication after Firestore confirms).
///
/// On send failure the local copy stays visible as [isFailed = true] so the
/// user can retry — it is never silently discarded (T4).
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

  // ── Internal state ───────────────────────────────────────────────────────────

  /// Confirmed messages from Firestore (real-time stream).
  List<MessageModel> _streamMessages = [];

  /// Local-only messages: pending (being sent) or failed (send error).
  final List<MessageModel> _localMessages = [];

  bool _isOffline = false;
  String? _error;

  // ── Public getters ───────────────────────────────────────────────────────────

  /// Merged, chronologically-sorted list.
  ///
  /// Local messages that are already confirmed by Firestore (matched by
  /// senderId + text within a 60-second window) are excluded to avoid
  /// duplicates (T2 deduplication fix).
  List<MessageModel> get messages {
    final confirmed = _streamMessages;

    final dedupedLocals = _localMessages.where((local) {
      // Keep failed messages always visible (T4).
      if (local.isFailed) return true;
      // Drop pending ones that Firestore has already confirmed.
      return !confirmed.any((c) =>
          c.senderId == local.senderId &&
          c.text == local.text &&
          c.sentAt.difference(local.sentAt).abs().inSeconds < 60);
    }).toList();

    return [...confirmed, ...dedupedLocals]
      ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
  }

  bool get isOffline => _isOffline;
  String? get error => _error;

  bool get isSending => _localMessages.any((m) => m.isPending && !m.isFailed);

  StreamSubscription<List<MessageModel>>? _sub;

  // ── Real-time subscription (T2) ──────────────────────────────────────────────

  void _subscribeToMessages() {
    _sub = _repo.messagesStream(appointmentId).listen(
      (msgs) {
        _streamMessages = msgs;
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

  // ── Send (T4: optimistic + failure persistence) ───────────────────────────────

  /// Sends [text] as a message.
  ///
  /// 1. Immediately inserts a pending bubble in the UI (optimistic).
  /// 2. On success: Firestore stream will deliver the real message; the
  ///    deduplication logic in [messages] will drop the pending copy.
  /// 3. On failure: the pending copy is marked [isFailed = true] and stays
  ///    visible so the user can retry via [retryMessage].
  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final localId = 'pending_${DateTime.now().millisecondsSinceEpoch}';

    final optimistic = MessageModel(
      id: localId,
      senderId: currentUserId,
      senderName: currentUserName,
      text: trimmed,
      sentAt: DateTime.now(),
      isPending: true,
      isFailed: false,
    );

    _localMessages.add(optimistic);
    _isOffline = false;
    notifyListeners();

    await _doSend(localId, trimmed);
  }

  /// Retries sending a previously-failed message (T4).
  Future<void> retryMessage(String localId) async {
    final idx = _localMessages.indexWhere((m) => m.id == localId);
    if (idx == -1) return;

    _localMessages[idx] = _localMessages[idx].copyWith(
      isPending: true,
      isFailed: false,
    );
    _isOffline = false;
    notifyListeners();

    await _doSend(localId, _localMessages[idx].text);
  }

  Future<void> _doSend(String localId, String text) async {
    try {
      final msg = MessageModel(
        id: '',
        senderId: currentUserId,
        senderName: currentUserName,
        text: text,
        sentAt: DateTime.now(),
      );
      await _repo.sendMessage(appointmentId: appointmentId, message: msg);

      // Success: the stream will confirm it. We keep the local copy briefly;
      // the deduplication getter will hide it once the stream fires.
      final idx = _localMessages.indexWhere((m) => m.id == localId);
      if (idx != -1) {
        _localMessages[idx] = _localMessages[idx].copyWith(isPending: false);
      }
    } catch (_) {
      // Mark as failed — keep visible for retry (T4).
      final idx = _localMessages.indexWhere((m) => m.id == localId);
      if (idx != -1) {
        _localMessages[idx] = _localMessages[idx].copyWith(
          isPending: false,
          isFailed: true,
        );
      }
      _isOffline = true;
    } finally {
      notifyListeners();
    }
  }

  /// Dismisses the offline banner (does NOT remove failed messages).
  void clearOfflineFlag() {
    _isOffline = false;
    notifyListeners();
  }

  // ── Factory ──────────────────────────────────────────────────────────────────

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
